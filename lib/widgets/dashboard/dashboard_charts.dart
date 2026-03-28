import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chart_data.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import 'custom_chart_tooltip.dart';

// Constants for daily activity bar chart
abstract class _BarChartConstants {
  static const double mobileHeight = 250.0;
  static const double barWidth = 8.0;
  static const Duration animationDuration = AppConstants.animationVerySlow;
  static const Curve animationCurve = Curves.easeOutCubic;
}

// Constants for vocabulary growth line chart
abstract class _LineChartConstants {
  static const double mobileHeight = 250.0;
  static const double lineWidth = 3.0;
  static const double dotSize = 4.0;
  static const double gradientOpacity = 0.1;
  static const Duration animationDuration = AppConstants.animationVerySlow;
  static const Curve animationCurve = Curves.easeOutCubic;
}

// Constants for status distribution donut chart
abstract class _DonutChartConstants {
  static const double size = 180.0;
  static const double radius = 50.0;
  static const double centerSpaceRadius = 49.0;
  static const double minPercentageForLabel = 5.0;
}

/// Daily activity bar chart showing reviews, words added, and texts finished.
class DailyActivityBarChart extends StatefulWidget {
  final List<DailyActivityChartData> data;
  final double height;

  const DailyActivityBarChart({
    super.key,
    required this.data,
    this.height = _BarChartConstants.mobileHeight,
  });

  @override
  State<DailyActivityBarChart> createState() => _DailyActivityBarChartState();
}

