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
}
