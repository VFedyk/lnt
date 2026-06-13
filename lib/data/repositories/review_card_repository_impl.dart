import 'dart:async';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:uuid/uuid.dart';
import '../../domain/entities/review_card.dart';
import '../../domain/events/term_event.dart';
import '../../domain/repositories/review_card_repository.dart';
import '../../utils/constants.dart';
import '../../domain/value_objects/term_status.dart';
import 'base_repository.dart';

const _uuid = Uuid();

class ReviewCardRepositoryImpl extends BaseRepository
    implements ReviewCardRepository {
  StreamSubscription<TermEvent>? _termSub;

  ReviewCardRepositoryImpl(super.getDatabase, {super.onChange});

  void subscribeToTermEvents(Stream<TermEvent> events) {
    _termSub = events.listen(_onTermEvent);
  }

  Future<void> _onTermEvent(TermEvent event) async {
    switch (event) {
      case TermWritten(:final id, :final status):
        if (status == TermStatus.ignored) {
          await deleteByTermId(id);
        } else {
          await getOrCreate(id);
        }
      case TermsBulkWritten(:final terms):
        final reviewable = terms
            .where((t) => t.status != TermStatus.ignored)
            .map((t) => t.id)
            .toList();
        final nonReviewable = terms
            .where((t) => t.status == TermStatus.ignored)
            .map((t) => t.id)
            .toList();
        await ensureCardsExist(reviewable);
        for (final id in nonReviewable) {
          await deleteByTermId(id);
        }
    }
  }

  void cancelTermSubscription() => _termSub?.cancel();

  @override
  Future<String> create(ReviewCardRecord record) async {
    final db = await getDatabase();
    final id = record.id ?? _uuid.v4();
    await db.insert('review_cards', record.copyWith(id: id).toMap());
    notifyChange();
    return id;
  }

  @override
  Future<ReviewCardRecord?> getByTermId(String termId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'review_cards',
      where: 'term_id = ?',
      whereArgs: [termId],
    );
    if (maps.isEmpty) return null;
    return ReviewCardRecord.fromMap(maps.first);
  }

  @override
  Future<int> update(ReviewCardRecord record) async {
    final db = await getDatabase();
    final result = await db.update(
      'review_cards',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    notifyChange();
    return result;
  }

  @override
  Future<int> deleteByTermId(String termId) async {
    final db = await getDatabase();
    final result = await db.delete(
      'review_cards',
      where: 'term_id = ?',
      whereArgs: [termId],
    );
    notifyChange();
    return result;
  }

  @override
  Future<List<ReviewCardRecord>> getDueCards(String languageId,
      {DateTime? now, int? limit}) async {
    final db = await getDatabase();
    now ??= DateTime.now().toUtc();
    final effectiveLimit = limit ?? AppConstants.dueCardLimit;
    final maps = await db.rawQuery(
      '''
      SELECT rc.* FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        AND rc.next_due <= ?
      ORDER BY rc.next_due ASC
      LIMIT ?
      ''',
      [languageId, now.toIso8601String(), effectiveLimit],
    );
    return maps.map((m) => ReviewCardRecord.fromMap(m)).toList();
  }

  @override
  Future<int> getDueCount(String languageId, {DateTime? now}) async {
    final db = await getDatabase();
    now ??= DateTime.now().toUtc();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as cnt FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        AND rc.next_due <= ?
      ''',
      [languageId, now.toIso8601String()],
    );
    return result.first['cnt'] as int;
  }

  @override
  Future<int> getClozeDueCount(String languageId, {DateTime? now}) async {
    final db = await getDatabase();
    now ??= DateTime.now().toUtc();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as cnt FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        AND rc.next_due <= ?
        AND (
          (t.sentence IS NOT NULL AND t.sentence != '')
          OR EXISTS (SELECT 1 FROM term_sentences ts WHERE ts.term_id = t.id)
        )
      ''',
      [languageId, now.toIso8601String()],
    );
    return result.first['cnt'] as int;
  }

  @override
  Future<DateTime?> getNextDueDate(String languageId) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      '''
      SELECT MIN(rc.next_due) as next_due FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
      ''',
      [languageId],
    );
    final value = result.first['next_due'] as String?;
    if (value == null) return null;
    return DateTime.parse(value);
  }

  @override
  Future<List<({DateTime date, int count})>> getDueForecast(
    String languageId, {
    int days = 14,
    DateTime? now,
  }) async {
    final db = await getDatabase();
    now ??= DateTime.now().toUtc();
    final todayStart = DateTime.utc(now.year, now.month, now.day);
    final end = todayStart.add(Duration(days: days));

    // No lower bound: overdue cards are folded into today's bucket below.
    final rows = await db.rawQuery(
      '''
      SELECT DATE(rc.next_due) as date, COUNT(*) as cnt
      FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        AND rc.next_due < ?
      GROUP BY DATE(rc.next_due)
      ''',
      [languageId, end.toIso8601String()],
    );

    String dayKey(DateTime d) => d.toIso8601String().substring(0, 10);
    final todayKey = dayKey(todayStart);
    final counts = <String, int>{};
    for (final row in rows) {
      final date = row['date'] as String;
      final cnt = row['cnt'] as int;
      // Anything due today or earlier (overdue) collapses into the first bar.
      final key = date.compareTo(todayKey) <= 0 ? todayKey : date;
      counts[key] = (counts[key] ?? 0) + cnt;
    }

    return List.generate(days, (i) {
      final day = todayStart.add(Duration(days: i));
      return (date: day, count: counts[dayKey(day)] ?? 0);
    });
  }

  @override
  Future<ReviewCardRecord> getOrCreate(String termId) async {
    final existing = await getByTermId(termId);
    if (existing != null) return existing;

    final now = DateTime.now().toUtc();
    final card = fsrs.Card(
      cardId: now.millisecondsSinceEpoch,
      due: now,
    );
    final record = ReviewCardRecord(
      termId: termId,
      cardData: card.toMap(),
      nextDue: now,
      createdAt: now,
      updatedAt: now,
    );
    final id = await create(record);
    return record.copyWith(id: id);
  }

  @override
  Future<void> ensureCardsExist(List<String> termIds) async {
    if (termIds.isEmpty) return;

    final db = await getDatabase();
    const batchSize = 500;
    final existingIds = <String>{};

    for (var i = 0; i < termIds.length; i += batchSize) {
      final batch = termIds.skip(i).take(batchSize).toList();
      final placeholders = List.filled(batch.length, '?').join(',');
      final maps = await db.rawQuery(
        'SELECT term_id FROM review_cards WHERE term_id IN ($placeholders)',
        batch,
      );
      existingIds.addAll(maps.map((m) => m['term_id'] as String));
    }

    final missingIds = termIds.where((id) => !existingIds.contains(id)).toList();
    if (missingIds.isEmpty) return;

    final now = DateTime.now().toUtc();
    final dbBatch = db.batch();
    for (var i = 0; i < missingIds.length; i++) {
      final termId = missingIds[i];
      final card = fsrs.Card(
        cardId: now.millisecondsSinceEpoch + i,
        due: now,
      );
      final record = ReviewCardRecord(
        id: _uuid.v4(),
        termId: termId,
        cardData: card.toMap(),
        nextDue: now,
        createdAt: now,
        updatedAt: now,
      );
      dbBatch.insert('review_cards', record.toMap());
    }
    await dbBatch.commit(noResult: true);
    notifyChange();
  }
}
