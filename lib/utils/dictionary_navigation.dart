import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../domain/entities/dictionary.dart';
import '../screens/dictionary_webview_screen.dart';
import '../services/dictionary_service.dart';

Future<void> openDictionaryLookup(
  BuildContext context,
  String word,
  Dictionary dictionary,
) async {
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
