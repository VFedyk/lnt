import 'dart:convert';
import 'package:http/http.dart' as http;
import '../service_locator.dart';

class LibreTranslateService {
  LibreTranslateService();

  /// Translates text using LibreTranslate API
  /// Returns the translated text or null if translation fails
  Future<String?> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final serverUrl = await settings.getLibreTranslateUrl();
    if (serverUrl == null || serverUrl.isEmpty) return null;

    final apiKey = await settings.getLibreTranslateApiKey();

    try {
      final body = <String, dynamic>{
        'q': text,
        'source': sourceLang.toLowerCase(),
        'target': targetLang.toLowerCase(),
      };
      if (apiKey != null && apiKey.isNotEmpty) {
        body['api_key'] = apiKey;
      }

      final normalizedUrl = serverUrl.endsWith('/')
          ? serverUrl.substring(0, serverUrl.length - 1)
          : serverUrl;

      final response = await http.post(
        Uri.parse('$normalizedUrl/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['translatedText'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Maps common language names to LibreTranslate ISO 639-1 codes (lowercase)
  static String? getLanguageCode(String languageName) {
    final normalized = languageName.toLowerCase().trim();
    const languageMap = {
      'english': 'en',
      'german': 'de',
      'french': 'fr',
      'spanish': 'es',
      'italian': 'it',
      'dutch': 'nl',
      'polish': 'pl',
      'portuguese': 'pt',
      'russian': 'ru',
      'japanese': 'ja',
      'chinese': 'zh',
      'korean': 'ko',
      'bulgarian': 'bg',
      'czech': 'cs',
      'danish': 'da',
      'greek': 'el',
      'estonian': 'et',
      'finnish': 'fi',
      'hungarian': 'hu',
      'indonesian': 'id',
      'latvian': 'lv',
      'lithuanian': 'lt',
      'norwegian': 'nb',
      'romanian': 'ro',
      'slovak': 'sk',
      'slovenian': 'sl',
      'swedish': 'sv',
      'turkish': 'tr',
      'ukrainian': 'uk',
      'arabic': 'ar',
      'hindi': 'hi',
      'hebrew': 'he',
      'thai': 'th',
      'vietnamese': 'vi',
      'irish': 'ga',
    };
    return languageMap[normalized];
  }
}
