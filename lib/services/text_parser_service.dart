import '../models/language.dart';
import 'chinese_segmentation_service.dart';

/// Represents a word match with its position in the text
class WordMatch {
  final String word;
  final int start;
  final int end;

  WordMatch(this.word, this.start, this.end);
}

class TextParserService {
  static const _defaultPattern =
      r"[\p{L}\p{M}]+(?:['\u2019\u02bc\u2018'][\p{L}\p{M}]+)*";
  static const _basicPattern = r'[\p{L}\p{M}]+';
  static final _punctuationPattern = RegExp(r'[\p{P}\p{S}]', unicode: true);
  static const _protectionMarker = '\u2E1C';

  /// Optional jieba-based segmenter; required when a language has
  /// [Language.useWordSegmentation] enabled (i.e. Mandarin Chinese).
  final ChineseSegmentationService? _chineseSeg;

  TextParserService({ChineseSegmentationService? chineseSeg})
    : _chineseSeg = chineseSeg;

  // ─── Public API ────────────────────────────────────────────────────────────

  List<WordMatch> getWordMatches(String text, Language language) {
    if (text.isEmpty) return [];

    if (language.splitByCharacter && language.useWordSegmentation) {
      return _getJiebaWordMatches(text);
    }

    if (language.splitByCharacter) {
      return _getCharacterMatches(text);
    }

    final processedText = _applySubstitutionsIfNeeded(text, language);
    final regex = RegExp(_wordPattern(language), unicode: true);
    final matches = regex.allMatches(processedText);

    return matches.map((m) => WordMatch(m.group(0)!, m.start, m.end)).toList();
  }

  List<String> splitIntoWords(String text, Language language) {
    if (text.isEmpty) return [];

    if (language.splitByCharacter && language.useWordSegmentation) {
      return _chineseSeg!.segmentToStrings(text);
    }

    if (language.splitByCharacter) {
      return _splitByCharacter(text);
    }

    final processedText = _applySubstitutionsIfNeeded(text, language);
    final regex = RegExp(_wordPattern(language), unicode: true);
    final matches = regex.allMatches(processedText);

    return matches.map((m) => m.group(0)!).toList();
  }

  List<String> splitIntoSentences(String text, Language language) {
    if (text.isEmpty) return [];

    final pattern = language.regexpSplitSentences.isNotEmpty
        ? language.regexpSplitSentences
        : r'[.!?]+';

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

  String getSentenceAtPosition(String text, int position, Language language) {
    if (text.isEmpty) return '';

    final pattern = language.regexpSplitSentences.isNotEmpty
        ? language.regexpSplitSentences
        : r'[.!?]+';

    String processedText = text;
    if (language.exceptionsSplitSentences.isNotEmpty) {
      processedText = _protectExceptions(
        text,
        language.exceptionsSplitSentences,
      );
    }

    final splitRegex = RegExp(pattern);
    int start = 0;

    for (final match in splitRegex.allMatches(processedText)) {
      if (position >= start && position < match.start) {
        return processedText
            .substring(start, match.start)
            .replaceAll(_protectionMarker, '.')
            .trim();
      }
      start = match.end;
    }

    if (position >= start && start < processedText.length) {
      return processedText
          .substring(start)
          .replaceAll(_protectionMarker, '.')
          .trim();
    }

    return '';
  }

  String normalizeWord(String word) => word.toLowerCase().trim();

  // ─── Private helpers ───────────────────────────────────────────────────────

  List<WordMatch> _getJiebaWordMatches(String text) {
    assert(
      _chineseSeg != null,
      'ChineseSegmentationService must be injected into TextParserService '
      'to enable jieba word segmentation.',
    );
    return _chineseSeg!
        .segmentWords(text)
        .map((sw) => WordMatch(sw.word, sw.start, sw.end))
        .toList();
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

  List<String> _splitByCharacter(String text) {
    final characters = <String>[];
    for (final rune in text.runes) {
      final char = String.fromCharCode(rune);
      if (char.trim().isEmpty || _punctuationPattern.hasMatch(char)) continue;
      characters.add(char);
    }
    return characters;
  }

  String _wordPattern(Language language) {
    return (language.regexpWordCharacters.isEmpty ||
            language.regexpWordCharacters == _basicPattern)
        ? _defaultPattern
        : language.regexpWordCharacters;
  }

  String _applySubstitutionsIfNeeded(String text, Language language) {
    if (language.characterSubstitutions.isEmpty) return text;
    return _applySubstitutions(text, language.characterSubstitutions);
  }

  String _applySubstitutions(String text, String substitutions) {
    final pairs = substitutions.split('|');
    String result = text;
    for (final pair in pairs) {
      final parts = pair.split('\u2192'); // →
      if (parts.length == 2) {
        result = result.replaceAll(parts[0], parts[1]);
      }
    }
    return result;
  }

  String _protectExceptions(String text, String exceptions) {
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
