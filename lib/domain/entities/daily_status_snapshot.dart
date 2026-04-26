/// A snapshot of how many terms were in each status on a given date.
class DailyStatusSnapshot {
  final DateTime date;
  /// Map from TermStatus int → count.
  final Map<int, int> counts;

  const DailyStatusSnapshot({required this.date, required this.counts});
}
