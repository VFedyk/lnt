import 'package:intl/intl.dart';
import '../models/chart_data.dart';
import '../models/term.dart';

/// Helper functions for transforming repository data into chart-ready format.
abstract class ChartHelpers {
  /// Builds daily activity chart data for the last [days] days.
  ///
  /// Combines review counts, words added, and texts finished into a single
  /// list of [DailyActivityChartData] ordered chronologically from oldest to newest.
  static List<DailyActivityChartData> buildDailyActivityChartData({
    required Map<String, int> reviewsByDay,
    required Map<String, int> wordsAddedByDay,
    required Map<String, int> textsFinishedByDay,
    required int days,
  }) {
    final now = DateTime.now();
    final result = <DailyActivityChartData>[];

    for (int i = days - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);

      result.add(DailyActivityChartData(
        date: date,
        reviews: reviewsByDay[dateKey] ?? 0,
        wordsAdded: wordsAddedByDay[dateKey] ?? 0,
        textsFinished: textsFinishedByDay[dateKey] ?? 0,
      ));
    }

    return result;
  }

  /// Builds vocabulary growth chart data for the last [days] days.
  ///
  /// Calculates cumulative word counts by working backwards from [currentKnownCount],
  /// subtracting daily additions to determine historical totals.
  /// Values are clamped to never go below 0.
  static List<VocabularyGrowthChartData> buildVocabularyGrowthChartData({
    required Map<String, int> wordsAddedByDay,
    required int currentKnownCount,
    required int days,
  }) {
    final now = DateTime.now();
    final result = <VocabularyGrowthChartData>[];
    int cumulativeTotal = currentKnownCount;

    // Work backwards from today to calculate historical values
    for (int i = 0; i < days; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(date);

      // Insert at beginning to maintain chronological order
      result.insert(
        0,
        VocabularyGrowthChartData(
          date: date,
          totalKnownWords: cumulativeTotal,
        ),
      );

      // Subtract words added on this day to get previous day's total
      // Clamp to 0 to prevent negative values
      cumulativeTotal = (cumulativeTotal - (wordsAddedByDay[dateKey] ?? 0)).clamp(0, double.infinity).toInt();
    }

    return result;
  }

  /// Builds status distribution chart data from term counts by status.
  ///
  /// Combines all learning statuses (2, 3, 4) into a single "Learning" category
  /// and filters out statuses with zero counts for cleaner visualization.
  static List<StatusDistributionData> buildStatusDistributionData({
    required Map<int, int> countsByStatus,
  }) {
    final Map<int, int> groupedCounts = {};

    // Group learning statuses (2, 3, 4) into learning2
    int learningTotal = 0;
    for (final status in [
      TermStatus.learning2,
      TermStatus.learning3,
      TermStatus.learning4,
    ]) {
      learningTotal += countsByStatus[status] ?? 0;
    }

    // Build grouped counts map
    groupedCounts[TermStatus.ignored] = countsByStatus[TermStatus.ignored] ?? 0;
    groupedCounts[TermStatus.unknown] = countsByStatus[TermStatus.unknown] ?? 0;
    groupedCounts[TermStatus.learning2] = learningTotal;
    groupedCounts[TermStatus.known] = countsByStatus[TermStatus.known] ?? 0;
    groupedCounts[TermStatus.wellKnown] = countsByStatus[TermStatus.wellKnown] ?? 0;

    // Convert to list, filtering out zero counts
    final result = <StatusDistributionData>[];
    groupedCounts.forEach((status, count) {
      if (count > 0) {
        result.add(StatusDistributionData(
          status: status,
          count: count,
          color: TermStatus.colorFor(status),
        ));
      }
    });

    return result;
  }
}
