import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../service_locator.dart';
import '../services/deepl_service.dart';
import '../services/libretranslate_service.dart';

enum TranslationProvider { deepL, libreTranslate }

mixin TranslationMixin<T extends StatefulWidget> on State<T> {
  bool _hasDeepL = false;
  bool _hasLibreTranslate = false;
  bool _isTranslating = false;

  bool get hasDeepL => _hasDeepL;
  bool get hasLibreTranslate => _hasLibreTranslate;
  bool get hasAnyTranslationProvider => _hasDeepL || _hasLibreTranslate;
  bool get hasMultipleTranslationProviders => _hasDeepL && _hasLibreTranslate;
  bool get isTranslating => _isTranslating;

  String get languageName;
  TextEditingController get sourceTextController;
  TextEditingController get translationTextController;

  Future<void> checkTranslationProviders() async {
    final hasDeepL = await settings.hasDeepLApiKey();
    final hasLT = await settings.hasLibreTranslateApiKey();
    if (mounted) {
      setState(() {
        _hasDeepL = hasDeepL;
        _hasLibreTranslate = hasLT;
      });
    }
  }

  Future<void> translateWithProvider(TranslationProvider provider) async {
    setState(() => _isTranslating = true);

    final targetLang = await settings.getDeepLTargetLang();
    String? translation;

    if (provider == TranslationProvider.deepL) {
      final sourceCode = DeepLService.getDeepLLanguageCode(languageName);
      if (sourceCode == null) {
        _showLanguageNotSupported('DeepL');
        setState(() => _isTranslating = false);
        return;
      }
      translation = await deepLService.translate(
        text: sourceTextController.text.trim(),
        sourceLang: sourceCode,
        targetLang: targetLang,
      );
    } else {
      final sourceCode = LibreTranslateService.getLanguageCode(languageName);
      if (sourceCode == null) {
        _showLanguageNotSupported('LibreTranslate');
        setState(() => _isTranslating = false);
        return;
      }
      translation = await libreTranslateService.translate(
        text: sourceTextController.text.trim(),
        sourceLang: sourceCode,
        targetLang: targetLang.toLowerCase(),
      );
    }

    if (mounted) {
      setState(() => _isTranslating = false);
      if (translation != null) {
        translationTextController.text = translation;
      } else {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.translationFailed)),
        );
      }
    }
  }

  void _showLanguageNotSupported(String providerName) {
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.languageNotSupported(languageName))),
      );
    }
  }
}
