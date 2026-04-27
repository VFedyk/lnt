import '../../theme/term_status_ui.dart';
import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../../utils/constants.dart';

/// A reusable progress indicator for review screens
///
/// Displays the current progress (X of Y) and a colored status dot
class ReviewProgressIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final int termStatus;
  final double statusDotSize;
  final bool showStatusDot;

  const ReviewProgressIndicator({
    super.key,
    required this.currentIndex,
    required this.totalCount,
    required this.termStatus,
    this.statusDotSize = 12.0,
    this.showStatusDot = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final statusColor = TermStatusUI.colorFor(termStatus);
    final progressColor = context.appColors.success;
    final progress = totalCount > 0 ? (currentIndex + 1) / totalCount : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.reviewProgress(currentIndex + 1, totalCount),
                style: TextStyle(color: AppConstants.subtitleColor),
              ),
              if (showStatusDot)
                Container(
                  width: statusDotSize,
                  height: statusDotSize,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXS),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
            child: LinearProgressIndicator(
              value: progress,
              color: progressColor,
              minHeight: AppConstants.spacingXS,
            ),
          ),
        ],
      ),
    );
  }
}
