import 'base_repository.dart';

class ReviewLogRepository extends BaseRepository {
  ReviewLogRepository(super.getDatabase);

  Future<int> create(int termId, String logDataJson, DateTime reviewedAt) async {
    final db = await getDatabase();
    return await db.insert('review_logs', {
      'term_id': termId,
      'log_data': logDataJson,
      'reviewed_at': reviewedAt.toUtc().toIso8601String(),
    });
  }

  Future<int> getReviewCountToday(int languageId) async {
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

  Future<Map<String, int>> getReviewCountsByDay(int languageId, String sinceIso) async {
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
}
