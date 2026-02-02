import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/deepl_service.dart';
import '../services/settings_service.dart';

mixin DeepLTranslationMixin<T extends StatefulWidget> on State<T> {
  bool _hasDeepLKey = false;
  bool _isTranslating = false;

  bool get hasDeepLKey => _hasDeepLKey;
  bool get isTranslating => _isTranslating;

  String get languageName;
  TextEditingController get sourceTextController;
  TextEditingController get translationTextController;

  Future<void> checkDeepLKey() async {
    final hasKey = await SettingsService.instance.hasDeepLApiKey();
    if (mounted) {
      setState(() => _hasDeepLKey = hasKey);
    }
  }

  Future<void> translateTerm() async {
    final sourceCode = DeepLService.getDeepLLanguageCode(languageName);
    if (sourceCode == null) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.languageNotSupported(languageName))),
        );
      }
      return;
    }

    setState(() => _isTranslating = true);

    final targetLang = await SettingsService.instance.getDeepLTargetLang();
    final translation = await DeepLService.instance.translate(
      text: sourceTextController.text.trim(),
      sourceLang: sourceCode,
      targetLang: targetLang,
    );

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
}
