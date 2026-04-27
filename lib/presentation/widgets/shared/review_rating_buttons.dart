import 'package:flutter/material.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../../utils/constants.dart';

/// Rating buttons row shared by flashcard and stroke review screens.
///
/// Displays four [OutlinedButton]s (Again / Hard / Good / Easy) with optional
/// next-interval labels below each button.
class ReviewRatingButtons extends StatelessWidget {
  final Map<fsrs.Rating, Duration>? nextIntervals;
  final Future<void> Function(fsrs.Rating) onRate;

  static const double _buttonSpacing = 8.0;
  static const double _intervalFontSize = 11.0;

  const ReviewRatingButtons({
    super.key,
    required this.onRate,
    this.nextIntervals,
  });

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) return '${duration.inDays}d';
    if (duration.inHours > 0) return '${duration.inHours}h';
    return '${duration.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        _buildButton(
          context,
          label: l10n.rateAgain,
          rating: fsrs.Rating.again,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(width: _buttonSpacing),
        _buildButton(
          context,
          label: l10n.rateHard,
          rating: fsrs.Rating.hard,
          color: context.appColors.warning,
        ),
        const SizedBox(width: _buttonSpacing),
        _buildButton(
          context,
          label: l10n.rateGood,
          rating: fsrs.Rating.good,
          color: context.appColors.success,
        ),
        const SizedBox(width: _buttonSpacing),
        _buildButton(
          context,
          label: l10n.rateEasy,
          rating: fsrs.Rating.easy,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String label,
    required fsrs.Rating rating,
    required Color color,
  }) {
    final interval = nextIntervals?[rating];
    return Expanded(
      child: OutlinedButton(
        onPressed: () => onRate(rating),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (interval != null)
              Text(
                _formatDuration(interval),
                style: TextStyle(
                  fontSize: _intervalFontSize,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
