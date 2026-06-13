import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';

/// Bar chart of how many review cards fall due on each of the next N days.
/// The first bar (today) includes any overdue cards.
class DueForecastChart extends StatelessWidget {
  final List<({DateTime date, int count})> data;
  final double height;

  const DueForecastChart({
    super.key,
    required this.data,
    this.height = 220.0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final hasDue = data.any((d) => d.count > 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.reviewForecast,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppConstants.spacingL),
            SizedBox(
              height: height,
              child: !hasDue
                  ? Center(
                      child: Text(
                        l10n.nothingDueSoon,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceEvenly,
                        maxY: _maxY(),
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, _, rod, _) {
                              final item = data[group.x.toInt()];
                              return BarTooltipItem(
                                '${DateFormat('MMM d').format(item.date)}\n',
                                TextStyle(
                                  color: colorScheme.onInverseSurface,
                                  fontWeight: FontWeight.bold,
                                  fontSize: AppConstants.fontSizeCaption,
                                ),
                                children: [
                                  TextSpan(
                                    text: l10n.cardsDueCount(item.count),
                                    style: TextStyle(
                                      color: colorScheme.onInverseSurface,
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
                              reservedSize: 28,
                              getTitlesWidget: (value, meta) {
                                final i = value.toInt();
                                if (i < 0 || i >= data.length) {
                                  return const SizedBox();
                                }
                                // Label first, last, and every other day.
                                if (i != 0 &&
                                    i != data.length - 1 &&
                                    i % 2 != 0) {
                                  return const SizedBox();
                                }
                                return Padding(
                                  padding:
                                      const EdgeInsets.only(top: AppConstants.spacingS),
                                  child: Text(
                                    DateFormat('M/d').format(data[i].date),
                                    style: TextStyle(
                                      fontSize: AppConstants.fontSizeCaption,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              getTitlesWidget: (value, meta) {
                                if (value != meta.max && value != meta.min) {
                                  return const SizedBox();
                                }
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    fontSize: AppConstants.fontSizeCaption,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                );
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
                          horizontalInterval: _maxY() / 4,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color:
                                colorScheme.outlineVariant.withValues(alpha: 0.3),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _barGroups(colorScheme),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  double _maxY() {
    final maxCount =
        data.fold<int>(0, (m, d) => d.count > m ? d.count : m);
    final maxY = (maxCount * 1.2).ceilToDouble();
    return maxY > 0 ? maxY : 4;
  }

  List<BarChartGroupData> _barGroups(ColorScheme colorScheme) {
    return data.asMap().entries.map((entry) {
      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: entry.value.count.toDouble(),
            color: colorScheme.primary,
            width: 8.0,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.borderRadiusS),
            ),
          ),
        ],
      );
    }).toList();
  }
}
