import '../../domain/entities/daily_status_snapshot.dart';
import '../../domain/repositories/term_status_log_repository.dart';
import 'base_repository.dart';

class TermStatusLogRepositoryImpl extends BaseRepository
    implements TermStatusLogRepository {
  TermStatusLogRepositoryImpl(super.getDatabase);

  @override
  Future<void> logChange(String termId, int status, DateTime changedAt) async {
    final db = await getDatabase();
    await db.insert('term_status_log', {
      'term_id': termId,
      'status': status,
      'changed_at': changedAt.toUtc().toIso8601String(),
    });
  }

  @override
  Future<List<DailyStatusSnapshot>> getDailySnapshots({
    required String languageId,
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await getDatabase();

    final toStr =
        DateTime.utc(to.year, to.month, to.day, 23, 59, 59).toIso8601String();

    final termRows = await db.rawQuery(
      '''
      SELECT id, created_at FROM terms
      WHERE language_id = ? AND created_at <= ?
      ORDER BY created_at ASC
      ''',
      [languageId, toStr],
    );

    if (termRows.isEmpty) return [];

    final termIds = termRows.map((r) => r['id'] as String).toList();
    final termCreatedAt = <String, DateTime>{};
    for (final r in termRows) {
      termCreatedAt[r['id'] as String] =
          DateTime.parse(r['created_at'] as String).toUtc();
    }

    final placeholders = List.filled(termIds.length, '?').join(',');
    final logRows = await db.rawQuery(
      '''
      SELECT term_id, status, changed_at FROM term_status_log
      WHERE term_id IN ($placeholders) AND changed_at <= ?
      ORDER BY changed_at ASC
      ''',
      [...termIds, toStr],
    );

    final termLog = <String, List<(DateTime, int)>>{};
    for (final r in logRows) {
      final tid = r['term_id'] as String;
      final dt = DateTime.parse(r['changed_at'] as String).toUtc();
      final st = r['status'] as int;
      (termLog[tid] ??= []).add((dt, st));
    }

    final days = _dayRange(from, to);
    final snapshots = <DailyStatusSnapshot>[];

    for (final day in days) {
      final dayEnd =
          DateTime.utc(day.year, day.month, day.day, 23, 59, 59);
      final counts = <int, int>{};

      for (final termId in termIds) {
        final created = termCreatedAt[termId]!;
        if (created.isAfter(dayEnd)) continue;

        final log = termLog[termId];
        int status = 1;
        if (log != null) {
          for (int i = log.length - 1; i >= 0; i--) {
            if (!log[i].$1.isAfter(dayEnd)) {
              status = log[i].$2;
              break;
            }
          }
        }
        counts[status] = (counts[status] ?? 0) + 1;
      }

      snapshots.add(DailyStatusSnapshot(date: day, counts: counts));
    }

    return snapshots;
  }

  @override
  Future<List<({DateTime changedAt, int status})>> getByTermId(
    String termId,
  ) async {
    final db = await getDatabase();
    final rows = await db.query(
      'term_status_log',
      columns: ['status', 'changed_at'],
      where: 'term_id = ?',
      whereArgs: [termId],
      orderBy: 'changed_at ASC',
    );
    return rows
        .map((r) => (
              changedAt: DateTime.parse(r['changed_at'] as String),
              status: r['status'] as int,
            ))
        .toList();
  }

  List<DateTime> _dayRange(DateTime from, DateTime to) {
    final days = <DateTime>[];
    var cur = DateTime.utc(from.year, from.month, from.day);
    final end = DateTime.utc(to.year, to.month, to.day);
    while (!cur.isAfter(end)) {
      days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return days;
  }
}
