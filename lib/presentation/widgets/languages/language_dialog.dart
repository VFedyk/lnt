import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/language.dart';
import '../../../domain/value_objects/text_parsing_defaults.dart';
import '../../../utils/constants.dart';
import '../../../utils/language_utils.dart';

class _LangPreset {
  final String name;
  final String code;
  final bool rightToLeft;
  final bool splitByCharacter;
  final bool useWordSegmentation;

  const _LangPreset(
    this.name,
    this.code, {
    this.rightToLeft = false,
    this.splitByCharacter = false,
    this.useWordSegmentation = false,
  });

  String get flagEmoji {
    const langToCountry = {
      'ar': 'SA', 'bg': 'BG', 'cs': 'CZ', 'da': 'DK', 'de': 'DE',
      'el': 'GR', 'en': 'GB', 'es': 'ES', 'et': 'EE', 'fi': 'FI',
      'fr': 'FR', 'ga': 'IE', 'he': 'IL', 'hi': 'IN', 'hu': 'HU',
      'id': 'ID', 'it': 'IT', 'ja': 'JP', 'ko': 'KR', 'lt': 'LT',
      'lv': 'LV', 'nb': 'NO', 'nl': 'NL', 'pl': 'PL', 'pt': 'PT',
      'ro': 'RO', 'ru': 'RU', 'sk': 'SK', 'sl': 'SI', 'sv': 'SE',
      'th': 'TH', 'tr': 'TR', 'uk': 'UA', 'vi': 'VN', 'zh': 'CN',
      'yue': 'HK',
      'la': 'IT', 'grc': 'GR', 'sa': 'IN', 'ang': 'GB', 'non': 'IS',
      'got': 'SE', 'sux': 'IQ', 'cu': 'BG',
    };
    final country = langToCountry[code];
    if (country == null) return '';
    final first = 0x1F1E6 + country.codeUnitAt(0) - 0x41;
    final second = 0x1F1E6 + country.codeUnitAt(1) - 0x41;
    return String.fromCharCodes([first, second]);
  }
}

const _kPresets = <_LangPreset>[
  _LangPreset('Arabic', 'ar', rightToLeft: true),
  _LangPreset('Bulgarian', 'bg'),
  _LangPreset('Chinese (Mandarin)', 'zh', splitByCharacter: true, useWordSegmentation: true),
  _LangPreset('Chinese (Cantonese)', 'yue', splitByCharacter: true),
  _LangPreset('Czech', 'cs'),
  _LangPreset('Danish', 'da'),
  _LangPreset('Dutch', 'nl'),
  _LangPreset('English', 'en'),
  _LangPreset('Estonian', 'et'),
  _LangPreset('Finnish', 'fi'),
  _LangPreset('French', 'fr'),
  _LangPreset('German', 'de'),
  _LangPreset('Greek', 'el'),
  _LangPreset('Hebrew', 'he', rightToLeft: true),
  _LangPreset('Hindi', 'hi'),
  _LangPreset('Hungarian', 'hu'),
  _LangPreset('Indonesian', 'id'),
  _LangPreset('Irish', 'ga'),
  _LangPreset('Italian', 'it'),
  _LangPreset('Japanese', 'ja', splitByCharacter: true),
  _LangPreset('Korean', 'ko', splitByCharacter: true),
  _LangPreset('Latvian', 'lv'),
  _LangPreset('Lithuanian', 'lt'),
  _LangPreset('Norwegian', 'nb'),
  _LangPreset('Polish', 'pl'),
  _LangPreset('Portuguese', 'pt'),
  _LangPreset('Romanian', 'ro'),
  _LangPreset('Russian', 'ru'),
  _LangPreset('Slovak', 'sk'),
  _LangPreset('Slovenian', 'sl'),
  _LangPreset('Spanish', 'es'),
  _LangPreset('Swedish', 'sv'),
  _LangPreset('Thai', 'th', splitByCharacter: true),
  _LangPreset('Turkish', 'tr'),
  _LangPreset('Ukrainian', 'uk'),
  _LangPreset('Vietnamese', 'vi'),
  // Classical / ancient languages
  _LangPreset('Latin', 'la'),
  _LangPreset('Ancient Greek', 'grc'),
  _LangPreset('Sanskrit', 'sa'),
  _LangPreset('Old English', 'ang'),
  _LangPreset('Old Norse', 'non'),
  _LangPreset('Literary Chinese', 'lzh', splitByCharacter: true),
  _LangPreset('Gothic', 'got'),
  _LangPreset('Sumerian', 'sux'),
  _LangPreset('Old Church Slavonic', 'cu'),
  // Constructed / fictional
  _LangPreset('Esperanto', 'eo'),
  _LangPreset('Interlingua', 'ia'),
  _LangPreset('Lojban', 'jbo'),
  _LangPreset('Klingon', 'tlh'),
  _LangPreset('Quenya', 'qya'),
  _LangPreset('Sindarin', 'sjn'),
];

