import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../l10n/generated/app_localizations.dart';
import '../models/day_activity.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';

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
  static const double tooltipWidth = 200.0;
  static const double tooltipOffset = 20.0;
  static const double tooltipElevation = 4.0;
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

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final currentMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: todayWeekday - 1));
    return currentMonday.subtract(Duration(days: (widget.weeksToShow - 1) * 7));
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

  void _handleTap(BuildContext context, TapUpDetails details) {
    final startDate = _getStartDate();
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
        col >= widget.weeksToShow ||
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
  }

  void _showTooltip(
    BuildContext context,
    Offset globalPos,
    DateTime date,
    DayActivity activity,
  ) {
    _removeTooltip();

    final l10n = AppLocalizations.of(context);
    final dateStr = DateFormat.yMMMd().format(date);
    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;

    _tooltipOverlay = OverlayEntry(
      builder: (context) {
        double left = globalPos.dx - _HeatmapConstants.tooltipWidth / 2;
        if (left < AppConstants.spacingS) {
          left = AppConstants.spacingS;
        }
        if (left + _HeatmapConstants.tooltipWidth >
            screenSize.width - AppConstants.spacingS) {
          left =
              screenSize.width -
              _HeatmapConstants.tooltipWidth -
              AppConstants.spacingS;
        }
        final top = globalPos.dy - 120;

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _removeTooltip,
              ),
            ),
            Positioned(
              left: left,
              top: top < AppConstants.spacingS
                  ? globalPos.dy + _HeatmapConstants.tooltipOffset
                  : top,
              child: Material(
                elevation: _HeatmapConstants.tooltipElevation,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                child: Container(
                  width: _HeatmapConstants.tooltipWidth,
                  padding: const EdgeInsets.all(AppConstants.spacingM),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(
                      AppConstants.borderRadiusM,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppConstants.spacingS),
                      _buildDetailRow(
                        context,
                        Icons.menu_book,
                        l10n.textsCompleted,
                        activity.textsCompleted,
                      ),
                      const SizedBox(height: AppConstants.spacingXS),
                      _buildDetailRow(
                        context,
                        Icons.add_circle_outline,
                        l10n.wordsAdded,
                        activity.wordsAdded,
                      ),
                      const SizedBox(height: AppConstants.spacingXS),
                      _buildDetailRow(
                        context,
                        Icons.school_outlined,
                        l10n.wordsReviewed,
                        activity.wordsReviewed,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_tooltipOverlay!);
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
    final startDate = _getStartDate();

    final gridWidth =
        _HeatmapConstants.dayLabelWidth +
        widget.weeksToShow *
            (_HeatmapConstants.cellSize + _HeatmapConstants.cellSpacing);
    final gridHeight =
        _HeatmapConstants.monthLabelHeight +
        _HeatmapConstants.daysInWeek *
            (_HeatmapConstants.cellSize + _HeatmapConstants.cellSpacing);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.activityHeatmap,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (widget.streakDays != null && widget.streakDays! > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                  ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: GestureDetector(
                onTapUp: (details) => _handleTap(context, details),
                child: CustomPaint(
                  size: Size(gridWidth, gridHeight),
                  painter: _HeatmapPainter(
                    activityData: widget.activityData,
                    startDate: startDate,
                    weeksToShow: widget.weeksToShow,
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
            const SizedBox(height: AppConstants.spacingS),
            _buildLegend(l10n, primary, emptyColor),
          ],
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
