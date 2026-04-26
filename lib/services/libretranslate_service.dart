import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../domain/entities/translation_result.dart';
import '../service_locator.dart';
import 'logger_service.dart';

class LibreTranslateService {
  LibreTranslateService();

  /// Translates text using LibreTranslate API.
  Future<TranslationResult> translate({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final serverUrl = await settings.getLibreTranslateUrl();
    if (serverUrl == null || serverUrl.isEmpty) {
      return const TranslationResult.failure(TranslationError.authFailed);
    }

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
        final translated = data['translatedText'] as String?;
        if (translated != null) {
          return TranslationResult.success(translated);
        }
        return const TranslationResult.failure(TranslationError.serverError);
      }
      return TranslationResult.failure(_classifyHttpError(response.statusCode));
    } on SocketException catch (e, stackTrace) {
      AppLogger.error('LibreTranslate network error', error: e, stackTrace: stackTrace);
      return const TranslationResult.failure(TranslationError.networkError);
    } catch (e, stackTrace) {
      AppLogger.error('LibreTranslate failed', error: e, stackTrace: stackTrace);
      return const TranslationResult.failure(TranslationError.networkError);
    }
  }

  static TranslationError _classifyHttpError(int statusCode) {
    if (statusCode == 401 || statusCode == 403) return TranslationError.authFailed;
    if (statusCode == 429) return TranslationError.rateLimited;
    return TranslationError.serverError;
  }

  /// Returns the LibreTranslate ISO 639-1 code for [isoCode]
  /// (case-insensitive), or null if the language is not supported.
  static String? libreCode(String isoCode) {
    const supported = {
      'ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi',
      'fr', 'ga', 'he', 'hi', 'hu', 'id', 'it', 'ja', 'ko', 'lt',
      'lv', 'nb', 'nl', 'pl', 'pt', 'ro', 'ru', 'sk', 'sl', 'sv',
      'th', 'tr', 'uk', 'vi', 'zh',
    };
    final lower = isoCode.toLowerCase().trim();
    return supported.contains(lower) ? lower : null;
  }
}
