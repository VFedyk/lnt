import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'logger_service.dart';
import 'settings_service.dart';

enum AiExplanationType { meaning, grammar }

enum _AiApiProvider { openAI, anthropic, ollama }

class AiExplanationService {
  final SettingsService _settings;

  AiExplanationService({SettingsService? settings})
    : _settings = settings ?? SettingsService();

  Future<bool> isConfigured() async {
    final apiKey = await _settings.getAiApiKey();
    final model = (await _settings.getAiModel()).trim();
    final apiUrl = (await _settings.getAiApiUrl()).trim();
    final provider = await _resolveProvider(apiUrl: apiUrl, model: model);

    if (provider == _AiApiProvider.ollama) {
      return model.isNotEmpty && apiUrl.isNotEmpty;
    }
    return apiKey != null && apiKey.trim().isNotEmpty;
  }

  Future<String> explainInContext({
    required AiExplanationType type,
    required String selectedText,
    required String contextSentence,
    required String languageName,
    required String responseLanguageCode,
  }) async {
    final apiKey = (await _settings.getAiApiKey())?.trim() ?? '';
    final model = (await _settings.getAiModel()).trim();
    final apiUrl = (await _settings.getAiApiUrl()).trim();
    final provider = await _resolveProvider(apiUrl: apiUrl, model: model);

    if (provider != _AiApiProvider.ollama && apiKey.isEmpty) {
      throw Exception('AI not configured');
    }
    if (model.isEmpty || apiUrl.isEmpty) {
      throw Exception('AI not configured');
    }

    final responseLanguage = responseLanguageCode == 'uk'
        ? 'Ukrainian'
        : 'English';
    final task = switch (type) {
      AiExplanationType.meaning =>
        'Explain the meaning of the selected text in the given sentence context.',
      AiExplanationType.grammar =>
        'Explain the grammar used by the selected text in the given sentence context.'
    };

    final userPrompt = '''
$task

Language: $languageName
Selected text: "$selectedText"
Sentence context: "$contextSentence"

Return:
1) Direct explanation
2) Nuance in this context
3) One short alternative wording or pattern
''';
    final systemPrompt =
        'You are a language tutor. Be accurate and concise. '
        'Answer in $responseLanguage. '
        'Use short sections and bullet points where helpful.';
    final resolvedApiUrl = _resolveApiUrl(provider: provider, apiUrl: apiUrl);
    final body = _buildRequestBody(
      provider: provider,
      model: model,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      apiUrl: resolvedApiUrl,
    );
    final headers = _buildHeaders(
      provider: provider,
      apiKey: apiKey,
      hasApiKey: apiKey.isNotEmpty,
    );

    try {
      final response = await http
          .post(
            Uri.parse(resolvedApiUrl),
            headers: headers,
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          'AI request failed (${response.statusCode}): ${response.body}',
        );
      }

      final content = _parseResponseContent(
        provider: provider,
        responseBody: response.body,
      );
      if (content == null || content.trim().isEmpty) {
        throw Exception('Empty AI response');
      }

      return content.trim();
    } on TimeoutException {
      throw Exception('AI request timed out');
    } catch (e, stackTrace) {
      AppLogger.error('AI explanation failed', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<_AiApiProvider> _resolveProvider({
    required String apiUrl,
    required String model,
  }) async {
    final configured = await _settings.getAiProvider();
    switch (configured) {
      case SettingsService.aiProviderOpenAiCompatible:
        return _AiApiProvider.openAI;
      case SettingsService.aiProviderAnthropic:
        return _AiApiProvider.anthropic;
      case SettingsService.aiProviderOllama:
        return _AiApiProvider.ollama;
      case SettingsService.aiProviderAuto:
      default:
        return _detectProvider(apiUrl: apiUrl, model: model);
    }
  }

  _AiApiProvider _detectProvider({
    required String apiUrl,
    required String model,
  }) {
    final lowerUrl = apiUrl.toLowerCase();
    final lowerModel = model.toLowerCase();
    if (lowerUrl.contains('/api/chat') ||
        lowerUrl.contains('/api/generate') ||
        lowerUrl.contains('localhost:11434') ||
        lowerUrl.contains('127.0.0.1:11434')) {
      return _AiApiProvider.ollama;
    }
    if (lowerUrl.contains('anthropic.com') || lowerModel.startsWith('claude')) {
      return _AiApiProvider.anthropic;
    }
    return _AiApiProvider.openAI;
  }

  String _resolveApiUrl({
    required _AiApiProvider provider,
    required String apiUrl,
  }) {
    if (provider != _AiApiProvider.ollama) return apiUrl;
    final lowerUrl = apiUrl.toLowerCase();
    if (lowerUrl.endsWith('/api/chat') || lowerUrl.endsWith('/api/generate')) {
      return apiUrl;
    }
    final normalized = apiUrl.endsWith('/')
        ? apiUrl.substring(0, apiUrl.length - 1)
        : apiUrl;
    return '$normalized/api/chat';
  }

  String _buildRequestBody({
    required _AiApiProvider provider,
    required String model,
    required String systemPrompt,
    required String userPrompt,
    required String apiUrl,
  }) {
    switch (provider) {
      case _AiApiProvider.openAI:
        return jsonEncode({
          'model': model,
          'temperature': 0.3,
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': userPrompt,
            },
          ],
        });
      case _AiApiProvider.anthropic:
        return jsonEncode({
          'model': model,
          'max_tokens': 600,
          'temperature': 0.3,
          'system': systemPrompt,
          'messages': [
            {
              'role': 'user',
              'content': userPrompt,
            },
          ],
        });
      case _AiApiProvider.ollama:
        if (_isOllamaGenerateEndpoint(apiUrl)) {
          return jsonEncode({
            'model': model,
            'stream': false,
            'prompt': '$systemPrompt\n\n$userPrompt',
          });
        }
        return jsonEncode({
          'model': model,
          'stream': false,
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt,
            },
            {
              'role': 'user',
              'content': userPrompt,
            },
          ],
        });
    }
  }

  bool _isOllamaGenerateEndpoint(String apiUrl) {
    final lower = apiUrl.toLowerCase();
    return lower.endsWith('/api/generate');
  }

  Map<String, String> _buildHeaders({
    required _AiApiProvider provider,
    required String apiKey,
    required bool hasApiKey,
  }) {
    switch (provider) {
      case _AiApiProvider.openAI:
        return {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        };
      case _AiApiProvider.anthropic:
        return {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
        };
      case _AiApiProvider.ollama:
        return {
          if (hasApiKey) 'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        };
    }
  }

  String? _parseResponseContent({
    required _AiApiProvider provider,
    required String responseBody,
  }) {
    final data = jsonDecode(responseBody) as Map<String, dynamic>;
    switch (provider) {
      case _AiApiProvider.openAI:
        final choices = data['choices'] as List<dynamic>? ?? [];
        if (choices.isEmpty) return null;
        final first = choices.first as Map<String, dynamic>;
        final message = first['message'] as Map<String, dynamic>?;
        return message?['content'] as String?;
      case _AiApiProvider.anthropic:
        final content = data['content'] as List<dynamic>? ?? [];
        if (content.isEmpty) return null;
        final textParts = content
            .whereType<Map<String, dynamic>>()
            .where((part) => part['type'] == 'text')
            .map((part) => part['text'] as String?)
            .whereType<String>()
            .toList();
        if (textParts.isEmpty) return null;
        return textParts.join('\n');
      case _AiApiProvider.ollama:
        final message = data['message'] as Map<String, dynamic>?;
        final content = message?['content'] as String?;
        if (content != null && content.trim().isNotEmpty) return content;
        return data['response'] as String?;
    }
  }
}
