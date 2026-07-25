import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../domain/repositories/review_log_repository.dart';
import 'base_repository.dart';

const _uuid = Uuid();

class ReviewLogRepositoryImpl extends BaseRepository
    implements ReviewLogRepository {
  ReviewLogRepositoryImpl(super.getDatabase);

  @override
  Future<int> create(String termId, String logDataJson, DateTime reviewedAt) async {
    final db = await getDatabase();
    return await db.insert('review_logs', {
      'id': _uuid.v4(),
      'term_id': termId,
      'log_data': logDataJson,
      'reviewed_at': reviewedAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<int> getReviewCountToday(String languageId) async {
    final db = await getDatabase();
    final todayStart = DateTime.now().toUtc();
    final todayStartStr = DateTime.utc(
      todayStart.year,
      todayStart.month,
      todayStart.day,
    ).toIso8601String();

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as cnt FROM review_logs rl
      INNER JOIN terms t ON t.id = rl.term_id
      WHERE t.language_id = ? AND rl.reviewed_at >= ?
      ''',
      [languageId, todayStartStr],
    );
    return result.first['cnt'] as int;
  }

  @override
  Future<Map<String, int>> getReviewCountsByDay(String languageId, String sinceIso) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      '''
      SELECT DATE(reviewed_at) as date, COUNT(*) as cnt
      FROM review_logs rl
      INNER JOIN terms t ON t.id = rl.term_id
      WHERE t.language_id = ? AND rl.reviewed_at >= ?
      GROUP BY DATE(reviewed_at)
      ''',
      [languageId, sinceIso],
    );
    return {for (var row in result) row['date'] as String: row['cnt'] as int};
  }

  @override
  Future<({int total, int recalled})> getRetention(
    String languageId, {
    int days = 30,
  }) async {
    final db = await getDatabase();
    final since = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days))
        .toIso8601String();

    final rows = await db.rawQuery(
      '''
      SELECT rl.log_data FROM review_logs rl
      INNER JOIN terms t ON t.id = rl.term_id
      WHERE t.language_id = ? AND rl.reviewed_at >= ?
      ''',
      [languageId, since],
    );

    var total = 0;
    var recalled = 0;
    for (final row in rows) {
      final data = jsonDecode(row['log_data'] as String) as Map<String, dynamic>;
      final rating = data['rating'] as int?;
      if (rating == null) continue;
      total++;
      // FSRS Rating.again == 1 marks a failed recall (lapse).
      if (rating != 1) recalled++;
    }
    return (total: total, recalled: recalled);
  }

  @override
  Future<Map<String, int>> getLapseCounts(
    List<String> termIds, {
    int days = 90,
  }) async {
    if (termIds.isEmpty) return {};
    final db = await getDatabase();
    final since = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days))
        .toIso8601String();

    // Ratings are decoded in Dart rather than with json_extract: SQLite's JSON1
    // extension is not guaranteed on every Android system SQLite we ship against.
    const chunkSize = 500;
    final counts = <String, int>{};
    for (var i = 0; i < termIds.length; i += chunkSize) {
      final chunk = termIds.skip(i).take(chunkSize).toList();
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await db.rawQuery(
        '''
        SELECT term_id, log_data FROM review_logs
        WHERE term_id IN ($placeholders) AND reviewed_at >= ?
        ''',
        [...chunk, since],
      );
      for (final row in rows) {
        final data =
            jsonDecode(row['log_data'] as String) as Map<String, dynamic>;
        // FSRS Rating.again == 1 is the only rating that counts as a lapse.
        if (data['rating'] != 1) continue;
        final termId = row['term_id'] as String;
        counts[termId] = (counts[termId] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  Future<List<({DateTime reviewedAt, int rating, int? durationMs})>> getByTermId(
    String termId,
  ) async {
    final db = await getDatabase();
    final rows = await db.query(
      'review_logs',
      where: 'term_id = ?',
      whereArgs: [termId],
      orderBy: 'reviewed_at ASC',
    );
    return rows.map((row) {
      final data = jsonDecode(row['log_data'] as String) as Map<String, dynamic>;
      return (
        reviewedAt: DateTime.parse(row['reviewed_at'] as String),
        rating: (data['rating'] as int?) ?? 0,
        durationMs: data['reviewDuration'] as int?,
      );
    }).toList();
  }
}
