import '../../presentation/theme/term_status_ui.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/chart_data.dart';
import '../../models/term.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../dashboard/custom_chart_tooltip.dart';

/// Time range options for the status-history chart.
enum StatusHistoryRange {
  week,
  month,
  threeMonths,
  sixMonths,
  year,
  custom,
}

class _LineColors {
  final Color unknown;
  final Color learning;
  final Color known;
  final Color wellKnown;

  const _LineColors({
    required this.unknown,
    required this.learning,
    required this.known,
    required this.wellKnown,
  });
}

/// Multi-line chart showing how term counts per status changed over time.
///
/// The caller is responsible for loading data and passing it in. The widget
/// handles the range selector UI and delegates data loading via [onRangeChanged].
class StatusHistoryChart extends StatefulWidget {
  final List<StatusHistoryDataPoint> data;
  final StatusHistoryRange selectedRange;
  final DateTimeRange? customRange;
  final ValueChanged<StatusHistoryRange> onRangeSelected;
  final ValueChanged<DateTimeRange> onCustomRangeSelected;
  final double height;

  const StatusHistoryChart({
    super.key,
    required this.data,
    required this.selectedRange,
    this.customRange,
    required this.onRangeSelected,
    required this.onCustomRangeSelected,
    this.height = 280.0,
  });

  @override
  State<StatusHistoryChart> createState() => _StatusHistoryChartState();
}

// Indices matching the order in _lineDescriptors / lineBarsData
const int _kUnknown = 0;
const int _kLearning = 1;
const int _kKnown = 2;
const int _kWellKnown = 3;

class _StatusHistoryChartState extends State<StatusHistoryChart> {
  OverlayEntry? _tooltipOverlay;
  final GlobalKey _chartKey = GlobalKey();
  int? _currentTouchedSpot;

  /// Indices of lines the user has toggled off.
  final Set<int> _hiddenLines = {};

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

  _LineColors _lineColors(BuildContext context) {
    final appColors = context.appColors;
    return _LineColors(
      unknown: TermStatusUI.colorFor(TermStatus.unknown),
      learning: appColors.warning,
      known: appColors.success,
      wellKnown: Theme.of(context).colorScheme.primary,
    );
  }

  void _toggleLine(int index) {
    _removeTooltip();
    setState(() {
      if (_hiddenLines.contains(index)) {
        _hiddenLines.remove(index);
      } else {
        _hiddenLines.add(index);
      }
    });
  }

  void _showTooltip(
    BuildContext context,
    int spotIndex,
    Offset localPosition,
    _LineColors colors,
    AppLocalizations l10n,
  ) {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;

    if (spotIndex < 0 || spotIndex >= widget.data.length) return;

    final item = widget.data[spotIndex];
    final dateStr = DateFormat('MMM d, y').format(item.date);

    final renderBox =
        _chartKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final chartPos = renderBox.localToGlobal(Offset.zero);
    final chartBounds = Rect.fromLTWH(
      chartPos.dx,
      chartPos.dy,
      renderBox.size.width,
      renderBox.size.height,
    );

    final labelColor = Theme.of(context).textTheme.bodyMedium?.color;
    final rows = <TooltipRow>[
      if (!_hiddenLines.contains(_kUnknown))
        TooltipRow(
          icon: Icons.circle,
          label: l10n.statusUnknown,
          value: item.unknown.toString(),
          iconColor: colors.unknown,
          labelColor: labelColor,
          valueColor: colors.unknown,
        ),
      if (!_hiddenLines.contains(_kLearning))
        TooltipRow(
          icon: Icons.circle,
          label: l10n.learning,
          value: item.learning.toString(),
          iconColor: colors.learning,
          labelColor: labelColor,
          valueColor: colors.learning,
        ),
      if (!_hiddenLines.contains(_kKnown))
        TooltipRow(
          icon: Icons.circle,
          label: l10n.statusKnown,
          value: item.known.toString(),
          iconColor: colors.known,
          labelColor: labelColor,
          valueColor: colors.known,
        ),
      if (!_hiddenLines.contains(_kWellKnown))
        TooltipRow(
          icon: Icons.circle,
          label: l10n.statusWellKnown,
          value: item.wellKnown.toString(),
          iconColor: colors.wellKnown,
          labelColor: labelColor,
          valueColor: colors.wellKnown,
        ),
    ];

    if (rows.isEmpty) return;

    _tooltipOverlay = CustomChartTooltip.showTooltip(
      context: context,
      position: renderBox.localToGlobal(localPosition),
      title: dateStr,
      rows: rows,
      onDismiss: _removeTooltip,
      chartBounds: chartBounds,
    );
  }

