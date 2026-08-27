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
  final int newCardsPerDay;
  final ValueChanged<int> onNewCardsPerDayChanged;
  final int sessionCardLimit;
  final ValueChanged<int> onSessionCardLimitChanged;

  const ReviewSettingsSection({
    super.key,
    required this.l10n,
    required this.desiredRetention,
    required this.onChanged,
    required this.newCardsPerDay,
    required this.onNewCardsPerDayChanged,
    required this.sessionCardLimit,
    required this.onSessionCardLimitChanged,
  });

  /// Slider positions are 0 (unlimited) then multiples of 10; anything landing
  /// between 0 and the real minimum snaps up to the minimum.
  static int _snap(double v) {
    final rounded = v.round();
    if (rounded <= 0) return 0;
    return rounded < SettingsService.minSessionCardLimit
        ? SettingsService.minSessionCardLimit
        : rounded;
  }

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
            const SizedBox(height: AppConstants.spacingL),
            Row(
              children: [
                Expanded(child: Text(l10n.newCardsPerDay)),
                Text(
                  newCardsPerDay == 0
                      ? l10n.unlimited
                      : newCardsPerDay.toString(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            Slider(
              value: newCardsPerDay.toDouble(),
              min: 0,
              max: SettingsService.maxNewCardsPerDay.toDouble(),
              divisions: SettingsService.maxNewCardsPerDay ~/ 5,
              label: newCardsPerDay == 0
                  ? l10n.unlimited
                  : newCardsPerDay.toString(),
              onChanged: (v) => onNewCardsPerDayChanged(v.round()),
            ),
            Text(
              l10n.newCardsPerDayDescription,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: AppConstants.fontSizeCaption,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Row(
              children: [
                Expanded(child: Text(l10n.sessionCardLimit)),
                Text(
                  sessionCardLimit == 0
                      ? l10n.unlimited
                      : sessionCardLimit.toString(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            Slider(
              value: sessionCardLimit.toDouble(),
              min: 0,
              max: SettingsService.maxSessionCardLimit.toDouble(),
              divisions: SettingsService.maxSessionCardLimit ~/ 10,
              label: sessionCardLimit == 0
                  ? l10n.unlimited
                  : sessionCardLimit.toString(),
              onChanged: (v) => onSessionCardLimitChanged(_snap(v)),
            ),
            Text(
              l10n.sessionCardLimitDescription,
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
