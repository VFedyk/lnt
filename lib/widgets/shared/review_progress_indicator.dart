import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/term.dart';
import '../../utils/constants.dart';

/// A reusable progress indicator for review screens
///
/// Displays the current progress (X of Y) and a colored status dot
class ReviewProgressIndicator extends StatelessWidget {
  final int currentIndex;
  final int totalCount;
  final int termStatus;
  final double statusDotSize;

  const ReviewProgressIndicator({
    super.key,
    required this.currentIndex,
    required this.totalCount,
    required this.termStatus,
    this.statusDotSize = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.reviewProgress(currentIndex + 1, totalCount),
            style: TextStyle(color: AppConstants.subtitleColor),
          ),
          Container(
            width: statusDotSize,
            height: statusDotSize,
            decoration: BoxDecoration(
              color: TermStatus.colorFor(termStatus),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
