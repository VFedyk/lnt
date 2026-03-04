import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';

/// Returns a localized display name for an ISO 639-1 language [code].
/// The code is case-insensitive. Falls back to the raw code if unknown.
String localizedLangName(AppLocalizations l10n, String code) =>
    switch (code.toLowerCase()) {
      'ar' => l10n.langArabic,
      'bg' => l10n.langBulgarian,
      'zh' => l10n.langChineseMandarin,
      'cs' => l10n.langCzech,
      'da' => l10n.langDanish,
      'nl' => l10n.langDutch,
      'en' => l10n.langEnglish,
      'et' => l10n.langEstonian,
      'fi' => l10n.langFinnish,
      'fr' => l10n.langFrench,
      'de' => l10n.langGerman,
      'el' => l10n.langGreek,
      'he' => l10n.langHebrew,
      'hi' => l10n.langHindi,
      'hu' => l10n.langHungarian,
      'id' => l10n.langIndonesian,
      'ga' => l10n.langIrish,
      'it' => l10n.langItalian,
      'ja' => l10n.langJapanese,
      'ko' => l10n.langKorean,
      'lv' => l10n.langLatvian,
      'lt' => l10n.langLithuanian,
      'nb' => l10n.langNorwegian,
      'pl' => l10n.langPolish,
      'pt' => l10n.langPortuguese,
      'ro' => l10n.langRomanian,
      'ru' => l10n.langRussian,
      'sk' => l10n.langSlovak,
      'sl' => l10n.langSlovenian,
      'es' => l10n.langSpanish,
      'sv' => l10n.langSwedish,
      'th' => l10n.langThai,
      'tr' => l10n.langTurkish,
      'uk' => l10n.langUkrainian,
      'vi' => l10n.langVietnamese,
      _ => code,
    };

/// Returns a sort key for [s] that places Ukrainian special letters
/// (Є, І, Ї, Ґ) in their correct alphabetical positions.
/// Their Unicode code points fall before А (U+0410), so a plain compareTo
/// puts them first — we remap them via their nearest in-block neighbour plus
/// a private-use suffix.
String langSortKey(String s, Locale locale) {
  final lower = s.toLowerCase();
  if (locale.languageCode != 'uk') return lower;
  return lower
      .replaceAll('\u0454', '\u0435\uE000') // є → after е (U+0435), before ж
      .replaceAll('\u0456', '\u0438\uE001') // і → after и (U+0438), before й
      .replaceAll('\u0457', '\u0438\uE002') // ї → after і, before й
      .replaceAll('\u0491', '\u0433\uE000'); // ґ → after г (U+0433), before д
}
