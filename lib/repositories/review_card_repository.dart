import 'package:fsrs/fsrs.dart' as fsrs;
import '../models/review_card.dart';
import 'base_repository.dart';

class ReviewCardRepository extends BaseRepository {
  ReviewCardRepository(super.getDatabase, {super.onChange});

  Future<int> create(ReviewCardRecord record) async {
    final db = await getDatabase();
    final map = record.toMap();
    map.remove('id');
    final id = await db.insert('review_cards', map);
    notifyChange();
    return id;
  }

  Future<ReviewCardRecord?> getByTermId(int termId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'review_cards',
      where: 'term_id = ?',
      whereArgs: [termId],
    );
    if (maps.isEmpty) return null;
    return ReviewCardRecord.fromMap(maps.first);
  }

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

  Future<int> deleteByTermId(int termId) async {
    final db = await getDatabase();
    final result = await db.delete(
      'review_cards',
      where: 'term_id = ?',
      whereArgs: [termId],
    );
    notifyChange();
    return result;
  }

  /// Get all due cards for a language, joined with terms.
  /// Excludes ignored (status=0) and wellKnown (status=99) terms.
  Future<List<ReviewCardRecord>> getDueCards(int languageId,
      {DateTime? now}) async {
    final db = await getDatabase();
    now ??= DateTime.now().toUtc();
    final maps = await db.rawQuery(
      '''
      SELECT rc.* FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        AND t.status != 99
        AND rc.next_due <= ?
      ORDER BY rc.next_due ASC
      ''',
      [languageId, now.toIso8601String()],
    );
    return maps.map((m) => ReviewCardRecord.fromMap(m)).toList();
  }

  /// Count due cards for a language (for badge display).
  Future<int> getDueCount(int languageId, {DateTime? now}) async {
    final db = await getDatabase();
    now ??= DateTime.now().toUtc();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as cnt FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        AND t.status != 99
        AND rc.next_due <= ?
      ''',
      [languageId, now.toIso8601String()],
    );
    return result.first['cnt'] as int;
  }

  /// Get the next due date across all cards for a language.
  Future<DateTime?> getNextDueDate(int languageId) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      '''
      SELECT MIN(rc.next_due) as next_due FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        AND t.status != 99
      ''',
      [languageId],
    );
    final value = result.first['next_due'] as String?;
    if (value == null) return null;
    return DateTime.parse(value);
  }

  /// Ensure a review card exists for a term; create one if missing.
  Future<ReviewCardRecord> getOrCreate(int termId) async {
    final existing = await getByTermId(termId);
    if (existing != null) return existing;

    final now = DateTime.now().toUtc();
    final card = fsrs.Card(
      cardId: now.millisecondsSinceEpoch,
      due: now,
    );
    final record = ReviewCardRecord(
      termId: termId,
      card: card,
      nextDue: now,
      createdAt: now,
      updatedAt: now,
    );
    final id = await create(record);
    return record.copyWith(id: id);
  }

  /// Batch create review cards for terms that don't have one yet.
  Future<void> ensureCardsExist(List<int> termIds) async {
    if (termIds.isEmpty) return;

    final db = await getDatabase();
    // Find which term IDs already have cards
    const batchSize = 500;
    final existingIds = <int>{};

    for (var i = 0; i < termIds.length; i += batchSize) {
      final batch = termIds.skip(i).take(batchSize).toList();
      final placeholders = List.filled(batch.length, '?').join(',');
      final maps = await db.rawQuery(
        'SELECT term_id FROM review_cards WHERE term_id IN ($placeholders)',
        batch,
      );
      existingIds.addAll(maps.map((m) => m['term_id'] as int));
    }

    final missingIds = termIds.where((id) => !existingIds.contains(id)).toList();
    if (missingIds.isEmpty) return;

    final now = DateTime.now().toUtc();
    final dbBatch = db.batch();
    for (final termId in missingIds) {
      final card = fsrs.Card(
        cardId: now.millisecondsSinceEpoch + termId,
        due: now,
      );
      final record = ReviewCardRecord(
        termId: termId,
        card: card,
        nextDue: now,
        createdAt: now,
        updatedAt: now,
      );
      final map = record.toMap();
      map.remove('id');
      dbBatch.insert('review_cards', map);
    }
    await dbBatch.commit(noResult: true);
    notifyChange();
  }
}