class _DailyActivityBarChartState extends State<DailyActivityBarChart> {
  OverlayEntry? _tooltipOverlay;
  final GlobalKey _chartKey = GlobalKey();
  int? _currentTouchedBar;

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
    _currentTouchedBar = null;
  }

  void _showBarTooltip(
    BuildContext context,
    int barIndex,
    Offset localPosition,
    AppLocalizations l10n,
    ColorScheme colorScheme,
    AppColors appColors,
  ) {
    // Only remove tooltip if we don't have one yet (prevents blinking)
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;

    final item = widget.data[barIndex];
    final dateStr = DateFormat('MMM d').format(item.date);

    // Get chart bounds
    final RenderBox? renderBox = _chartKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final chartPosition = renderBox.localToGlobal(Offset.zero);
    final chartSize = renderBox.size;
    final chartBounds = Rect.fromLTWH(
      chartPosition.dx,
      chartPosition.dy,
      chartSize.width,
      chartSize.height,
    );

    // Convert local position to global
    final globalPosition = renderBox.localToGlobal(localPosition);

    _tooltipOverlay = CustomChartTooltip.showTooltip(
      context: context,
      position: globalPosition,
      title: dateStr,
      rows: [
        TooltipRow(
          icon: Icons.school_outlined,
          label: l10n.wordsReviewed,
          value: item.reviews.toString(),
          iconColor: colorScheme.primary,
          labelColor: Theme.of(context).textTheme.bodyMedium?.color,
          valueColor: colorScheme.primary,
        ),
        TooltipRow(
          icon: Icons.add_circle_outline,
          label: l10n.wordsAdded,
          value: item.wordsAdded.toString(),
          iconColor: appColors.warning,
          labelColor: Theme.of(context).textTheme.bodyMedium?.color,
          valueColor: appColors.warning,
        ),
        TooltipRow(
          icon: Icons.menu_book,
          label: l10n.textsCompleted,
          value: item.textsFinished.toString(),
          iconColor: appColors.success,
          labelColor: Theme.of(context).textTheme.bodyMedium?.color,
          valueColor: appColors.success,
        ),
      ],
      onDismiss: _removeTooltip,
      chartBounds: chartBounds,
    );
  }

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
              height: widget.height,
              child: widget.data.isEmpty
                  ? Center(
                      child: Text(
                        'No activity data',
                        style: TextStyle(color: AppConstants.subtitleColor),
                      ),
                    )
                  : MouseRegion(
                      key: _chartKey,
                      onExit: (_) => _removeTooltip(),
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceEvenly,
                          maxY: _calculateMaxY(),
                          barTouchData: BarTouchData(
                            enabled: PlatformHelper.isDesktop,
                            touchTooltipData: BarTouchTooltipData(
                              // Disable built-in tooltip rendering
                              getTooltipItem: (group, groupIndex, rod, rodIndex) => null,
                            ),
                            touchCallback: (event, response) {
                              if (response == null || response.spot == null || event.localPosition == null) {
                                _removeTooltip();
                                return;
                              }

                              final barIndex = response.spot!.touchedBarGroupIndex;
                              if (barIndex < 0 || barIndex >= widget.data.length) {
                                _removeTooltip();
                                return;
                              }

                              // Only update if different bar
                              if (_currentTouchedBar != barIndex) {
                                _currentTouchedBar = barIndex;
                                _showBarTooltip(
                                  context,
                                  barIndex,
                                  event.localPosition!,
                                  l10n,
                                  colorScheme,
                                  appColors,
                                );
                              }
                            },
                            handleBuiltInTouches: true,
                          ),
                          titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() % 5 != 0) {
                                  return const SizedBox();
                                }
                                if (value.toInt() >= widget.data.length) {
                                  return const SizedBox();
                                }
                                final date = widget.data[value.toInt()].date;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppConstants.spacingS,
                                  ),
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
                                alpha: 0.3,
                              ),
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
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMaxY() {
    if (widget.data.isEmpty) return 4;
    final maxTotal = widget.data.map((d) => d.total).reduce((a, b) => a > b ? a : b);
    final maxY = (maxTotal * 1.2).ceilToDouble();
    return maxY > 0 ? maxY : 4; // ensure interval (maxY/4) is never zero
  }

  List<BarChartGroupData> _buildBarGroups(
    ColorScheme colorScheme,
    AppColors appColors,
  ) {
    return widget.data.asMap().entries.map((entry) {
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
class VocabularyGrowthLineChart extends StatefulWidget {
  final List<VocabularyGrowthChartData> data;
  final double height;

  const VocabularyGrowthLineChart({
    super.key,
    required this.data,
    this.height = _LineChartConstants.mobileHeight,
  });

  @override
  State<VocabularyGrowthLineChart> createState() => _VocabularyGrowthLineChartState();
}

class _VocabularyGrowthLineChartState extends State<VocabularyGrowthLineChart> {
  OverlayEntry? _tooltipOverlay;
  final GlobalKey _chartKey = GlobalKey();
  int? _currentTouchedSpot;

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
    _currentTouchedSpot = null;
  }

  void _showLineTooltip(
    BuildContext context,
    int spotIndex,
    Offset localPosition,
    AppLocalizations l10n,
    ColorScheme colorScheme,
  ) {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;

    final item = widget.data[spotIndex];
    final dateStr = DateFormat('MMM d').format(item.date);

    // Get chart bounds
    final RenderBox? renderBox = _chartKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final chartPosition = renderBox.localToGlobal(Offset.zero);
    final chartSize = renderBox.size;
    final chartBounds = Rect.fromLTWH(
      chartPosition.dx,
      chartPosition.dy,
      chartSize.width,
      chartSize.height,
    );

    // Convert local position to global
    final globalPosition = renderBox.localToGlobal(localPosition);

    _tooltipOverlay = CustomChartTooltip.showTooltip(
      context: context,
      position: globalPosition,
      title: dateStr,
      rows: [
        TooltipRow(
          icon: Icons.abc,
          label: 'Total words',
          value: item.totalKnownWords.toString(),
          iconColor: colorScheme.primary,
          labelColor: Theme.of(context).textTheme.bodyMedium?.color,
          valueColor: colorScheme.primary,
        ),
      ],
      onDismiss: _removeTooltip,
      chartBounds: chartBounds,
    );
  }

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
              height: widget.height,
              child: widget.data.isEmpty
                  ? Center(
                      child: Text(
                        'No vocabulary data',
                        style: TextStyle(color: AppConstants.subtitleColor),
                      ),
                    )
                  : MouseRegion(
                      key: _chartKey,
                      onExit: (_) => _removeTooltip(),
                      child: LineChart(
                        LineChartData(
                          lineTouchData: LineTouchData(
                            enabled: PlatformHelper.isDesktop,
                            touchTooltipData: LineTouchTooltipData(
                              // Disable built-in tooltip rendering
                              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) => null).toList(),
                            ),
                            touchCallback: (event, response) {
                              if (response == null || response.lineBarSpots == null || response.lineBarSpots!.isEmpty) {
                                _removeTooltip();
                                return;
                              }

                              final spot = response.lineBarSpots!.first;
                              final spotIndex = spot.x.toInt();
                              if (spotIndex < 0 || spotIndex >= widget.data.length) {
                                _removeTooltip();
                                return;
                              }

                              // Only update if different spot
                              if (_currentTouchedSpot != spotIndex) {
                                _currentTouchedSpot = spotIndex;
                                if (event.localPosition != null) {
                                  _showLineTooltip(
                                    context,
                                    spotIndex,
                                    event.localPosition!,
                                    l10n,
                                    colorScheme,
                                  );
                                }
                              }
                            },
                            handleBuiltInTouches: true,
                          ),
                          titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 5,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() % 5 != 0) {
                                  return const SizedBox();
                                }
                                if (value.toInt() >= widget.data.length) {
                                  return const SizedBox();
                                }
                                final date = widget.data[value.toInt()].date;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: AppConstants.spacingS,
                                  ),
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
                          horizontalInterval: _calculateHorizontalInterval(),
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: AppConstants.borderColor.withValues(
                                alpha: 0.3,
                              ),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        minX: 0,
                        maxX: (widget.data.length - 1).toDouble(),
                        minY: _calculateMinY(),
                        maxY: _calculateMaxY(),
                        lineBarsData: [
                          LineChartBarData(
                            spots: widget.data
                                .asMap()
                                .entries
                                .map(
                                  (e) => FlSpot(
                                    e.key.toDouble(),
                                    e.value.totalKnownWords.toDouble(),
                                  ),
                                )
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
                                alpha: _LineChartConstants.gradientOpacity,
                              ),
                            ),
                          ),
                        ],
                      ),
                      duration: _LineChartConstants.animationDuration,
                      curve: _LineChartConstants.animationCurve,
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateMinY() {
    if (widget.data.isEmpty) return 0;
    final minWords = widget.data
        .map((d) => d.totalKnownWords)
        .reduce((a, b) => a < b ? a : b);
    return (minWords * 0.9).floorToDouble();
  }

  double _calculateMaxY() {
    if (widget.data.isEmpty) return 100;
    final maxWords = widget.data
        .map((d) => d.totalKnownWords)
        .reduce((a, b) => a > b ? a : b);
    final maxY = (maxWords * 1.1).ceilToDouble();
    // Ensure maxY > minY so fl_chart never computes a zero interval.
    return maxY > _calculateMinY() ? maxY : _calculateMinY() + 4;
  }

  double _calculateHorizontalInterval() {
    final range = _calculateMaxY() - _calculateMinY();
    final interval = range / 4;
    return interval > 0 ? interval : 1;
  }
}

/// Status distribution donut chart showing breakdown of words by learning status.
class StatusDistributionDonutChart extends StatefulWidget {
  final List<StatusDistributionData> data;

  const StatusDistributionDonutChart({super.key, required this.data});

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
                                    _touchedIndex = response!
                                        .touchedSection!
                                        .touchedSectionIndex;
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
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              l10n.words,
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
                fontWeight: _touchedIndex == index
                    ? FontWeight.bold
                    : FontWeight.normal,
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
        return l10n.statusIgnored;
      case 1: // TermStatus.unknown
        return l10n.statusUnknown;
      case 2: // TermStatus.learning2 (grouped learning)
        return l10n.learning;
      case 5: // TermStatus.known
        return l10n.statusKnown;
      case 99: // TermStatus.wellKnown
        return l10n.statusWellKnown;
      default:
        return l10n.statusUnknown;
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
