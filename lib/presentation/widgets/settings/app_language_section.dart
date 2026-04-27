import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';

class AppLanguageSection extends StatelessWidget {
  final AppLocalizations l10n;
  final Locale selectedLocale;
  final ValueChanged<Locale> onLocaleChanged;

  const AppLanguageSection({
    super.key,
    required this.l10n,
    required this.selectedLocale,
    required this.onLocaleChanged,
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
                const Icon(Icons.language),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  l10n.appLanguage,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingL),
            SegmentedButton<Locale>(
              segments: [
                ButtonSegment(
                  value: const Locale('en'),
                  label: Text(l10n.english),
                ),
                ButtonSegment(
                  value: const Locale('uk'),
                  label: Text(l10n.ukrainian),
                ),
              ],
              selected: {selectedLocale},
              onSelectionChanged: (selected) {
                onLocaleChanged(selected.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}
