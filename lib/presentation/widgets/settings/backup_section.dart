import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';

class BackupSection extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isApplePlatform;
  final bool busy;
  final bool isCheckingBackup;
  final double? restoreProgress;
  /// iCloud upload progress while a backup is in flight.
  final double? backupProgress;
  final String iCloudDeviceBackupLabel;
  final String iCloudRemoteBackupLabel;
  final String lastRestoreLabel;
  final VoidCallback onBackupToICloud;
  final VoidCallback onRestoreFromICloud;
  final VoidCallback onRecheckICloudBackup;

  const BackupSection({
    super.key,
    required this.l10n,
    required this.isApplePlatform,
    required this.busy,
    required this.isCheckingBackup,
    required this.iCloudDeviceBackupLabel,
    required this.iCloudRemoteBackupLabel,
    required this.lastRestoreLabel,
    required this.onBackupToICloud,
    required this.onRestoreFromICloud,
    required this.onRecheckICloudBackup,
    this.restoreProgress,
    this.backupProgress,
  });

  @override
  Widget build(BuildContext context) {
    final captionStyle = TextStyle(
      fontSize: AppConstants.fontSizeCaption,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

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
                if (busy && restoreProgress == null && backupProgress == null) ...[
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
            // Real upload progress: the copy into the container is instant, but
            // the transfer to iCloud is what decides whether another device
            // will ever see this backup.
            if (backupProgress != null) ...[
              const SizedBox(height: AppConstants.spacingS),
              LinearProgressIndicator(value: backupProgress),
            ],
            if (isApplePlatform) ...[
              const SizedBox(height: AppConstants.spacingL),
              Text('iCloud', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppConstants.spacingXS),
              Text(iCloudDeviceBackupLabel, style: captionStyle),
              const SizedBox(height: AppConstants.spacingXS),
              // Remote backup row with recheck button
              Row(
                children: [
                  Expanded(
                    child: Text(iCloudRemoteBackupLabel, style: captionStyle),
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  SizedBox(
                    width: AppConstants.progressIndicatorSizeS,
                    height: AppConstants.progressIndicatorSizeS,
                    child: isCheckingBackup
                        ? const CircularProgressIndicator(
                            strokeWidth: AppConstants.progressStrokeWidth,
                          )
                        : IconButton.outlined(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: AppConstants.fontSizeBody,
                            onPressed: busy ? null : onRecheckICloudBackup,
                            icon: const Icon(Icons.refresh),
                            tooltip: l10n.refresh,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingXS),
              Text(lastRestoreLabel, style: captionStyle),
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
