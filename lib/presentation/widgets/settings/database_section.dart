import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';

class DatabaseSection extends StatelessWidget {
  final AppLocalizations l10n;
  final String dbPath;
  final VoidCallback onOpenDatabaseDirectory;
  final VoidCallback onChangeDatabase;

  const DatabaseSection({
    super.key,
    required this.l10n,
    required this.dbPath,
    required this.onOpenDatabaseDirectory,
    required this.onChangeDatabase,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storage),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  l10n.databaseSection,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              l10n.databasePath,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppConstants.spacingM),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: SelectableText(
                dbPath,
                style: TextStyle(
                  fontSize: AppConstants.fontSizeCaption,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Wrap(
              spacing: AppConstants.spacingS,
              runSpacing: AppConstants.spacingS,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenDatabaseDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: Text(l10n.openDatabaseDirectory),
                ),
                OutlinedButton.icon(
                  onPressed: onChangeDatabase,
                  icon: const Icon(Icons.swap_horiz),
                  label: Text(l10n.changeDatabase),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
