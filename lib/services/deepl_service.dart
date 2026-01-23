import 'dart:convert';
import 'package:http/http.dart' as http;
import 'settings_service.dart';

class DeepLUsage {
  final int characterCount;
  final int characterLimit;

  DeepLUsage({required this.characterCount, required this.characterLimit});

  double get usagePercent => characterLimit > 0 ? characterCount / characterLimit : 0;
  int get charactersRemaining => characterLimit - characterCount;
}

class DeepLService {
  static final DeepLService instance = DeepLService._init();
  DeepLService._init();

  static const String _freeApiUrl = 'https://api-free.deepl.com/v2/translate';
  static const String _proApiUrl = 'https://api.deepl.com/v2/translate';
  static const String _freeUsageUrl = 'https://api-free.deepl.com/v2/usage';
  static const String _proUsageUrl = 'https://api.deepl.com/v2/usage';

  /// Translates text using DeepL API
  /// Returns the translated text or null if translation fails
  Future<String?> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final apiKey = await SettingsService.instance.getDeepLApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final isFree = await SettingsService.instance.isDeepLApiFree();
    final apiUrl = isFree ? _freeApiUrl : _proApiUrl;

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'DeepL-Auth-Key $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': [text],
          'source_lang': sourceLang.toUpperCase(),
          'target_lang': targetLang.toUpperCase(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final translations = data['translations'] as List;
        if (translations.isNotEmpty) {
          return translations[0]['text'] as String;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Gets usage statistics from DeepL API
  Future<DeepLUsage?> getUsage() async {
    final apiKey = await SettingsService.instance.getDeepLApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final isFree = await SettingsService.instance.isDeepLApiFree();
    final usageUrl = isFree ? _freeUsageUrl : _proUsageUrl;

    try {
      final response = await http.get(
        Uri.parse(usageUrl),
        headers: {
          'Authorization': 'DeepL-Auth-Key $apiKey',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return DeepLUsage(
          characterCount: data['character_count'] as int,
          characterLimit: data['character_limit'] as int,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Maps common language names to DeepL language codes
  static String? getDeepLLanguageCode(String languageName) {
    final normalized = languageName.toLowerCase().trim();
    const languageMap = {
      'english': 'EN',
      'german': 'DE',
      'french': 'FR',
      'spanish': 'ES',
      'italian': 'IT',
      'dutch': 'NL',
      'polish': 'PL',
      'portuguese': 'PT',
      'russian': 'RU',
      'japanese': 'JA',
      'chinese': 'ZH',
      'korean': 'KO',
      'bulgarian': 'BG',
      'czech': 'CS',
      'danish': 'DA',
      'greek': 'EL',
      'estonian': 'ET',
      'finnish': 'FI',
      'hungarian': 'HU',
      'indonesian': 'ID',
      'latvian': 'LV',
      'lithuanian': 'LT',
      'norwegian': 'NB',
      'romanian': 'RO',
      'slovak': 'SK',
      'slovenian': 'SL',
      'swedish': 'SV',
      'turkish': 'TR',
      'ukrainian': 'UK',
    };
    return languageMap[normalized];
  }
}
