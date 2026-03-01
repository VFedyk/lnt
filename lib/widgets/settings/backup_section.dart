import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../utils/constants.dart';

class BackupSection extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isApplePlatform;
  final bool busy;
  final double? restoreProgress;
  final String iCloudBackupLabel;
  final VoidCallback onBackupToICloud;
  final VoidCallback onRestoreFromICloud;

  const BackupSection({
    super.key,
    required this.l10n,
    required this.isApplePlatform,
    required this.busy,
    required this.iCloudBackupLabel,
    required this.onBackupToICloud,
    required this.onRestoreFromICloud,
    this.restoreProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  l10n.backupRestore,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (busy && restoreProgress == null) ...[
                  const SizedBox(width: AppConstants.spacingM),
                  SizedBox(
                    width: AppConstants.progressIndicatorSizeS,
                    height: AppConstants.progressIndicatorSizeS,
                    child: const CircularProgressIndicator(
                      strokeWidth: AppConstants.progressStrokeWidth,
                    ),
                  ),
                ],
              ],
            ),
            if (restoreProgress != null) ...[
              const SizedBox(height: AppConstants.spacingS),
              LinearProgressIndicator(value: restoreProgress),
            ],
            if (isApplePlatform) ...[
              const SizedBox(height: AppConstants.spacingL),
              Text('iCloud', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppConstants.spacingXS),
              Text(
                iCloudBackupLabel,
                style: TextStyle(
                  fontSize: AppConstants.fontSizeCaption,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              Wrap(
                spacing: AppConstants.spacingS,
                runSpacing: AppConstants.spacingS,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : onBackupToICloud,
                    icon: const Icon(Icons.cloud_upload),
                    label: Text(l10n.backupToICloud),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onRestoreFromICloud,
                    icon: const Icon(Icons.cloud_download),
                    label: Text(l10n.restoreFromICloud),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
