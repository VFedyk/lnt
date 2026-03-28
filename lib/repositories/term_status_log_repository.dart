import 'base_repository.dart';

/// A snapshot of how many terms were in each status on a given date.
class DailyStatusSnapshot {
  final DateTime date;
  /// Map from TermStatus int → count.
  final Map<int, int> counts;

  const DailyStatusSnapshot({required this.date, required this.counts});
}

/// Repository for term_status_log.
///
/// Tracks the status of each term over time (one row per status change).
/// Used to build the vocabulary progress line chart on the statistics screen.
class TermStatusLogRepository extends BaseRepository {
  TermStatusLogRepository(super.getDatabase);

  /// Insert a status change entry (called by ReviewService on every review).
  Future<void> logChange(String termId, int status, DateTime changedAt) async {
    final db = await getDatabase();
    await db.insert('term_status_log', {
      'term_id': termId,
      'status': status,
      'changed_at': changedAt.toUtc().toIso8601String(),
    });
  }

  /// Returns daily status snapshots between [from] and [to] (inclusive).
  Future<List<DailyStatusSnapshot>> getDailySnapshots({
    required String languageId,
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await getDatabase();

    final toStr =
        DateTime.utc(to.year, to.month, to.day, 23, 59, 59).toIso8601String();

    // 1. All terms created on or before `to`, for this language.
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
    // Map term_id → created_at (UTC DateTime)
    final termCreatedAt = <String, DateTime>{};
    for (final r in termRows) {
      termCreatedAt[r['id'] as String] =
          DateTime.parse(r['created_at'] as String).toUtc();
    }

    // 2. All status log entries for those terms, up through `to`.
    final placeholders = List.filled(termIds.length, '?').join(',');
    final logRows = await db.rawQuery(
      '''
      SELECT term_id, status, changed_at FROM term_status_log
      WHERE term_id IN ($placeholders) AND changed_at <= ?
      ORDER BY changed_at ASC
      ''',
      [...termIds, toStr],
    );

    // Build per-term sorted list of (changed_at, status)
    final termLog = <String, List<(DateTime, int)>>{};
    for (final r in logRows) {
      final tid = r['term_id'] as String;
      final dt = DateTime.parse(r['changed_at'] as String).toUtc();
      final st = r['status'] as int;
      (termLog[tid] ??= []).add((dt, st));
    }

    // 3. For each day, compute per-term status then aggregate.
    final days = _dayRange(from, to);
    final snapshots = <DailyStatusSnapshot>[];

    for (final day in days) {
      final dayEnd =
          DateTime.utc(day.year, day.month, day.day, 23, 59, 59);
      final counts = <int, int>{};

      for (final termId in termIds) {
        final created = termCreatedAt[termId]!;
        // Only count terms that existed by this day.
        if (created.isAfter(dayEnd)) continue;

        final log = termLog[termId];
        int status = 1; // default: unknown
        if (log != null) {
          // Walk backwards to find the most recent entry on or before dayEnd.
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
