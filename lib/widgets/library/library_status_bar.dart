import 'package:flutter/material.dart';

import '../../../utils/constants.dart';

class LibraryStatusBar extends StatelessWidget {
  final IconData sortIcon;
  final String sortLabel;
  final bool showHiddenBadge;
  final String hiddenCountLabel;
  final String textCountLabel;
  final double iconSize;
  final double badgeVerticalPadding;

  const LibraryStatusBar({
    super.key,
    required this.sortIcon,
    required this.sortLabel,
    required this.showHiddenBadge,
    required this.hiddenCountLabel,
    required this.textCountLabel,
    required this.iconSize,
    required this.badgeVerticalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingL,
        vertical: AppConstants.spacingS,
      ),
      child: Row(
        children: [
          Icon(
            sortIcon,
            size: iconSize,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: AppConstants.spacingXS),
          Text(
            sortLabel,
            style: TextStyle(
              fontSize: AppConstants.fontSizeCaption,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          if (showHiddenBadge) ...[
            const SizedBox(width: AppConstants.spacingM),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.spacingS,
                vertical: badgeVerticalPadding,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
              ),
              child: Text(
                hiddenCountLabel,
                style: TextStyle(
                  fontSize: AppConstants.fontSizeCaption,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
          const Spacer(),
          Text(
            textCountLabel,
            style: TextStyle(
              fontSize: AppConstants.fontSizeCaption,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
