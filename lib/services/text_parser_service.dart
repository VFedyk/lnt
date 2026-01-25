import '../models/language.dart';

class TextParserService {
  // Split text into words based on language rules
  List<String> splitIntoWords(String text, Language language) {
    if (text.isEmpty) return [];

    // For character-based languages (Chinese, Japanese), split by character
    if (language.splitByCharacter) {
      return _splitByCharacter(text);
    }

    // Apply character substitutions if configured
    String processedText = text;
    if (language.characterSubstitutions.isNotEmpty) {
      processedText = _applySubstitutions(
        text,
        language.characterSubstitutions,
      );
    }

    // Use language-specific word character pattern
    // Default pattern includes apostrophes for contractions (we're, don't) and possessives (winter's)
    final defaultPattern = r"[\p{L}\p{M}]+(?:[''’'][\p{L}\p{M}]+)*";
    final basicPattern = r'[\p{L}\p{M}]+';

    // Use enhanced pattern if language has no custom pattern or uses the basic pattern
    final pattern =
        (language.regexpWordCharacters.isEmpty ||
            language.regexpWordCharacters == basicPattern)
        ? defaultPattern
        : language.regexpWordCharacters;

    final regex = RegExp(pattern, unicode: true);
    final matches = regex.allMatches(processedText);

    return matches.map((m) => m.group(0)!).toList();
  }

  // Split text by individual characters (for Chinese, Japanese, etc.)
  List<String> _splitByCharacter(String text) {
    final characters = <String>[];
    final runes = text.runes.toList();

    for (int i = 0; i < runes.length; i++) {
      final char = String.fromCharCode(runes[i]);

      // Skip whitespace and punctuation for character-based languages
      if (char.trim().isEmpty || _isPunctuation(char)) {
        continue;
      }

      characters.add(char);
    }

    return characters;
  }

  // Check if character is punctuation
  bool _isPunctuation(String char) {
    final punctuationPattern = RegExp(r'[\p{P}\p{S}]', unicode: true);
    return punctuationPattern.hasMatch(char);
  }

  // Split text into sentences
  List<String> splitIntoSentences(String text, Language language) {
    if (text.isEmpty) return [];

    final pattern = language.regexpSplitSentences.isNotEmpty
        ? language.regexpSplitSentences
        : r'[.!?]+';

    // Handle exceptions
    String processedText = text;
    if (language.exceptionsSplitSentences.isNotEmpty) {
      processedText = _protectExceptions(
        text,
        language.exceptionsSplitSentences,
      );
    }

    final sentences = processedText
        .split(RegExp(pattern))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return sentences;
  }

  // Apply character substitutions
  String _applySubstitutions(String text, String substitutions) {
    // Format: "from1→to1|from2→to2"
    final pairs = substitutions.split('|');
    String result = text;

    for (final pair in pairs) {
      final parts = pair.split('→');
      if (parts.length == 2) {
        result = result.replaceAll(parts[0], parts[1]);
      }
    }

    return result;
  }

  // Protect exceptions from sentence splitting
  String _protectExceptions(String text, String exceptions) {
    // Format: "Mr.|Dr.|etc."
    final exceptionList = exceptions.split('|');
    String result = text;

    for (final exception in exceptionList) {
      // Replace exception with protected version (using special marker)
      result = result.replaceAll(exception, exception.replaceAll('.', '⁜'));
    }

    return result;
  }

  // Get sentence containing word at position
  String getSentenceAtPosition(String text, int position, Language language) {
    final sentences = splitIntoSentences(text, language);
    int currentPos = 0;

    for (final sentence in sentences) {
      final sentenceEnd = currentPos + sentence.length;
      if (position >= currentPos && position <= sentenceEnd) {
        return sentence;
      }
      currentPos = sentenceEnd + 1;
    }

    return '';
  }

  // Normalize word for comparison
  String normalizeWord(String word) {
    return word.toLowerCase().trim();
  }
}
