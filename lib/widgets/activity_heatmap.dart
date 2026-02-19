import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../l10n/generated/app_localizations.dart';
import '../models/day_activity.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'custom_chart_tooltip.dart';

abstract class _HeatmapConstants {
  static const double cellSize = 11.0;
  static const double cellSpacing = 3.0;
  static const double cellRadius = 2.0;
  static const double dayLabelWidth = 28.0;
  static const double monthLabelHeight = 16.0;
  static const int daysInWeek = 7;
  static const double legendCellSize = 10.0;
  static const double legendSpacing = 2.0;
  static const int defaultWeeks = 26;
  static const int intensityThreshold1 = 2;
  static const int intensityThreshold2 = 5;
  static const int intensityThreshold3 = 10;
  static const double intensityAlpha1 = 0.25;
  static const double intensityAlpha2 = 0.50;
  static const double intensityAlpha3 = 0.75;
}

class ActivityHeatmap extends StatefulWidget {
  final Map<String, DayActivity> activityData;
  final int weeksToShow;
  final bool useTooltip;
  final int? streakDays;

  const ActivityHeatmap({
    super.key,
    required this.activityData,
    this.weeksToShow = _HeatmapConstants.defaultWeeks,
    this.useTooltip = false,
    this.streakDays,
  });

  @override
  State<ActivityHeatmap> createState() => _ActivityHeatmapState();
}

