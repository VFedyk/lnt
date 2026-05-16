import 'package:flutter/material.dart';
import '../../../utils/constants.dart';

/// Reusable custom tooltip for charts with left-aligned content.
///
/// Based on activity heatmap tooltip implementation.
class CustomChartTooltip {
  static const double tooltipWidth = 200.0;
  static const double tooltipElevation = 4.0;
  static const Duration fadeInDuration = Duration(milliseconds: 200);

  /// Shows a custom tooltip overlay at the given position.
  ///
  /// Returns the OverlayEntry so it can be removed later.
  static OverlayEntry showTooltip({
    required BuildContext context,
    required Offset position,
    required String title,
    required List<TooltipRow> rows,
    required VoidCallback onDismiss,
    Rect? chartBounds,
  }) {
    final overlay = Overlay.of(context);
    final screenSize = MediaQuery.of(context).size;

    // Use chart bounds if provided, otherwise use screen bounds
    final bounds = chartBounds ?? Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);

    final overlayEntry = OverlayEntry(
      builder: (context) {
        // Calculate horizontal position
        double left = position.dx - tooltipWidth / 2;
        if (left < bounds.left + AppConstants.spacingS) {
          left = bounds.left + AppConstants.spacingS;
        }
        if (left + tooltipWidth > bounds.right - AppConstants.spacingS) {
          left = bounds.right - tooltipWidth - AppConstants.spacingS;
        }

        // Calculate vertical position (above the touch point)
        // Estimated tooltip height based on number of rows
        const estimatedTooltipHeight = 120.0;
        double top = position.dy - estimatedTooltipHeight - 20;

        // Ensure tooltip stays within vertical bounds
        if (top < bounds.top + AppConstants.spacingS) {
          // If tooltip would go above bounds, show it below the point instead
          top = position.dy + 20;
        }
        if (top + estimatedTooltipHeight > bounds.bottom - AppConstants.spacingS) {
          // If tooltip would go below bounds, position it at the top of bounds
          top = bounds.bottom - estimatedTooltipHeight - AppConstants.spacingS;
          // But make sure it doesn't go above the top bound
          if (top < bounds.top + AppConstants.spacingS) {
            top = bounds.top + AppConstants.spacingS;
          }
        }

        return TweenAnimationBuilder<double>(
          duration: fadeInDuration,
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.easeOut,
          builder: (context, opacity, child) {
            return Opacity(opacity: opacity, child: child!);
          },
          child: IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  left: left,
                  top: top,
                  child: Material(
                  elevation: tooltipElevation,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                  child: Container(
                    width: tooltipWidth,
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
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppConstants.spacingS),
                        ...rows.asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (index > 0)
                                const SizedBox(height: AppConstants.spacingXS),
                              _buildRow(context, row),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                ),
              ],
            ),
          ),
        );
      },
    );

    overlay.insert(overlayEntry);
    return overlayEntry;
  }

  static Widget _buildRow(BuildContext context, TooltipRow row) {
    return Row(
      children: [
        Icon(
          row.icon,
          size: AppConstants.iconSizeS,
          color: row.iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppConstants.spacingS),
        Expanded(
          child: Text(
            row.label,
            style: TextStyle(color: row.labelColor),
          ),
        ),
        Text(
          row.value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: row.valueColor,
          ),
        ),
      ],
    );
  }
}

/// Data class for a single row in the tooltip.
class TooltipRow {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Color? labelColor;
  final Color? valueColor;

  const TooltipRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.labelColor,
    this.valueColor,
  });
}
