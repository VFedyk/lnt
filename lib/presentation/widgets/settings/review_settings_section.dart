import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/settings_service.dart';
import '../../../utils/constants.dart';

/// Lets the user choose the FSRS desired retention rate. Higher retention
/// schedules reviews more frequently for stronger recall.
class ReviewSettingsSection extends StatelessWidget {
  final AppLocalizations l10n;
  final double desiredRetention;
  final ValueChanged<double> onChanged;

  const ReviewSettingsSection({
    super.key,
    required this.l10n,
    required this.desiredRetention,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (desiredRetention * 100).round();
    final divisions = ((SettingsService.maxDesiredRetention -
                SettingsService.minDesiredRetention) *
            100)
        .round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_repeat_outlined),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  l10n.reviewSettings,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingL),
            Row(
              children: [
                Expanded(child: Text(l10n.targetRetention)),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            Slider(
              value: desiredRetention,
              min: SettingsService.minDesiredRetention,
              max: SettingsService.maxDesiredRetention,
              divisions: divisions,
              label: '$percent%',
              onChanged: onChanged,
            ),
            Text(
              l10n.targetRetentionDescription,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: AppConstants.fontSizeCaption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
