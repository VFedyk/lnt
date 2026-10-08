import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/term.dart';
import 'package:language_nerd_tools/l10n/generated/app_localizations.dart';
import 'package:language_nerd_tools/presentation/controllers/reader_controller.dart';
import 'package:language_nerd_tools/presentation/widgets/reader/word_tooltip.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Term term({String romanization = '', String ipa = '', String translation = ''}) =>
      Term(
        id: 't1',
        languageId: 'l1',
        text: 'water',
        lowerText: 'water',
        romanization: romanization,
        ipa: ipa,
        translation: translation,
      );

  String plain(WordTooltipData data) =>
      buildWordTooltipSpan(data, l10n)!.toPlainText(includePlaceholders: false);

  WordTooltipData forTerm(
    Term t, {
    List<Translation>? translations,
    int count = 0,
    Map<String, Translation> byId = const {},
    Map<String, Term> termsById = const {},
  }) =>
      WordTooltipData.forTerm(
        term: t,
        translations: translations,
        translationsById: byId,
        termsById: termsById,
        sentenceCount: count,
        l10n: l10n,
      );

  test('IPA sits after romanization and before translations', () {
    final text = plain(forTerm(
      term(romanization: 'rom', ipa: '/ˈwɔːtə/'),
      translations: [Translation(termId: 't1', meaning: 'вода')],
    ));
    expect(text, 'rom\n/ˈwɔːtə/\nвода');
  });

  test('example line is pluralised and hidden at zero', () {
    final base = term(translation: 'x');
    expect(plain(forTerm(base, count: 3)), contains('3 examples'));
    expect(plain(forTerm(base, count: 1)), contains('1 example'));
    expect(plain(forTerm(base, count: 1)), isNot(contains('1 examples')));
    expect(plain(forTerm(base)), isNot(contains('example')));
  });

  test('only-IPA term has a tooltip; empty term has none', () {
    expect(buildWordTooltipSpan(forTerm(term(ipa: '/x/')), l10n), isNotNull);
    expect(buildWordTooltipSpan(forTerm(term()), l10n), isNull);
  });

  test('forForeign includes IPA, language name and example count', () {
    final data = WordTooltipData.forForeign(
      ForeignTermInfo(
        term: term(ipa: '/vasɐ/'),
        translations: [Translation(termId: 't1', meaning: 'water')],
        languageName: 'German',
        languageId: 'l2',
        sentenceCount: 2,
      ),
      l10n,
    );
    expect(plain(data), '/vasɐ/\nwater\n(German)\n 2 examples');
  });

  test('keeps POS in parentheses and the base-form line', () {
    final base = Translation(id: 'b1', termId: 't0', meaning: 'to be');
    final t = Translation(
      termId: 't1',
      meaning: 'is',
      partOfSpeech: 'verb',
      baseTranslationId: 'b1',
    );
    final text = plain(forTerm(
      term(),
      translations: [t],
      byId: {'b1': base},
      termsById: {'t0': Term(id: 't0', languageId: 'l1', text: 'be', lowerText: 'be')},
    ));
    expect(text, 'is (${l10n.posVerb}) ← be (to be)');
  });
}
