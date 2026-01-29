import '../models/language.dart';

/// Represents a word match with its position in the text
class WordMatch {
  final String word;
  final int start;
  final int end;

  WordMatch(this.word, this.start, this.end);
}

class TextParserService {
  static const _defaultPattern = r"[\p{L}\p{M}]+(?:[''ʼ'][\p{L}\p{M}]+)*";
  static const _basicPattern = r'[\p{L}\p{M}]+';
  static final _punctuationPattern = RegExp(r'[\p{P}\p{S}]', unicode: true);
  static const _protectionMarker = '⁜';

  /// Get word matches with their positions - O(n) instead of O(n²)
  List<WordMatch> getWordMatches(String text, Language language) {
    if (text.isEmpty) return [];

    if (language.splitByCharacter) {
      return _getCharacterMatches(text);
    }

    final processedText = _applySubstitutionsIfNeeded(text, language);
    final regex = RegExp(_wordPattern(language), unicode: true);
    final matches = regex.allMatches(processedText);

    return matches.map((m) => WordMatch(m.group(0)!, m.start, m.end)).toList();
  }

  List<WordMatch> _getCharacterMatches(String text) {
    final matches = <WordMatch>[];

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char.trim().isNotEmpty && !_punctuationPattern.hasMatch(char)) {
        matches.add(WordMatch(char, i, i + 1));
      }
    }

    return matches;
  }

  // Split text into words based on language rules
  List<String> splitIntoWords(String text, Language language) {
    if (text.isEmpty) return [];

    if (language.splitByCharacter) {
      return _splitByCharacter(text);
    }

    final processedText = _applySubstitutionsIfNeeded(text, language);
    final regex = RegExp(_wordPattern(language), unicode: true);
    final matches = regex.allMatches(processedText);

    return matches.map((m) => m.group(0)!).toList();
  }

  // Split text by individual characters (for Chinese, Japanese, etc.)
  List<String> _splitByCharacter(String text) {
    final characters = <String>[];

    // Use runes iterator to correctly handle characters outside the BMP
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);

      // Skip whitespace and punctuation for character-based languages
      if (char.trim().isEmpty || _punctuationPattern.hasMatch(char)) {
        continue;
      }

      characters.add(char);
    }

    return characters;
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
        .map((s) => s.replaceAll(_protectionMarker, '.').trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return sentences;
  }

  // Get sentence containing word at position
  String getSentenceAtPosition(String text, int position, Language language) {
    if (text.isEmpty) return '';

    final pattern = language.regexpSplitSentences.isNotEmpty
        ? language.regexpSplitSentences
        : r'[.!?]+';

    // Protect exceptions before splitting
    String processedText = text;
    if (language.exceptionsSplitSentences.isNotEmpty) {
      processedText = _protectExceptions(
        text,
        language.exceptionsSplitSentences,
      );
    }

    // Split using the regex but track positions in the original text
    final splitRegex = RegExp(pattern);
    int start = 0;

    for (final match in splitRegex.allMatches(processedText)) {
      // The sentence runs from start to this delimiter
      if (position >= start && position < match.start) {
        return processedText
            .substring(start, match.start)
            .replaceAll(_protectionMarker, '.')
            .trim();
      }
      start = match.end;
    }

    // Check the last segment after the final delimiter
    if (position >= start && start < processedText.length) {
      return processedText
          .substring(start)
          .replaceAll(_protectionMarker, '.')
          .trim();
    }

    return '';
  }

  // Normalize word for comparison
  String normalizeWord(String word) {
    return word.toLowerCase().trim();
  }

  // --- Private helpers ---

  /// Returns the word-matching pattern for a language.
  String _wordPattern(Language language) {
    return (language.regexpWordCharacters.isEmpty ||
            language.regexpWordCharacters == _basicPattern)
        ? _defaultPattern
        : language.regexpWordCharacters;
  }

  /// Applies character substitutions if the language has them configured.
  String _applySubstitutionsIfNeeded(String text, Language language) {
    if (language.characterSubstitutions.isEmpty) return text;
    return _applySubstitutions(text, language.characterSubstitutions);
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
      result = result.replaceAll(
        exception,
        exception.replaceAll('.', _protectionMarker),
      );
    }

    return result;
  }
}