class _ActivityHeatmapState extends State<ActivityHeatmap> {
  OverlayEntry? _tooltipOverlay;
  String? _currentHoveredDateKey;
  final GlobalKey _heatmapKey = GlobalKey();

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  DateTime _getStartDate(int weeksToShow) {
    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final currentMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: todayWeekday - 1));
    return currentMonday.subtract(Duration(days: (weeksToShow - 1) * 7));
  }

  int _intensityLevel(int total) {
    if (total == 0) return 0;
    if (total <= _HeatmapConstants.intensityThreshold1) return 1;
    if (total <= _HeatmapConstants.intensityThreshold2) return 2;
    if (total <= _HeatmapConstants.intensityThreshold3) return 3;
    return 4;
  }

  Color _colorForIntensity(int level, Color primary, Color empty) {
    switch (level) {
      case 0:
        return empty;
      case 1:
        return primary.withValues(alpha: _HeatmapConstants.intensityAlpha1);
      case 2:
        return primary.withValues(alpha: _HeatmapConstants.intensityAlpha2);
      case 3:
        return primary.withValues(alpha: _HeatmapConstants.intensityAlpha3);
      case 4:
        return primary;
      default:
        return primary;
    }
  }

  void _handleTap(
    BuildContext context,
    TapUpDetails details,
    int weeksToShow,
  ) {
    final startDate = _getStartDate(weeksToShow);
    final localPos = details.localPosition;

    final col =
        ((localPos.dx - _HeatmapConstants.dayLabelWidth) /
                (_HeatmapConstants.cellSize + _HeatmapConstants.cellSpacing))
            .floor();
    final row =
        ((localPos.dy - _HeatmapConstants.monthLabelHeight) /
                (_HeatmapConstants.cellSize + _HeatmapConstants.cellSpacing))
            .floor();

    if (col < 0 ||
        col >= weeksToShow ||
        row < 0 ||
        row >= _HeatmapConstants.daysInWeek) {
      return;
    }

    final date = startDate.add(Duration(days: col * 7 + row));
    if (date.isAfter(DateTime.now())) {
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final activity = widget.activityData[dateStr] ?? const DayActivity();

    if (widget.useTooltip) {
      _showTooltip(context, details.globalPosition, date, activity);
    } else {
      _showDayDialog(context, date, activity);
    }
  }

  void _removeTooltip() {
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;
    _currentHoveredDateKey = null;
  }

  void _handleHover(
    BuildContext context,
    PointerEvent event,
    int weeksToShow,
  ) {
    if (!widget.useTooltip) return;

    // Get render box for coordinate conversion
    final RenderBox? renderBox = _heatmapKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final startDate = _getStartDate(weeksToShow);
    final localPos = event.localPosition;

    final col =
        ((localPos.dx - _HeatmapConstants.dayLabelWidth) /
                (_HeatmapConstants.cellSize + _HeatmapConstants.cellSpacing))
            .floor();
    final row =
        ((localPos.dy - _HeatmapConstants.monthLabelHeight) /
                (_HeatmapConstants.cellSize + _HeatmapConstants.cellSpacing))
            .floor();

    if (col < 0 ||
        col >= weeksToShow ||
        row < 0 ||
        row >= _HeatmapConstants.daysInWeek) {
      if (_currentHoveredDateKey != null) {
        _removeTooltip();
      }
      return;
    }

    final date = startDate.add(Duration(days: col * 7 + row));
    if (date.isAfter(DateTime.now())) {
      if (_currentHoveredDateKey != null) {
        _removeTooltip();
      }
      return;
    }

    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    // Only update tooltip if hovering over a different cell
    if (_currentHoveredDateKey != dateStr) {
      _currentHoveredDateKey = dateStr;
      final activity = widget.activityData[dateStr] ?? const DayActivity();

      // Convert local position to global
      final globalPosition = renderBox.localToGlobal(localPos);
      _showTooltip(context, globalPosition, date, activity);
    }
  }

  void _showTooltip(
    BuildContext context,
    Offset globalPos,
    DateTime date,
    DayActivity activity,
  ) {
    // Remove old tooltip overlay but keep the current hovered date key
    _tooltipOverlay?.remove();
    _tooltipOverlay = null;

    final l10n = AppLocalizations.of(context);
    final dateStr = DateFormat.yMMMd().format(date);

    // Calculate chart bounds to constrain tooltip within the heatmap area
    final RenderBox? renderBox = _heatmapKey.currentContext?.findRenderObject() as RenderBox?;
    Rect? chartBounds;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      chartBounds = Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
    }

    _tooltipOverlay = CustomChartTooltip.showTooltip(
      context: context,
      position: globalPos,
      title: dateStr,
      rows: [
        TooltipRow(
          icon: Icons.menu_book,
          label: l10n.textsCompleted,
          value: activity.textsCompleted.toString(),
          iconColor: AppConstants.subtitleColor,
          labelColor: Theme.of(context).textTheme.bodyMedium?.color,
          valueColor: Theme.of(context).textTheme.bodyMedium?.color,
        ),
        TooltipRow(
          icon: Icons.add_circle_outline,
          label: l10n.wordsAdded,
          value: activity.wordsAdded.toString(),
          iconColor: AppConstants.subtitleColor,
          labelColor: Theme.of(context).textTheme.bodyMedium?.color,
          valueColor: Theme.of(context).textTheme.bodyMedium?.color,
        ),
        TooltipRow(
          icon: Icons.school_outlined,
          label: l10n.wordsReviewed,
          value: activity.wordsReviewed.toString(),
          iconColor: AppConstants.subtitleColor,
          labelColor: Theme.of(context).textTheme.bodyMedium?.color,
          valueColor: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ],
      onDismiss: _removeTooltip,
      chartBounds: chartBounds,
    );
  }

  void _showDayDialog(
    BuildContext context,
    DateTime date,
    DayActivity activity,
  ) {
    final l10n = AppLocalizations.of(context);
    final dateStr = DateFormat.yMMMd().format(date);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(dateStr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow(
              context,
              Icons.menu_book,
              l10n.textsCompleted,
              activity.textsCompleted,
            ),
            const SizedBox(height: AppConstants.spacingS),
            _buildDetailRow(
              context,
              Icons.add_circle_outline,
              l10n.wordsAdded,
              activity.wordsAdded,
            ),
            const SizedBox(height: AppConstants.spacingS),
            _buildDetailRow(
              context,
              Icons.school_outlined,
              l10n.wordsReviewed,
              activity.wordsReviewed,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    int count,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: AppConstants.iconSizeS,
          color: AppConstants.subtitleColor,
        ),
        const SizedBox(width: AppConstants.spacingS),
        Expanded(child: Text(label)),
        Text(
          count.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final emptyColor = colorScheme.surfaceContainerHighest;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.activityHeatmap,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.streakDays != null && widget.streakDays! > 0) ...[
                  const Spacer(),
                  Icon(
                    Icons.local_fire_department,
                    size: AppConstants.iconSizeS,
                    color: context.appColors.streak,
                  ),
                  const SizedBox(width: AppConstants.spacingXS),
                  Text(
                    l10n.streakDays(widget.streakDays!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.appColors.streak,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            widget.useTooltip
                ? _buildHeatmapGrid(
                    context: context,
                    weeksToShow: widget.weeksToShow,
                    primary: primary,
                    emptyColor: emptyColor,
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final cellTotal =
                          _HeatmapConstants.cellSize +
                          _HeatmapConstants.cellSpacing;
                      final availableWidth = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : double.infinity;
                      final effectiveWeeks = availableWidth.isFinite
                          ? ((availableWidth -
                                          _HeatmapConstants.dayLabelWidth) /
                                      cellTotal)
                                  .floor()
                                  .clamp(1, widget.weeksToShow)
                          : widget.weeksToShow;

                      return _buildHeatmapGrid(
                        context: context,
                        weeksToShow: effectiveWeeks,
                        primary: primary,
                        emptyColor: emptyColor,
                      );
                    },
                  ),
            const SizedBox(height: AppConstants.spacingS),
            _buildLegend(l10n, primary, emptyColor),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapGrid({
    required BuildContext context,
    required int weeksToShow,
    required Color primary,
    required Color emptyColor,
  }) {
    final cellTotal = _HeatmapConstants.cellSize + _HeatmapConstants.cellSpacing;
    final startDate = _getStartDate(weeksToShow);
    final gridWidth = _HeatmapConstants.dayLabelWidth + weeksToShow * cellTotal;
    final gridHeight =
        _HeatmapConstants.monthLabelHeight +
        _HeatmapConstants.daysInWeek * cellTotal;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: MouseRegion(
        key: _heatmapKey,
        onHover: (event) => _handleHover(context, event, weeksToShow),
        onExit: (_) => _removeTooltip(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(context, details, weeksToShow),
          child: CustomPaint(
            size: Size(gridWidth, gridHeight),
            painter: _HeatmapPainter(
              activityData: widget.activityData,
              startDate: startDate,
              weeksToShow: weeksToShow,
              primary: primary,
              emptyColor: emptyColor,
              textColor: AppConstants.subtitleColor,
              intensityLevel: _intensityLevel,
              colorForIntensity: (level) =>
                  _colorForIntensity(level, primary, emptyColor),
              locale: Localizations.localeOf(context).languageCode,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(AppLocalizations l10n, Color primary, Color emptyColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          l10n.less,
          style: TextStyle(
            fontSize: AppConstants.fontSizeXS,
            color: AppConstants.subtitleColor,
          ),
        ),
        const SizedBox(width: AppConstants.spacingXS),
        for (int i = 0; i <= 4; i++) ...[
          Container(
            width: _HeatmapConstants.legendCellSize,
            height: _HeatmapConstants.legendCellSize,
            margin: const EdgeInsets.symmetric(
              horizontal: _HeatmapConstants.legendSpacing,
            ),
            decoration: BoxDecoration(
              color: _colorForIntensity(i, primary, emptyColor),
              borderRadius: BorderRadius.circular(_HeatmapConstants.cellRadius),
            ),
          ),
        ],
        const SizedBox(width: AppConstants.spacingXS),
        Text(
          l10n.more,
          style: TextStyle(
            fontSize: AppConstants.fontSizeXS,
            color: AppConstants.subtitleColor,
          ),
        ),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  final Map<String, DayActivity> activityData;
  final DateTime startDate;
  final int weeksToShow;
  final Color primary;
  final Color emptyColor;
  final Color textColor;
  final int Function(int) intensityLevel;
  final Color Function(int) colorForIntensity;
  final String locale;

  _HeatmapPainter({
    required this.activityData,
    required this.startDate,
    required this.weeksToShow,
    required this.primary,
    required this.emptyColor,
    required this.textColor,
    required this.intensityLevel,
    required this.colorForIntensity,
    required this.locale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellTotal =
        _HeatmapConstants.cellSize + _HeatmapConstants.cellSpacing;
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');

    // Draw month labels
    final monthLabelStyle = TextStyle(
      fontSize: AppConstants.fontSizeXS,
      color: textColor,
    );
    int lastMonth = -1;
    for (int week = 0; week < weeksToShow; week++) {
      final weekStart = startDate.add(Duration(days: week * 7));
      if (weekStart.month != lastMonth) {
        lastMonth = weekStart.month;
        final monthName = DateFormat('MMM', locale).format(weekStart);
        final tp = TextPainter(
          text: TextSpan(text: monthName, style: monthLabelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(_HeatmapConstants.dayLabelWidth + week * cellTotal, 0),
        );
      }
    }

    // Draw day labels (Mon, Wed, Fri)
    final dayLabels = DateFormat('E', locale);
    for (int row = 0; row < _HeatmapConstants.daysInWeek; row++) {
      if (row == 0 || row == 2 || row == 4) {
        final sampleDate = startDate.add(Duration(days: row));
        final label = dayLabels.format(sampleDate);
        final tp = TextPainter(
          text: TextSpan(text: label, style: monthLabelStyle),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.right,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            0,
            _HeatmapConstants.monthLabelHeight +
                row * cellTotal +
                (_HeatmapConstants.cellSize - tp.height) / 2,
          ),
        );
      }
    }

    // Draw cells
    final paint = Paint();
    for (int week = 0; week < weeksToShow; week++) {
      for (int day = 0; day < _HeatmapConstants.daysInWeek; day++) {
        final date = startDate.add(Duration(days: week * 7 + day));

        if (date.isAfter(now)) continue;

        final dateStr = dateFormat.format(date);
        final activity = activityData[dateStr];
        final total = activity?.total ?? 0;
        final level = intensityLevel(total);

        paint.color = colorForIntensity(level);

        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            _HeatmapConstants.dayLabelWidth + week * cellTotal,
            _HeatmapConstants.monthLabelHeight + day * cellTotal,
            _HeatmapConstants.cellSize,
            _HeatmapConstants.cellSize,
          ),
          const Radius.circular(_HeatmapConstants.cellRadius),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) {
    return oldDelegate.activityData != activityData ||
        oldDelegate.startDate != startDate ||
        oldDelegate.primary != primary ||
        oldDelegate.weeksToShow != weeksToShow;
  }
}
