import 'package:flutter/material.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../utils/constants.dart';
import '../../utils/language_utils.dart';

class TargetLanguageSection extends StatelessWidget {
  final AppLocalizations l10n;
  // Stored as DeepL-format uppercase code (e.g. 'EN', 'UK', 'ZH').
  final String targetLang;
  final ValueChanged<String> onChanged;

  // Union of DeepL and LibreTranslate supported language codes (uppercase ISO 639-1).
  static const _codes = [
    'AR', 'BG', 'CS', 'DA', 'DE', 'EL', 'EN', 'ES', 'ET', 'FI',
    'FR', 'GA', 'HE', 'HI', 'HU', 'ID', 'IT', 'JA', 'KO', 'LT',
    'LV', 'NB', 'NL', 'PL', 'PT', 'RO', 'RU', 'SK', 'SL', 'SV',
    'TH', 'TR', 'UK', 'VI', 'ZH',
  ];

  const TargetLanguageSection({
    super.key,
    required this.l10n,
    required this.targetLang,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final sorted = [..._codes]
      ..sort((a, b) => langSortKey(localizedLangName(l10n, a), locale)
          .compareTo(langSortKey(localizedLangName(l10n, b), locale)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.translate_outlined),
                const SizedBox(width: AppConstants.spacingS),
                Text(
                  l10n.targetLanguage,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingL),
            DropdownButtonFormField<String>(
              initialValue: targetLang,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingM,
                  vertical: AppConstants.spacingS,
                ),
              ),
              items: sorted
                  .map(
                    (code) => DropdownMenuItem(
                      value: code,
                      child: Text(localizedLangName(l10n, code)),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              l10n.languageForTranslations,
              style: TextStyle(
                color: AppConstants.subtitleColor,
                fontSize: AppConstants.fontSizeCaption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
