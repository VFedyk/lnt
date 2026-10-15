import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/services/system_dictionary_service.dart';
import '../domain/entities/dictionary.dart';
import '../l10n/generated/app_localizations.dart';
import '../presentation/screens/dictionary_webview_screen.dart';
import '../services/dictionary_service.dart';
import 'snackbar_helpers.dart';

/// The name to show for [d]; the virtual System Dictionary is localized.
String dictionaryDisplayName(AppLocalizations l10n, Dictionary d) =>
    d.isSystem ? l10n.systemDictionary : d.name;

Future<void> openDictionaryLookup(
  BuildContext context,
  String word,
  Dictionary dictionary,
) async {
  if (dictionary.isSystem) {
    try {
      await SystemDictionaryService().lookUp(word);
    } on PlatformException {
      if (context.mounted) _showSystemLookupFailed(context);
    } on MissingPluginException {
      if (context.mounted) _showSystemLookupFailed(context);
    }
    return;
  }
  if (!kIsWeb) {
    final url = DictionaryService.buildLookupUrl(word, dictionary.url);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DictionaryWebViewScreen(
          url: url,
          word: word,
          customCss: dictionary.customCss,
        ),
      ),
    );
  } else {
    await DictionaryService().lookupWordExternal(word, dictionary.url);
  }
}

void _showSystemLookupFailed(BuildContext context) {
  SnackbarHelpers.showError(
    context,
    AppLocalizations.of(context).systemDictionaryFailed,
  );
}
