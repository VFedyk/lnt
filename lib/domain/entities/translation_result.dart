/// Error categories for translation service failures.
enum TranslationError {
  /// Invalid API key or unauthorized (HTTP 401/403).
  authFailed,

  /// Rate limited (HTTP 429) or quota exceeded.
  rateLimited,

  /// Network connectivity issue (timeout, DNS, etc.).
  networkError,

  /// Server error (HTTP 5xx) or unexpected response.
  serverError,
}

/// Result of a translation API call — either translated text or a typed error.
class TranslationResult {
  final String? text;
  final TranslationError? error;

  const TranslationResult.success(String this.text) : error = null;
  const TranslationResult.failure(TranslationError this.error) : text = null;

  bool get isSuccess => text != null;
}
