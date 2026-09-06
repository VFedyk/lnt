import 'dart:developer' as developer;

import '../domain/entities/language.dart';
import '../domain/value_objects/text_parsing_defaults.dart';
import '../data/services/chinese_segmentation_service.dart';

/// Represents a word match with its position in the text
class WordMatch {
  final String word;
  final int start;
  final int end;

  WordMatch(this.word, this.start, this.end);
}

class TextParserService {
  static final _punctuationPattern = RegExp(r'[\p{P}\p{S}]', unicode: true);
  static const _protectionMarker = '⸜';

  /// Trailing characters absorbed onto the sentence a delimiter terminates, so
  /// `said.’` ends *after* the closing quote rather than orphaning it onto the
  /// next sentence.
  static const _closingChars = '’”\'"»›」』〉】）)]}';

  static final _digit = RegExp(r'[0-9]');
  static final _letter = RegExp(r'[\p{L}\p{M}]', unicode: true);
  static final _lowerLetter = RegExp(r'\p{Ll}', unicode: true);
  static final _paragraphBreak = RegExp(r'\n[ \t]*\n');
  static final _whitespaceRun = RegExp(r'\s+');

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

  /// Half-open [start, end) offsets into the *original* [text], one per
  /// sentence. Ranges are contiguous in reading order and never overlap;
  /// inter-sentence whitespace belongs to no range. Delimiters and their
  /// trailing closing quotes are kept inside the sentence they end; a blank
  /// line is an unconditional boundary.
  List<({int start, int end})> sentenceRanges(String text, Language language) {
    if (text.isEmpty) return const [];

    final work = _protectExceptions(text, language);
    assert(work.length == text.length,
        'exception protection must be length-preserving');

    // boundary offset (exclusive end) -> offset to resume the next sentence at.
    final resumeOf = <int, int>{};
    void addBoundary(int at, int resume) {
      if (at <= 0 || at > text.length) return;
      final existing = resumeOf[at];
      resumeOf[at] =
          existing == null ? resume : (resume > existing ? resume : existing);
    }

    final sentenceRe = RegExp(_sentencePattern(language), unicode: true);
    for (final m in sentenceRe.allMatches(work)) {
      if (_isNonBoundaryDot(work, m)) continue;
      var end = m.end;
      while (end < work.length && _closingChars.contains(work[end])) {
        end++;
      }
      // A delimiter followed directly by a lowercase word is mid-sentence
      // (ellipsis, `"stop!" she said`, decimals already handled above).
      var probe = end;
      while (probe < work.length && _isWs(work.codeUnitAt(probe))) {
        probe++;
      }
      if (probe < work.length && _lowerLetter.hasMatch(work[probe])) continue;
      addBoundary(end, end);
    }

    for (final m in _paragraphBreak.allMatches(work)) {
      addBoundary(m.start, m.end);
    }

    final boundaries = resumeOf.keys.toList()..sort();
    boundaries.add(text.length);
    resumeOf.putIfAbsent(text.length, () => text.length);

    final ranges = <({int start, int end})>[];
    var cursor = 0;
    for (final b in boundaries) {
      if (b <= cursor) continue;
      var start = cursor;
      while (start < b && _isWs(text.codeUnitAt(start))) {
        start++;
      }
      var end = b;
      while (end > start && _isWs(text.codeUnitAt(end - 1))) {
        end--;
      }
      if (end > start) ranges.add((start: start, end: end));
      cursor = resumeOf[b] ?? b;
    }
    return ranges;
  }

  List<String> splitIntoSentences(String text, Language language) =>
      sentenceRanges(text, language)
          .map((r) => text.substring(r.start, r.end))
          .where((s) => s.isNotEmpty)
          .toList();

  String getSentenceAtPosition(String text, int position, Language language) {
    for (final r in sentenceRanges(text, language)) {
      if (position < r.end) return text.substring(r.start, r.end);
    }
    return '';
  }

  String normalizeWord(String word) => word.toLowerCase().trim();

