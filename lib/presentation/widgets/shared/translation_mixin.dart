import 'package:flutter/material.dart';
import '../../../application/use_cases/translation/translate_term.dart';
import '../../../domain/entities/translation_result.dart';
import '../../../domain/value_objects/translation_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../service_locator.dart';

export '../../../domain/value_objects/translation_provider.dart';

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
  String get languageCode; // ISO 639-1, lowercase (e.g. 'ja', 'de')
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

    final result = await sl<TranslateTerm>().call(
      text: sourceTextController.text.trim(),
      sourceLanguageCode: languageCode,
      provider: provider,
    );

    if (mounted) {
      setState(() => _isTranslating = false);
      if (result.isSuccess) {
        translationTextController.text = result.text!;
      } else if (result.error == TranslationError.unsupportedLanguage) {
        _showLanguageNotSupported();
      } else {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(l10n, result.error!))),
        );
      }
    }
  }

  String _errorMessage(AppLocalizations l10n, TranslationError error) {
    return switch (error) {
      TranslationError.authFailed => l10n.translationAuthFailed,
      TranslationError.rateLimited => l10n.translationRateLimited,
      TranslationError.networkError => l10n.translationNetworkError,
      TranslationError.serverError => l10n.translationServerError,
      TranslationError.unsupportedLanguage => l10n.languageNotSupported(languageName),
    };
  }

  void _showLanguageNotSupported() {
    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.languageNotSupported(languageName))),
      );
    }
  }
}
