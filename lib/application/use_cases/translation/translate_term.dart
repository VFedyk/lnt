import '../../../data/services/deepl_service.dart';
import '../../../data/services/libretranslate_service.dart';
import '../../../domain/entities/translation_result.dart';
import '../../../domain/value_objects/translation_provider.dart';
import '../../../services/settings_service.dart';

class TranslateTerm {
  TranslateTerm({
    required DeepLService deepL,
    required LibreTranslateService libreTranslate,
    required SettingsService settings,
  })  : _deepL = deepL,
        _libreTranslate = libreTranslate,
        _settings = settings;

  final DeepLService _deepL;
  final LibreTranslateService _libreTranslate;
  final SettingsService _settings;

  Future<TranslationResult> call({
    required String text,
    required String sourceLanguageCode,
    required TranslationProvider provider,
  }) async {
    final targetLang = await _settings.getTargetLang();

    if (provider == TranslationProvider.deepL) {
      final src = DeepLService.deeplCode(sourceLanguageCode);
      final tgt = DeepLService.deeplCode(targetLang);
      if (src == null || tgt == null) {
        return const TranslationResult.failure(TranslationError.unsupportedLanguage);
      }
      return _deepL.translate(text: text, sourceLang: src, targetLang: tgt);
    } else {
      final src = LibreTranslateService.libreCode(sourceLanguageCode);
      final tgt = LibreTranslateService.libreCode(targetLang);
      if (src == null || tgt == null) {
        return const TranslationResult.failure(TranslationError.unsupportedLanguage);
      }
      return _libreTranslate.translate(text: text, sourceLang: src, targetLang: tgt);
    }
  }
}
