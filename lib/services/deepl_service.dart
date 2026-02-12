import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/translation_result.dart';
import '../service_locator.dart';
import 'logger_service.dart';

class DeepLUsage {
  final int characterCount;
  final int characterLimit;

  DeepLUsage({required this.characterCount, required this.characterLimit});

  double get usagePercent => characterLimit > 0 ? characterCount / characterLimit : 0;
  int get charactersRemaining => characterLimit - characterCount;
}

class DeepLService {
  DeepLService();

  static const String _freeApiUrl = 'https://api-free.deepl.com/v2/translate';
  static const String _proApiUrl = 'https://api.deepl.com/v2/translate';
  static const String _freeUsageUrl = 'https://api-free.deepl.com/v2/usage';
  static const String _proUsageUrl = 'https://api.deepl.com/v2/usage';

  /// Translates text using DeepL API.
  Future<TranslationResult> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final apiKey = await settings.getDeepLApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return const TranslationResult.failure(TranslationError.authFailed);
    }

    final isFree = await settings.isDeepLApiFree();
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
          return TranslationResult.success(translations[0]['text'] as String);
        }
        return const TranslationResult.failure(TranslationError.serverError);
      }
      return TranslationResult.failure(_classifyHttpError(response.statusCode));
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('DeepL network error', error: e, stackTrace: stackTrace);
      return const TranslationResult.failure(TranslationError.networkError);
    } catch (e, stackTrace) {
      AppLogger.error('DeepL translation failed', error: e, stackTrace: stackTrace);
      return const TranslationResult.failure(TranslationError.networkError);
    }
  }

  static TranslationError _classifyHttpError(int statusCode) {
    if (statusCode == 401 || statusCode == 403) return TranslationError.authFailed;
    if (statusCode == 429 || statusCode == 456) return TranslationError.rateLimited;
    return TranslationError.serverError;
  }

  /// Gets usage statistics from DeepL API
  Future<DeepLUsage?> getUsage() async {
    final apiKey = await settings.getDeepLApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return null;
    }

    final isFree = await settings.isDeepLApiFree();
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
    } catch (e, stackTrace) {
      AppLogger.error('DeepL usage fetch failed', error: e, stackTrace: stackTrace);
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
