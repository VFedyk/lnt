import 'package:flutter/material.dart';

/// Data model for daily activity bar chart.
/// Holds counts for reviews, words added, and texts finished for a single day.
class DailyActivityChartData {
  final DateTime date;
  final int reviews;
  final int wordsAdded;
  final int textsFinished;

  const DailyActivityChartData({
    required this.date,
    required this.reviews,
    required this.wordsAdded,
    required this.textsFinished,
  });

  int get total => reviews + wordsAdded + textsFinished;
}

/// Data model for vocabulary growth line chart.
/// Holds cumulative total of words for a single date.
class VocabularyGrowthChartData {
  final DateTime date;
  final int totalKnownWords;

  const VocabularyGrowthChartData({
    required this.date,
    required this.totalKnownWords,
  });
}

/// One data point for the status-history line chart.
/// Holds counts for each TermStatus on a given date.
class StatusHistoryDataPoint {
  final DateTime date;
  final int unknown;
  final int learning;
  final int known;
  final int wellKnown;
  final int ignored;

  const StatusHistoryDataPoint({
    required this.date,
    required this.unknown,
    required this.learning,
    required this.known,
    required this.wellKnown,
    required this.ignored,
  });

  int get total => unknown + learning + known + wellKnown + ignored;
}

/// Data model for status distribution donut chart.
/// Holds count and display color for a term status category.
class StatusDistributionData {
  final int status;
  final int count;
  final Color color;

  const StatusDistributionData({
    required this.status,
    required this.count,
    required this.color,
  });

  double get percentage => count.toDouble();
}