  int get _labelStep {
    final n = widget.data.length;
    if (n <= 14) return 1;
    if (n <= 31) return 5;
    if (n <= 91) return 14;
    if (n <= 183) return 30;
    return 60;
  }

  String _dateLabel(DateTime d) {
    if (widget.selectedRange == StatusHistoryRange.year ||
        widget.selectedRange == StatusHistoryRange.sixMonths) {
      return DateFormat('M/d').format(d);
    }
    return DateFormat('M/d').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = _lineColors(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.statusHistoryChart,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            _buildRangeSelector(l10n),
            const SizedBox(height: AppConstants.spacingL),
            _buildLegend(context, colors, l10n),
            const SizedBox(height: AppConstants.spacingM),
            SizedBox(
              height: widget.height,
              child: widget.data.isEmpty
                  ? Center(
                      child: Text(
                        l10n.noActivityInRange,
                        style: TextStyle(color: AppConstants.subtitleColor),
                      ),
                    )
                  : MouseRegion(
                      key: _chartKey,
                      onExit: (_) => _removeTooltip(),
                      child: LineChart(
                        _buildChartData(colors, l10n),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeSelector(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _rangeChip(l10n.rangeWeek, StatusHistoryRange.week),
          const SizedBox(width: AppConstants.spacingXS),
          _rangeChip(l10n.rangeMonth, StatusHistoryRange.month),
          const SizedBox(width: AppConstants.spacingXS),
          _rangeChip(l10n.range3Months, StatusHistoryRange.threeMonths),
          const SizedBox(width: AppConstants.spacingXS),
          _rangeChip(l10n.range6Months, StatusHistoryRange.sixMonths),
          const SizedBox(width: AppConstants.spacingXS),
          _rangeChip(l10n.rangeYear, StatusHistoryRange.year),
          const SizedBox(width: AppConstants.spacingXS),
          _customRangeChip(l10n),
        ],
      ),
    );
  }

  Widget _rangeChip(String label, StatusHistoryRange range) {
    final selected = widget.selectedRange == range;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => widget.onRangeSelected(range),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _customRangeChip(AppLocalizations l10n) {
    final selected = widget.selectedRange == StatusHistoryRange.custom;
    String label = l10n.rangeCustom;
    if (selected && widget.customRange != null) {
      final r = widget.customRange!;
      label =
          '${DateFormat('M/d/yy').format(r.start)} – ${DateFormat('M/d/yy').format(r.end)}';
    }
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 5),
          lastDate: now,
          initialDateRange: widget.customRange ??
              DateTimeRange(
                start: now.subtract(const Duration(days: 30)),
                end: now,
              ),
        );
        if (picked != null) {
          widget.onCustomRangeSelected(picked);
        }
      },
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildLegend(
    BuildContext context,
    _LineColors colors,
    AppLocalizations l10n,
  ) {
    return Wrap(
      spacing: AppConstants.spacingM,
      runSpacing: AppConstants.spacingXS,
      children: [
        _legendItem(l10n.statusUnknown, colors.unknown, _kUnknown),
        _legendItem(l10n.learning, colors.learning, _kLearning),
        _legendItem(l10n.statusKnown, colors.known, _kKnown),
        _legendItem(l10n.statusWellKnown, colors.wellKnown, _kWellKnown),
      ],
    );
  }

  Widget _legendItem(String label, Color color, int lineIndex) {
    final hidden = _hiddenLines.contains(lineIndex);
    return GestureDetector(
      onTap: () => _toggleLine(lineIndex),
      child: Opacity(
        opacity: hidden ? 0.35 : 1.0,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppConstants.spacingXS),
            Text(
              label,
              style: TextStyle(
                fontSize: AppConstants.fontSizeCaption,
                color: AppConstants.subtitleColor,
                decoration: hidden ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _buildChartData(_LineColors colors, AppLocalizations l10n) {
    final n = widget.data.length;
    final step = _labelStep;

    return LineChartData(
      lineTouchData: LineTouchData(
        enabled: PlatformHelper.isDesktop,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) => spots.map((_) => null).toList(),
        ),
        touchCallback: (event, response) {
          if (response == null ||
              response.lineBarSpots == null ||
              response.lineBarSpots!.isEmpty) {
            _removeTooltip();
            return;
          }
          final idx = response.lineBarSpots!.first.x.toInt();
          if (_currentTouchedSpot != idx && event.localPosition != null) {
            _currentTouchedSpot = idx;
            _showTooltip(context, idx, event.localPosition!, colors, l10n);
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
              final i = value.toInt();
              if (i % step != 0 || i >= n) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: AppConstants.spacingS),
                child: Text(
                  _dateLabel(widget.data[i].date),
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
            reservedSize: 44,
            getTitlesWidget: (value, meta) {
              if (value != meta.max && value != meta.min) {
                return const SizedBox();
              }
              return Text(
                value.toInt().toString(),
                style: TextStyle(
                  fontSize: AppConstants.fontSizeCaption,
                  color: AppConstants.subtitleColor,
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
        getDrawingHorizontalLine: (_) => FlLine(
          color: AppConstants.borderColor.withValues(alpha: 0.3),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (n - 1).toDouble(),
      minY: 0,
      maxY: _maxY(),
      lineBarsData: [
        if (!_hiddenLines.contains(_kUnknown))
          _line(
            widget.data.map((d) => d.unknown.toDouble()).toList(),
            colors.unknown,
          ),
        if (!_hiddenLines.contains(_kLearning))
          _line(
            widget.data.map((d) => d.learning.toDouble()).toList(),
            colors.learning,
          ),
        if (!_hiddenLines.contains(_kKnown))
          _line(
            widget.data.map((d) => d.known.toDouble()).toList(),
            colors.known,
          ),
        if (!_hiddenLines.contains(_kWellKnown))
          _line(
            widget.data.map((d) => d.wellKnown.toDouble()).toList(),
            colors.wellKnown,
          ),
      ],
    );
  }

  double _maxY() {
    if (widget.data.isEmpty) return 100;
    final visibleGetters = <int Function(StatusHistoryDataPoint)>[
      if (!_hiddenLines.contains(_kUnknown)) (d) => d.unknown,
      if (!_hiddenLines.contains(_kLearning)) (d) => d.learning,
      if (!_hiddenLines.contains(_kKnown)) (d) => d.known,
      if (!_hiddenLines.contains(_kWellKnown)) (d) => d.wellKnown,
    ];
    if (visibleGetters.isEmpty) return 100;
    final max = widget.data
        .map((d) => visibleGetters.map((g) => g(d)).reduce((a, b) => a > b ? a : b))
        .reduce((a, b) => a > b ? a : b);
    return (max * 1.15).ceilToDouble();
  }

  LineChartBarData _line(List<double> values, Color color) {
    return LineChartBarData(
      spots: values
          .asMap()
          .entries
          .map((e) => FlSpot(e.key.toDouble(), e.value))
          .toList(),
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}
