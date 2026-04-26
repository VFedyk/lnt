import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:language_nerd_tools/application/use_cases/translation/translate_term.dart';
import 'package:language_nerd_tools/data/services/deepl_service.dart';
import 'package:language_nerd_tools/data/services/libretranslate_service.dart';
import 'package:language_nerd_tools/domain/entities/translation_result.dart';
import 'package:language_nerd_tools/domain/value_objects/translation_provider.dart';
import 'package:language_nerd_tools/services/settings_service.dart';

class MockDeepLService extends Mock implements DeepLService {}
class MockLibreTranslateService extends Mock implements LibreTranslateService {}
class MockSettingsService extends Mock implements SettingsService {}

void main() {
  late MockDeepLService mockDeepL;
  late MockLibreTranslateService mockLibre;
  late MockSettingsService mockSettings;
  late TranslateTerm useCase;

  setUp(() {
    mockDeepL = MockDeepLService();
    mockLibre = MockLibreTranslateService();
    mockSettings = MockSettingsService();
    useCase = TranslateTerm(
      deepL: mockDeepL,
      libreTranslate: mockLibre,
      settings: mockSettings,
    );
    // Default: target language is English (supported by both providers)
    when(() => mockSettings.getTargetLang()).thenAnswer((_) async => 'en');
  });

  group('DeepL provider', () {
    test('calls settings.getTargetLang() and deepL.translate() for supported language', () async {
      when(() => mockDeepL.translate(
        text: any(named: 'text'),
        sourceLang: any(named: 'sourceLang'),
        targetLang: any(named: 'targetLang'),
      )).thenAnswer((_) async => const TranslationResult.success('bonjour'));

      final result = await useCase(
        text: 'hello',
        sourceLanguageCode: 'fr',
        provider: TranslationProvider.deepL,
      );

      verify(() => mockSettings.getTargetLang()).called(1);
      verify(() => mockDeepL.translate(
        text: 'hello',
        sourceLang: any(named: 'sourceLang'),
        targetLang: any(named: 'targetLang'),
      )).called(1);
      expect(result.isSuccess, isTrue);
      expect(result.text, 'bonjour');
    });

    test('returns unsupportedLanguage without calling translate for unknown source code', () async {
      final result = await useCase(
        text: 'hello',
        sourceLanguageCode: 'xx',  // not in DeepL's supported list
        provider: TranslationProvider.deepL,
      );

      verifyNever(() => mockDeepL.translate(
        text: any(named: 'text'),
        sourceLang: any(named: 'sourceLang'),
        targetLang: any(named: 'targetLang'),
      ));
      expect(result.isSuccess, isFalse);
      expect(result.error, TranslationError.unsupportedLanguage);
    });

    test('passes through failure result from DeepL service', () async {
      when(() => mockDeepL.translate(
        text: any(named: 'text'),
        sourceLang: any(named: 'sourceLang'),
        targetLang: any(named: 'targetLang'),
      )).thenAnswer((_) async => const TranslationResult.failure(TranslationError.authFailed));

      final result = await useCase(
        text: 'hello',
        sourceLanguageCode: 'de',
        provider: TranslationProvider.deepL,
      );

      expect(result.error, TranslationError.authFailed);
    });
  });

  group('LibreTranslate provider', () {
    test('calls settings.getTargetLang() and libreTranslate.translate() for supported language', () async {
      when(() => mockLibre.translate(
        text: any(named: 'text'),
        sourceLang: any(named: 'sourceLang'),
        targetLang: any(named: 'targetLang'),
      )).thenAnswer((_) async => const TranslationResult.success('hola'));

      final result = await useCase(
        text: 'hello',
        sourceLanguageCode: 'es',
        provider: TranslationProvider.libreTranslate,
      );

      verify(() => mockSettings.getTargetLang()).called(1);
      verify(() => mockLibre.translate(
        text: 'hello',
        sourceLang: any(named: 'sourceLang'),
        targetLang: any(named: 'targetLang'),
      )).called(1);
      expect(result.isSuccess, isTrue);
    });

    test('returns unsupportedLanguage without calling translate for unknown source code', () async {
      final result = await useCase(
        text: 'hello',
        sourceLanguageCode: 'xx',  // not in LibreTranslate's supported list
        provider: TranslationProvider.libreTranslate,
      );

      verifyNever(() => mockLibre.translate(
        text: any(named: 'text'),
        sourceLang: any(named: 'sourceLang'),
        targetLang: any(named: 'targetLang'),
      ));
      expect(result.error, TranslationError.unsupportedLanguage);
    });

    test('does not call deepL when provider is libreTranslate', () async {
      when(() => mockLibre.translate(
        text: any(named: 'text'),
        sourceLang: any(named: 'sourceLang'),
        targetLang: any(named: 'targetLang'),
      )).thenAnswer((_) async => const TranslationResult.success('ok'));

      await useCase(
        text: 'hello',
        sourceLanguageCode: 'de',
        provider: TranslationProvider.libreTranslate,
      );

      verifyNever(() => mockDeepL.translate(
        text: any(named: 'text'),
        sourceLang: any(named: 'sourceLang'),
        targetLang: any(named: 'targetLang'),
      ));
    });
  });
}
