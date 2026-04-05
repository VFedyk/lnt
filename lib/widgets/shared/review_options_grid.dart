import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';

/// A 2×2 grid of multiple-choice option buttons shared by
/// MultipleChoiceReviewScreen and ClozeReviewScreen.
///
/// Shows four options with keyboard shortcut labels (1-4).
/// After [selectedIndex] is set (non-null), the correct option turns green,
/// the wrong selected option turns red, and buttons become inert.
class ReviewOptionsGrid extends StatelessWidget {
  final List<String> options;
  final int correctIndex;
  final int? selectedIndex;
  final void Function(int) onSelect;

  static const _keyLabels = ['1', '2', '3', '4'];
  static const double _optionFontSize = 16.0;
  static const double _optionIconSize = 20.0;

  const ReviewOptionsGrid({
    super.key,
    required this.options,
    required this.correctIndex,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final answered = selectedIndex != null;
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildOption(context, 0, answered)),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(child: _buildOption(context, 1, answered)),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingS),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildOption(context, 2, answered)),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(child: _buildOption(context, 3, answered)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOption(BuildContext context, int index, bool answered) {
    if (index >= options.length) return const SizedBox.shrink();

    final isCorrect = index == correctIndex;
    final isSelected = selectedIndex == index;

    Color? bgColor;
    Color borderColor = Theme.of(context).colorScheme.outline;
    Color? textColor;
    IconData? statusIcon;

    if (answered) {
      if (isCorrect) {
        bgColor = context.appColors.success.withValues(alpha: 0.15);
        borderColor = context.appColors.success;
        textColor = context.appColors.success;
        statusIcon = Icons.check_circle;
      } else if (isSelected) {
        bgColor = Theme.of(context).colorScheme.error.withValues(alpha: 0.15);
        borderColor = Theme.of(context).colorScheme.error;
        textColor = Theme.of(context).colorScheme.error;
        statusIcon = Icons.cancel;
      }
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: answered ? () {} : () => onSelect(index),
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor ?? Theme.of(context).colorScheme.onSurface,
          side: BorderSide(color: borderColor),
          minimumSize: const Size(0, 64),
          // Left padding matches the button's effective border radius (half of
          // minimumSize height = 64/2 = 32px) so text starts at the straight
          // edge of the pill shape rather than inside the rounded cap.
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingXXL,
            AppConstants.spacingL,
            AppConstants.spacingM,
            AppConstants.spacingL,
          ),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _keyLabels[index],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: (textColor ?? Theme.of(context).colorScheme.onSurface)
                    .withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            if (statusIcon != null) ...[
              Icon(statusIcon, color: textColor, size: _optionIconSize),
              const SizedBox(width: AppConstants.spacingXS),
            ],
            Expanded(
              child: Text(
                options[index],
                style: TextStyle(fontSize: _optionFontSize, color: textColor),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
