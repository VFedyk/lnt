import 'package:flutter/material.dart';

import '../../../utils/constants.dart';

class LibraryEmptyState extends StatelessWidget {
  final bool showCompletedState;
  final String allTextsCompletedLabel;
  final String showCompletedLabel;
  final String noCollectionsOrTextsLabel;
  final VoidCallback onShowCompleted;

  const LibraryEmptyState({
    super.key,
    required this.showCompletedState,
    required this.allTextsCompletedLabel,
    required this.showCompletedLabel,
    required this.noCollectionsOrTextsLabel,
    required this.onShowCompleted,
  });

  @override
  Widget build(BuildContext context) {
    if (!showCompletedState) {
      return Center(child: Text(noCollectionsOrTextsLabel));
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: AppConstants.emptyStateIconSize,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: AppConstants.spacingL),
          Text(
            allTextsCompletedLabel,
            style: TextStyle(
              fontSize: AppConstants.fontSizeSubtitle,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppConstants.spacingS),
          TextButton.icon(
            onPressed: onShowCompleted,
            icon: const Icon(Icons.visibility),
            label: Text(showCompletedLabel),
          ),
        ],
      ),
    );
  }
}