class LanguageDialog extends StatefulWidget {
  final Language? language;

  const LanguageDialog({super.key, this.language});

  @override
  State<LanguageDialog> createState() => _LanguageDialogState();
}


class _LanguageDialogState extends State<LanguageDialog> {
  final _formKey = GlobalKey<FormState>();
  _LangPreset? _selectedPreset;
  late bool _showRomanization;
  late bool _splitByCharacter;
  late bool _useWordSegmentation;

  @override
  void initState() {
    super.initState();
    final lang = widget.language;
    if (lang != null) {
      _selectedPreset = _kPresets
          .where((p) => p.code == lang.languageCode)
          .firstOrNull;
    }
    _showRomanization = lang?.showRomanization ?? false;
    _splitByCharacter = lang?.splitByCharacter ?? (_selectedPreset?.splitByCharacter ?? false);
    _useWordSegmentation = lang?.useWordSegmentation ?? (_selectedPreset?.useWordSegmentation ?? false);
  }

  void _onPresetChanged(_LangPreset? preset) {
    setState(() {
      _selectedPreset = preset;
      if (preset != null) {
        _splitByCharacter = preset.splitByCharacter;
        _useWordSegmentation = preset.useWordSegmentation;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context);
    final isCJK = _selectedPreset?.splitByCharacter ?? false;
    final sortedPresets = [..._kPresets]
      ..sort((a, b) => langSortKey(localizedLangName(l10n, a.code), locale)
          .compareTo(langSortKey(localizedLangName(l10n, b.code), locale)));

    return AlertDialog(
      title: Text(
        widget.language == null ? l10n.addLanguage : l10n.editLanguage,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<_LangPreset>(
                initialValue: _selectedPreset,
                decoration: InputDecoration(labelText: l10n.languageNameLabel),
                isExpanded: true,
                items: sortedPresets.map((preset) {
                  final flag = preset.flagEmoji;
                  return DropdownMenuItem<_LangPreset>(
                    value: preset,
                    child: Text('${flag.isNotEmpty ? '$flag ' : ''}${localizedLangName(l10n, preset.code)}'),
                  );
                }).toList(),
                onChanged: _onPresetChanged,
                validator: (v) => v == null ? l10n.required : null,
              ),
              const SizedBox(height: AppConstants.spacingL),
              SwitchListTile(
                title: Text(l10n.showRomanization),
                subtitle: Text(l10n.showRomanizationHint),
                value: _showRomanization,
                onChanged: (v) => setState(() => _showRomanization = v),
                contentPadding: EdgeInsets.zero,
              ),
              if (isCJK) ...[
                SwitchListTile(
                  title: Text(l10n.splitByCharacter),
                  subtitle: Text(l10n.splitByCharacterHint),
                  value: _splitByCharacter,
                  onChanged: (v) => setState(() {
                    _splitByCharacter = v;
                    if (!v) _useWordSegmentation = false;
                  }),
                  contentPadding: EdgeInsets.zero,
                ),
                if (_splitByCharacter)
                  SwitchListTile(
                    title: const Text('Word segmentation (Chinese)'),
                    subtitle: const Text(
                      'Use jieba to split text into words instead of individual characters. '
                      'Recommended for Mandarin Chinese.',
                    ),
                    value: _useWordSegmentation,
                    onChanged: (v) => setState(() => _useWordSegmentation = v),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
              const SizedBox(height: AppConstants.spacingS),
              Container(
                padding: const EdgeInsets.all(AppConstants.spacingM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20.0,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Text(
                        l10n.addDictionariesAfterCreating,
                        style: TextStyle(
                          fontSize: 13.0,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final preset = _selectedPreset!;
              final existing = widget.language;
              final lang = Language(
                id: existing?.id,
                name: localizedLangName(l10n, preset.code),
                languageCode: preset.code,
                rightToLeft: preset.rightToLeft,
                showRomanization: _showRomanization,
                splitByCharacter: _splitByCharacter,
                useWordSegmentation: _useWordSegmentation,
                characterSubstitutions: existing?.characterSubstitutions ?? '',
                regexpWordCharacters: existing?.regexpWordCharacters ??
                    TextParsingDefaults.wordPattern,
                regexpSplitSentences: existing?.regexpSplitSentences ??
                    TextParsingDefaults.sentencePattern,
                exceptionsSplitSentences: existing?.exceptionsSplitSentences ?? '',
              );
              Navigator.pop(context, lang);
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
