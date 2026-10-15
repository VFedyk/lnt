import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:language_nerd_tools/application/use_cases/languages/create_language.dart';
import 'package:language_nerd_tools/domain/entities/dictionary.dart';
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/domain/repositories/dictionary_repository.dart';
import 'package:language_nerd_tools/domain/repositories/language_repository.dart';
import 'package:language_nerd_tools/services/settings_service.dart';

class _MockLanguages extends Mock implements LanguageRepository {}

class _MockDictionaries extends Mock implements DictionaryRepository {}

class _MockSettings extends Mock implements SettingsService {}

void main() {
  setUpAll(() {
    registerFallbackValue(Language(name: 'x', languageCode: 'x'));
    registerFallbackValue(Dictionary(languageId: 'x', name: 'x', url: 'x'));
  });

  late _MockLanguages languages;
  late _MockDictionaries dictionaries;
  late _MockSettings settings;
  late CreateLanguage useCase;

  final draft = Language(name: 'German', languageCode: 'DE');

  setUp(() {
    languages = _MockLanguages();
    dictionaries = _MockDictionaries();
    settings = _MockSettings();
    useCase = CreateLanguage(
      languages: languages,
      dictionaries: dictionaries,
      settings: settings,
    );
    when(() => settings.getTargetLang()).thenAnswer((_) async => 'EN');
    when(() => dictionaries.create(any())).thenAnswer((_) async => 'd1');
  });

  test('creates the language, then its dictionary, and returns the id', () async {
    final calls = <String>[];
    Dictionary? dict;
    when(() => languages.create(any())).thenAnswer((_) async {
      calls.add('language');
      return 'l1';
    });
    when(() => dictionaries.create(any())).thenAnswer((i) async {
      calls.add('dictionary');
      dict = i.positionalArguments.single as Dictionary;
      return 'd1';
    });

    final saved = await useCase(draft);

    expect(saved.id, 'l1');
    expect(saved.name, 'German');
    expect(calls, ['language', 'dictionary']);
    expect(dict!.languageId, 'l1');
    expect(dict!.name, 'Google Translate DE-EN');
    expect(dict!.url,
        'https://translate.google.com/?sl=de&tl=en&text=###&op=translate');
  });
  test('creates no dictionary and rethrows when the insert fails', () async {
    when(() => languages.create(any())).thenThrow(Exception('boom'));

    await expectLater(useCase(draft), throwsException);
    verifyNever(() => dictionaries.create(any()));
  });
}
