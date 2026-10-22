import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';

/// Switches controlling how dictionary WebView pages are themed while loading.
class DictionarySettingsSection extends StatelessWidget {
  final AppLocalizations l10n;
  final bool darkenPages;
  final ValueChanged<bool> onDarkenPagesChanged;
  final bool coverOnNavigation;
  final ValueChanged<bool> onCoverOnNavigationChanged;

  const DictionarySettingsSection({
    super.key,
    required this.l10n,
    required this.darkenPages,
    required this.onDarkenPagesChanged,
    required this.coverOnNavigation,
    required this.onCoverOnNavigationChanged,
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
                const Icon(Icons.menu_book_outlined),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: Text(
                    l10n.dictionarySettingsTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingS),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.dictionaryCoverNavigation),
              subtitle: Text(l10n.dictionaryCoverNavigationHint),
              value: coverOnNavigation,
              onChanged: onCoverOnNavigationChanged,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.dictionaryDarkenPages),
              subtitle: Text(l10n.dictionaryDarkenPagesHint),
              value: darkenPages,
              onChanged: onDarkenPagesChanged,
            ),
          ],
        ),
      ),
    );
  }
}
