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
/// Holds cumulative total of known words for a single date.
class VocabularyGrowthChartData {
  final DateTime date;
  final int totalKnownWords;

  const VocabularyGrowthChartData({
    required this.date,
    required this.totalKnownWords,
  });
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
