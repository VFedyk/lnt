import 'dart:async';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:uuid/uuid.dart';
import '../../domain/entities/review_card.dart';
import '../../domain/events/term_event.dart';
import '../../domain/repositories/review_card_repository.dart';
import '../../services/settings_service.dart';
import '../../utils/constants.dart';
import '../../domain/value_objects/term_status.dart';
import 'base_repository.dart';

const _uuid = Uuid();

class ReviewCardRepositoryImpl extends BaseRepository
    implements ReviewCardRepository {
  StreamSubscription<TermEvent>? _termSub;
  final SettingsService? _settings;

  ReviewCardRepositoryImpl(super.getDatabase,
      {super.onChange, SettingsService? settings})
      : _settings = settings;

  /// SQL fragment that is 1 when a card has never been reviewed.
  static const String _isNewExpr =
      "CASE WHEN NOT EXISTS (SELECT 1 FROM review_logs rl WHERE rl.term_id = rc.term_id) THEN 1 ELSE 0 END";

  /// Remaining new cards allowed today, or null when there is no limit.
  Future<int?> _newCardBudget(String languageId) async {
    final settings = _settings;
    if (settings == null) return null;
    final perDay = await settings.getNewCardsPerDay();
    if (perDay <= 0) return null;
    final introduced = await _countNewCardsIntroducedToday(languageId);
    final budget = perDay - introduced;
    return budget < 0 ? 0 : budget;
  }

  /// Number of terms whose first-ever review happened today.
  Future<int> _countNewCardsIntroducedToday(String languageId) async {
    final db = await getDatabase();
    final now = DateTime.now().toUtc();
    final todayStart =
        DateTime.utc(now.year, now.month, now.day).toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as cnt FROM (
        SELECT rl.term_id FROM review_logs rl
        INNER JOIN terms t ON t.id = rl.term_id
        WHERE t.language_id = ?
        GROUP BY rl.term_id
        HAVING MIN(rl.reviewed_at) >= ?
      )
      ''',
      [languageId, todayStart],
    );
    return result.first['cnt'] as int;
  }

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
    // Ids are read up front so each removed card gets its own tombstone —
    // sync addresses cards by id, not by term_id.
    final cardIds = (await db.query('review_cards',
            columns: ['id'], where: 'term_id = ?', whereArgs: [termId]))
        .map((r) => r['id'] as String)
        .toList();
    final result = await db.delete(
      'review_cards',
      where: 'term_id = ?',
      whereArgs: [termId],
    );
    for (final cardId in cardIds) {
      await BaseRepository.recordTombstone(db, 'review_card', cardId);
    }
    notifyChange();
    return result;
  }

  /// `AND t.status IN (?, ?, …)` fragment, or empty when no filter is applied.
  static String _statusClause(List<int>? statuses) =>
      (statuses != null && statuses.isNotEmpty)
          ? 'AND t.status IN (${List.filled(statuses.length, '?').join(', ')})'
          : '';

  @override
  Future<List<ReviewCardRecord>> getDueCards(String languageId,
      {DateTime? now, int? limit, List<int>? statuses}) async {
    final db = await getDatabase();
    now ??= DateTime.now().toUtc();
    final effectiveLimit = limit ?? AppConstants.dueCardLimit;
    final statusArgs = statuses ?? const <int>[];
    final maps = await db.rawQuery(
      '''
      SELECT rc.*, $_isNewExpr AS is_new FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        AND rc.next_due <= ?
        ${_statusClause(statuses)}
      ORDER BY rc.next_due ASC
      LIMIT ?
      ''',
      [languageId, now.toIso8601String(), ...statusArgs, effectiveLimit],
    );

    final budget = await _newCardBudget(languageId);
    if (budget == null) {
      return maps.map((m) => ReviewCardRecord.fromMap(m)).toList();
    }

    // Review cards are always shown; new cards are capped by the daily budget.
    final result = <ReviewCardRecord>[];
    var newUsed = 0;
    for (final m in maps) {
      if ((m['is_new'] as int) == 1) {
        if (newUsed >= budget) continue;
        newUsed++;
      }
      result.add(ReviewCardRecord.fromMap(m));
    }
    return result;
  }

  /// Total due once the daily new-card [budget] is applied (review cards are
  /// always counted; new cards are capped).
  int _applyBudget(int total, int newCnt, int? budget) {
    if (budget == null) return total;
    final cappedNew = newCnt < budget ? newCnt : budget;
    return (total - newCnt) + cappedNew;
  }

  @override
  Future<int> getDueCount(String languageId,
      {DateTime? now, List<int>? statuses}) async {
    final db = await getDatabase();
    now ??= DateTime.now().toUtc();
    final statusArgs = statuses ?? const <int>[];
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as total, COALESCE(SUM($_isNewExpr), 0) as new_cnt
      FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        AND rc.next_due <= ?
        ${_statusClause(statuses)}
      ''',
      [languageId, now.toIso8601String(), ...statusArgs],
    );
    final total = result.first['total'] as int;
    final newCnt = result.first['new_cnt'] as int;
    return _applyBudget(total, newCnt, await _newCardBudget(languageId));
  }

  @override
  Future<int> getClozeDueCount(String languageId,
      {DateTime? now, List<int>? statuses}) async {
    final db = await getDatabase();
    now ??= DateTime.now().toUtc();
    final statusArgs = statuses ?? const <int>[];
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as total, COALESCE(SUM($_isNewExpr), 0) as new_cnt
      FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        AND rc.next_due <= ?
        ${_statusClause(statuses)}
        AND (
          (t.sentence IS NOT NULL AND t.sentence != '')
          OR EXISTS (SELECT 1 FROM term_sentences ts WHERE ts.term_id = t.id)
        )
      ''',
      [languageId, now.toIso8601String(), ...statusArgs],
    );
    final total = result.first['total'] as int;
    final newCnt = result.first['new_cnt'] as int;
    return _applyBudget(total, newCnt, await _newCardBudget(languageId));
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
