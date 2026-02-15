import 'package:flutter/material.dart';

import '../../../utils/constants.dart';

abstract class _LibraryStatusBarConstants {
  static const double sortIconSize = 16.0;
  static const double badgeVerticalPadding = 2.0;
}

class LibraryStatusBar extends StatelessWidget {
  final IconData sortIcon;
  final String sortLabel;
  final bool showHiddenBadge;
  final String hiddenCountLabel;
  final String textCountLabel;

  const LibraryStatusBar({
    super.key,
    required this.sortIcon,
    required this.sortLabel,
    required this.showHiddenBadge,
    required this.hiddenCountLabel,
    required this.textCountLabel,
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
            size: _LibraryStatusBarConstants.sortIconSize,
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
                vertical: _LibraryStatusBarConstants.badgeVerticalPadding,
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
