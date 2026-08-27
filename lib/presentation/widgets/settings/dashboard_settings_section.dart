import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/settings_service.dart';
import '../../../utils/constants.dart';

/// Lets the user choose how many books the dashboard's Reading progress
/// widget shows.
class DashboardSettingsSection extends StatelessWidget {
  final AppLocalizations l10n;
  final int bookProgressLimit;
  final ValueChanged<int> onBookProgressLimitChanged;

  const DashboardSettingsSection({
    super.key,
    required this.l10n,
    required this.bookProgressLimit,
    required this.onBookProgressLimitChanged,
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
                const Icon(Icons.dashboard_outlined),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  l10n.dashboardSettings,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingL),
            Row(
              children: [
                Expanded(child: Text(l10n.readingProgressItems)),
                Text(
                  '$bookProgressLimit',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            Slider(
              value: bookProgressLimit.toDouble(),
              min: SettingsService.minBookProgressLimit.toDouble(),
              max: SettingsService.maxBookProgressLimit.toDouble(),
              divisions:
                  SettingsService.maxBookProgressLimit -
                  SettingsService.minBookProgressLimit,
              label: '$bookProgressLimit',
              onChanged: (v) => onBookProgressLimitChanged(v.round()),
            ),
            Text(
              l10n.readingProgressItemsDescription,
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
