import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// import '../models/language.dart';
import '../models/dictionary.dart';
import '../service_locator.dart';
import '../screens/dictionary_webview_screen.dart';

class DictionaryService {
  // Open dictionary with word lookup - platform aware
  Future<void> lookupWord(
    BuildContext context,
    String word,
    String dictUrl,
  ) async {
    if (dictUrl.isEmpty) {
      throw Exception('Dictionary URL not configured');
    }

    final encodedWord = Uri.encodeComponent(word.trim());
    final url = dictUrl.replaceAll('###', encodedWord);

    // Use in-app webview only for mobile platforms
    final useMobileWebView = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    if (useMobileWebView) {
      // Mobile: Use in-app webview
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DictionaryWebViewScreen(url: url, word: word),
        ),
      );
    } else {
      // Desktop/Web: Use external browser
      await lookupWordExternal(word, dictUrl);
    }
  }

  // Open in external browser
  Future<void> lookupWordExternal(String word, String dictUrl) async {
    if (dictUrl.isEmpty) {
      throw Exception('Dictionary URL not configured');
    }

    final encodedWord = Uri.encodeComponent(word.trim());
    final url = dictUrl.replaceAll('###', encodedWord);

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw Exception('Could not launch dictionary URL');
    }
  }

  // Get active dictionaries for a language
  Future<List<Dictionary>> getActiveDictionaries(int languageId) async {
    return await db.dictionaries.getAll(
      languageId: languageId,
      activeOnly: true,
    );
  }

  // Get all dictionaries for a language
  Future<List<Dictionary>> getAllDictionaries(int languageId) async {
    return await db.dictionaries.getAll(
      languageId: languageId,
    );
  }

  // Check if any dictionaries are configured
  Future<bool> hasDictionaries(int languageId) async {
    final dicts = await getActiveDictionaries(languageId);
    return dicts.isNotEmpty;
  }
}
