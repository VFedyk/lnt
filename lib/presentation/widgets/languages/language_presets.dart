import 'package:flutter/widgets.dart';

import '../../../domain/entities/language.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/language_utils.dart';

class LangPreset {
  final String name;
  final String code;
  final bool rightToLeft;
  final bool splitByCharacter;
  final bool useWordSegmentation;

  const LangPreset(
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

  /// A new, unsaved [Language] with this preset's defaults.
  /// [displayName] is the localized name (`localizedLangName(l10n, code)`).
  Language toLanguage(String displayName) => Language(
        name: displayName,
        languageCode: code,
        rightToLeft: rightToLeft,
        splitByCharacter: splitByCharacter,
        useWordSegmentation: useWordSegmentation,
      );
}

/// Codes shown as "Popular" chips in the quick picker, in display order.
const kPopularLangCodes = <String>[
  'en', 'es', 'fr', 'de', 'it', 'pt', 'nl', 'pl', 'uk', 'zh', 'ja', 'ko',
];

/// [presets] (default: all) sorted by localized name for [locale].
List<LangPreset> sortedLangPresets(
  AppLocalizations l10n,
  Locale locale, [
  Iterable<LangPreset> presets = kLangPresets,
]) =>
    [...presets]..sort((a, b) =>
        langSortKey(localizedLangName(l10n, a.code), locale)
            .compareTo(langSortKey(localizedLangName(l10n, b.code), locale)));

const kLangPresets = <LangPreset>[
  LangPreset('Arabic', 'ar', rightToLeft: true),
  LangPreset('Bulgarian', 'bg'),
  LangPreset('Chinese (Mandarin)', 'zh', splitByCharacter: true, useWordSegmentation: true),
  LangPreset('Chinese (Cantonese)', 'yue', splitByCharacter: true),
  LangPreset('Czech', 'cs'),
  LangPreset('Danish', 'da'),
  LangPreset('Dutch', 'nl'),
  LangPreset('English', 'en'),
  LangPreset('Estonian', 'et'),
  LangPreset('Finnish', 'fi'),
  LangPreset('French', 'fr'),
  LangPreset('German', 'de'),
  LangPreset('Greek', 'el'),
  LangPreset('Hebrew', 'he', rightToLeft: true),
  LangPreset('Hindi', 'hi'),
  LangPreset('Hungarian', 'hu'),
  LangPreset('Indonesian', 'id'),
  LangPreset('Irish', 'ga'),
  LangPreset('Italian', 'it'),
  LangPreset('Japanese', 'ja', splitByCharacter: true),
  LangPreset('Korean', 'ko', splitByCharacter: true),
  LangPreset('Latvian', 'lv'),
  LangPreset('Lithuanian', 'lt'),
  LangPreset('Norwegian', 'nb'),
  LangPreset('Polish', 'pl'),
  LangPreset('Portuguese', 'pt'),
  LangPreset('Romanian', 'ro'),
  LangPreset('Russian', 'ru'),
  LangPreset('Slovak', 'sk'),
  LangPreset('Slovenian', 'sl'),
  LangPreset('Spanish', 'es'),
  LangPreset('Swedish', 'sv'),
  LangPreset('Thai', 'th', splitByCharacter: true),
  LangPreset('Turkish', 'tr'),
  LangPreset('Ukrainian', 'uk'),
  LangPreset('Vietnamese', 'vi'),
  // Classical / ancient languages
  LangPreset('Latin', 'la'),
  LangPreset('Ancient Greek', 'grc'),
  LangPreset('Sanskrit', 'sa'),
  LangPreset('Old English', 'ang'),
  LangPreset('Old Norse', 'non'),
  LangPreset('Literary Chinese', 'lzh', splitByCharacter: true),
  LangPreset('Gothic', 'got'),
  LangPreset('Sumerian', 'sux'),
  LangPreset('Old Church Slavonic', 'cu'),
  // Constructed / fictional
  LangPreset('Esperanto', 'eo'),
  LangPreset('Interlingua', 'ia'),
  LangPreset('Lojban', 'jbo'),
  LangPreset('Klingon', 'tlh'),
  LangPreset('Quenya', 'qya'),
  LangPreset('Sindarin', 'sjn'),
];