  /// Range of the first *word-boundary-aligned* occurrence of [termLowerText]
  /// in [sentence], or null when the term does not literally occur in it.
  ///
  /// Substring matching is wrong here: term "on" must not match inside
  /// "London". Multi-word terms match across consecutive tokens regardless of
  /// the whitespace between them. Static and DI-free so widgets can call it.
  static ({int start, int end})? findOccurrence(
    String sentence,
    String termLowerText, {
    Language? language,
  }) {
    if (termLowerText.isEmpty) return null;

    if (language?.splitByCharacter == true) {
      final idx = sentence.toLowerCase().indexOf(termLowerText);
      if (idx < 0) return null;
      return (start: idx, end: idx + termLowerText.length);
    }

    final regex = RegExp(_staticWordPattern(language), unicode: true);
    final matches = regex.allMatches(sentence).toList();
    if (matches.isEmpty) return null;

    final parts = termLowerText
        .split(_whitespaceRun)
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;

    if (parts.length == 1) {
      for (final m in matches) {
        if (m.group(0)!.toLowerCase() == parts[0]) {
          return (start: m.start, end: m.end);
        }
      }
      return null;
    }

    for (var i = 0; i + parts.length <= matches.length; i++) {
      var ok = true;
      for (var j = 0; j < parts.length; j++) {
        if (matches[i + j].group(0)!.toLowerCase() != parts[j]) {
          ok = false;
          break;
        }
      }
      if (ok) {
        return (
          start: matches[i].start,
          end: matches[i + parts.length - 1].end,
        );
      }
    }
    return null;
  }

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

  String _wordPattern(Language language) => _staticWordPattern(language);

  static String _staticWordPattern(Language? language) {
    if (language == null) return TextParsingDefaults.wordPattern;
    return TextParsingDefaults.legacyWordPatterns
            .contains(language.regexpWordCharacters)
        ? TextParsingDefaults.wordPattern
        : language.regexpWordCharacters;
  }

  String _sentencePattern(Language language) =>
      TextParsingDefaults.legacySentencePatterns
              .contains(language.regexpSplitSentences)
          ? TextParsingDefaults.sentencePattern
          : language.regexpSplitSentences;

  String _applySubstitutionsIfNeeded(String text, Language language) {
    if (language.characterSubstitutions.isEmpty) return text;
    return _applySubstitutions(text, language.characterSubstitutions);
  }

  /// Substitutions must be length-preserving: word offsets from the processed
  /// text are used verbatim against the *raw* content by the reader, the word
  /// index and getSentenceAtPosition. A pair like `ß→ss` shifts every later
  /// offset and corrupts all three, so it is dropped rather than applied.
  String _applySubstitutions(String text, String substitutions) {
    String result = text;
    for (final pair in substitutions.split('|')) {
      final parts = pair.split('→'); // →
      if (parts.length != 2) continue;
      if (parts[0].length != parts[1].length) {
        developer.log('TextParserService: ignoring non-length-preserving '
            'substitution "${parts[0]}→${parts[1]}"');
        continue;
      }
      result = result.replaceAll(parts[0], parts[1]);
    }
    return result;
  }

  /// Compiled abbreviation regex, cached by its source list so a per-tap
  /// `getSentenceAtPosition` over a whole chapter does not rebuild it.
  static final Map<String, RegExp?> _exceptionRegexCache = {};

  static RegExp? _exceptionRegex(Language language) {
    final source = language.exceptionsSplitSentences.isNotEmpty
        ? language.exceptionsSplitSentences
        : TextParsingDefaults.abbreviations;
    return _exceptionRegexCache.putIfAbsent(source, () {
      final alternatives = source
          .split('|')
          .where((e) => e.isNotEmpty)
          .map(RegExp.escape)
          .join('|');
      if (alternatives.isEmpty) return null;
      const prefix = r'(?<![\p{L}\p{M}])(?:';
      return RegExp('$prefix$alternatives)',
          unicode: true, caseSensitive: false);
    });
  }

  /// Replaces the `.` inside each abbreviation with [_protectionMarker] (a
  /// single UTF-16 unit, so offsets stay aligned). Source list: the language's
  /// own exceptions when set, else [TextParsingDefaults.abbreviations].
  String _protectExceptions(String text, Language language) {
    final re = _exceptionRegex(language);
    if (re == null) return text;
    return text.replaceAllMapped(
      re,
      (m) => m.group(0)!.replaceAll('.', _protectionMarker),
    );
  }

  /// True only for a single `.` that is a decimal point (`3.5`) or a
  /// single-letter initial (`U.S.`, `J. R. R.`). Multi-dot runs and `!`/`?`
  /// are always boundaries; abbreviations are handled by [_protectExceptions].
  static bool _isNonBoundaryDot(String work, RegExpMatch m) {
    if (m.end - m.start != 1 || work[m.start] != '.') return false;
    final i = m.start;
    final before = i > 0 ? work[i - 1] : '';
    final after = i + 1 < work.length ? work[i + 1] : '';

    if (_digit.hasMatch(before) && _digit.hasMatch(after)) return true;

    if (_letter.hasMatch(before)) {
      final before2 = i > 1 ? work[i - 2] : '';
      if (before2.isEmpty || !_letter.hasMatch(before2)) return true;
    }
    return false;
  }

  static bool _isWs(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D ||
      codeUnit == 0x0C ||
      codeUnit == 0x0B;
}
