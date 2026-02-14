import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/chart_data.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

// Constants for daily activity bar chart
abstract class _BarChartConstants {
  static const double mobileHeight = 250.0;
  static const double barWidth = 8.0;
  static const Duration animationDuration = Duration(milliseconds: 800);
  static const Curve animationCurve = Curves.easeOutCubic;
}

// Constants for vocabulary growth line chart
abstract class _LineChartConstants {
  static const double mobileHeight = 250.0;
  static const double lineWidth = 3.0;
  static const double dotSize = 4.0;
  static const double gradientOpacity = 0.1;
  static const Duration animationDuration = Duration(milliseconds: 800);
  static const Curve animationCurve = Curves.easeOutCubic;
}

// Constants for status distribution donut chart
abstract class _DonutChartConstants {
  static const double size = 180.0;
  static const double radius = 50.0;
  static const double centerSpaceRadius = 30.0;
  static const double minPercentageForLabel = 5.0;
}

/// Daily activity bar chart showing reviews, words added, and texts finished.
class DailyActivityBarChart extends StatelessWidget {
  final List<DailyActivityChartData> data;
  final double height;

  const DailyActivityBarChart({
    super.key,
    required this.data,
    this.height = _BarChartConstants.mobileHeight,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.dailyActivityChart,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppConstants.spacingL),
            SizedBox(
              height: height,
              child: data.isEmpty
                  ? Center(
                      child: Text(
                        'No activity data',
                        style: TextStyle(color: AppConstants.subtitleColor),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceEvenly,
                        maxY: _calculateMaxY(),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (group) =>
                                colorScheme.surfaceContainerHigh,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final date = data[group.x.toInt()].date;
                              final dateStr =
                                  DateFormat('MMM d').format(date);
                              final reviews = data[group.x.toInt()].reviews;
                              final wordsAdded =
                                  data[group.x.toInt()].wordsAdded;
                              final textsFinished =
                                  data[group.x.toInt()].textsFinished;

                              return BarTooltipItem(
                                '$dateStr\n',
                                TextStyle(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                                children: [
                                  TextSpan(
                                    text: l10n.chartTooltipReviews(reviews),
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        '\n${l10n.chartTooltipWordsAdded(wordsAdded)}',
                                    style: TextStyle(
                                      color: appColors.warning,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        '\n${l10n.chartTooltipTextsFinished(textsFinished)}',
                                    style: TextStyle(
                                      color: appColors.success,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() % 5 != 0) return const SizedBox();
                                if (value.toInt() >= data.length) {
                                  return const SizedBox();
                                }
                                final date = data[value.toInt()].date;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      top: AppConstants.spacingS),
                                  child: Text(
                                    DateFormat('M/d').format(date),
                                    style: TextStyle(
                                      fontSize: AppConstants.fontSizeCaption,
                                      color: AppConstants.subtitleColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                if (value == meta.max || value == meta.min) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      fontSize: AppConstants.fontSizeCaption,
                                      color: AppConstants.subtitleColor,
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: _calculateMaxY() / 4,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: AppConstants.borderColor.withValues(
                                  alpha: 0.3),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _buildBarGroups(colorScheme, appColors),
                      ),
                      duration: _BarChartConstants.animationDuration,
                      curve: _BarChartConstants.animationCurve,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMaxY() {
    if (data.isEmpty) return 10;
    final maxTotal = data.map((d) => d.total).reduce((a, b) => a > b ? a : b);
    return (maxTotal * 1.2).ceilToDouble();
  }

  List<BarChartGroupData> _buildBarGroups(
      ColorScheme colorScheme, AppColors appColors) {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;

      final double reviewsEnd = item.reviews.toDouble();
      final double wordsEnd = reviewsEnd + item.wordsAdded.toDouble();
      final double textsEnd = wordsEnd + item.textsFinished.toDouble();

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: textsEnd,
            rodStackItems: [
              BarChartRodStackItem(0, reviewsEnd, colorScheme.primary),
              BarChartRodStackItem(reviewsEnd, wordsEnd, appColors.warning),
              BarChartRodStackItem(wordsEnd, textsEnd, appColors.success),
            ],
            borderRadius: BorderRadius.zero,
            width: _BarChartConstants.barWidth,
          ),
        ],
      );
    }).toList();
  }
}

/// Vocabulary growth line chart showing cumulative known words over time.
class VocabularyGrowthLineChart extends StatelessWidget {
  final List<VocabularyGrowthChartData> data;
  final double height;

  const VocabularyGrowthLineChart({
    super.key,
    required this.data,
    this.height = _LineChartConstants.mobileHeight,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.vocabularyGrowthChart,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppConstants.spacingL),
            SizedBox(
              height: height,
              child: data.isEmpty
                  ? Center(
                      child: Text(
                        'No vocabulary data',
                        style: TextStyle(color: AppConstants.subtitleColor),
                      ),
                    )
                  : LineChart(
                      LineChartData(
                        lineTouchData: LineTouchData(
                          enabled: true,
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipColor: (touchedSpot) =>
                                colorScheme.surfaceContainerHigh,
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final date = data[spot.x.toInt()].date;
                                final words = spot.y.toInt();
                                return LineTooltipItem(
                                  '${DateFormat('MMM d').format(date)}\n$words words',
                                  TextStyle(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 5,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() % 5 != 0) return const SizedBox();
                                if (value.toInt() >= data.length) {
                                  return const SizedBox();
                                }
                                final date = data[value.toInt()].date;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      top: AppConstants.spacingS),
                                  child: Text(
                                    DateFormat('M/d').format(date),
                                    style: TextStyle(
                                      fontSize: AppConstants.fontSizeCaption,
                                      color: AppConstants.subtitleColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              getTitlesWidget: (value, meta) {
                                if (value == meta.max || value == meta.min) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: TextStyle(
                                      fontSize: AppConstants.fontSizeCaption,
                                      color: AppConstants.subtitleColor,
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: AppConstants.borderColor.withValues(
                                  alpha: 0.3),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (data.length - 1).toDouble(),
                        minY: _calculateMinY(),
                        maxY: _calculateMaxY(),
                        lineBarsData: [
                          LineChartBarData(
                            spots: data
                                .asMap()
                                .entries
                                .map((e) => FlSpot(
                                      e.key.toDouble(),
                                      e.value.totalKnownWords.toDouble(),
                                    ))
                                .toList(),
                            isCurved: true,
                            color: colorScheme.primary,
                            barWidth: _LineChartConstants.lineWidth,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: _LineChartConstants.dotSize,
                                  color: colorScheme.primary,
                                  strokeWidth: 0,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: colorScheme.primary.withValues(
                                  alpha: _LineChartConstants.gradientOpacity),
                            ),
                          ),
                        ],
                      ),
                      duration: _LineChartConstants.animationDuration,
                      curve: _LineChartConstants.animationCurve,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMinY() {
    if (data.isEmpty) return 0;
    final minWords =
        data.map((d) => d.totalKnownWords).reduce((a, b) => a < b ? a : b);
    return (minWords * 0.9).floorToDouble();
  }

  double _calculateMaxY() {
    if (data.isEmpty) return 100;
    final maxWords =
        data.map((d) => d.totalKnownWords).reduce((a, b) => a > b ? a : b);
    return (maxWords * 1.1).ceilToDouble();
  }
}

/// Status distribution donut chart showing breakdown of words by learning status.
class StatusDistributionDonutChart extends StatefulWidget {
  final List<StatusDistributionData> data;

  const StatusDistributionDonutChart({
    super.key,
    required this.data,
  });

  @override
  State<StatusDistributionDonutChart> createState() =>
      _StatusDistributionDonutChartState();
}

class _StatusDistributionDonutChartState
    extends State<StatusDistributionDonutChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final totalCount = widget.data.isEmpty
        ? 0
        : widget.data.map((d) => d.count).reduce((a, b) => a + b);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.statusDistributionChart,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppConstants.spacingL),
            SizedBox(
              height: _DonutChartConstants.size,
              child: widget.data.isEmpty
                  ? Center(
                      child: Text(
                        'No status data',
                        style: TextStyle(color: AppConstants.subtitleColor),
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius:
                                _DonutChartConstants.centerSpaceRadius,
                            sections: _buildSections(totalCount),
                            pieTouchData: PieTouchData(
                              touchCallback: (event, response) {
                                setState(() {
                                  if (response?.touchedSection != null) {
                                    _touchedIndex =
                                        response!.touchedSection!.touchedSectionIndex;
                                  } else {
                                    _touchedIndex = null;
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              totalCount.toString(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'words',
                              style: TextStyle(
                                fontSize: AppConstants.fontSizeCaption,
                                color: AppConstants.subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            if (widget.data.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingL),
              _buildLegend(context, totalCount),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, int totalCount) {
    return Wrap(
      spacing: AppConstants.spacingM,
      runSpacing: AppConstants.spacingS,
      children: widget.data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final percentage = (item.count / totalCount * 100).toStringAsFixed(1);
        final statusName = _getStatusName(item.status, context);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: item.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppConstants.spacingXS),
            Text(
              '$statusName ($percentage%)',
              style: TextStyle(
                fontSize: AppConstants.fontSizeCaption,
                color: AppConstants.subtitleColor,
                fontWeight:
                    _touchedIndex == index ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _getStatusName(int status, BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case 0: // TermStatus.ignored
        return 'Ignored';
      case 1: // TermStatus.unknown
        return 'Unknown';
      case 2: // TermStatus.learning2 (grouped learning)
        return l10n.learning;
      case 5: // TermStatus.known
        return 'Known';
      case 99: // TermStatus.wellKnown
        return 'Well Known';
      default:
        return 'Unknown';
    }
  }

  List<PieChartSectionData> _buildSections(int totalCount) {
    return widget.data.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final percentage = (item.count / totalCount) * 100;
      final showLabel =
          percentage >= _DonutChartConstants.minPercentageForLabel;
      final isTouched = _touchedIndex == index;

      return PieChartSectionData(
        value: item.count.toDouble(),
        color: item.color,
        title: showLabel ? '${percentage.toStringAsFixed(0)}%' : '',
        titleStyle: const TextStyle(
          fontSize: AppConstants.fontSizeCaption,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: isTouched
            ? _DonutChartConstants.radius + 5
            : _DonutChartConstants.radius,
        titlePositionPercentageOffset: 0.6,
      );
    }).toList();
  }
}
