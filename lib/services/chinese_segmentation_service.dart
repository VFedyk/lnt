import 'package:jieba_flutter/analysis/jieba_segmenter.dart';
import 'package:pinyin/pinyin.dart';

/// Provides Chinese-specific NLP utilities:
///   1. Word-level segmentation via jieba (replaces naïve character split)
///   2. Automatic pinyin generation for individual words or full sentences
///
/// This service must be initialised once at app startup (call [init]) before
/// any other method is used.  The jieba dictionary is loaded from Flutter
/// assets the first time [init] is called; subsequent calls are no-ops.
class ChineseSegmentationService {
  bool _initialised = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  /// Loads the jieba dictionary from assets.  Safe to call multiple times.
  Future<void> init() async {
    if (_initialised) return;
    await JiebaSegmenter.init();
    _initialised = true;
  }

  // ── Segmentation ───────────────────────────────────────────────────────────

  /// Segments [text] into a list of [SegmentedWord]s, each carrying the word
  /// string and its byte-offset span inside [text].
  ///
  /// Punctuation and whitespace tokens are filtered out so only learnable
  /// items are returned — matching the contract of [TextParserService].
  ///
  /// Uses jieba's SEARCH mode, which further splits long compounds into their
  /// sub-words.  This produces a better recall for language learning (learners
  /// should know both 北京大学 and 大学 independently).
  List<SegmentedWord> segmentWords(String text) {
    _assertInitialised();
    if (text.isEmpty) return [];

    final seg = JiebaSegmenter();
    final tokens = seg.process(text, SegMode.SEARCH);

    return tokens
        .where((t) => _isLearnableToken(t.word))
        .map(
          (t) => SegmentedWord(
            word: t.word,
            start: t.startOffset,
            end: t.endOffset,
          ),
        )
        .toList();
  }

  /// Returns just the word strings (no offsets) — convenience wrapper.
  List<String> segmentToStrings(String text) =>
      segmentWords(text).map((w) => w.word).toList();

  // ── Pinyin ─────────────────────────────────────────────────────────────────

  /// Returns the toned pinyin for a single Chinese word or short phrase,
  /// e.g. "学生" → "xué shēng".
  ///
  /// If the input contains no Chinese characters the original string is
  /// returned unchanged (safe to call on mixed-script tokens).
  String getPinyin(String word) {
    if (!_containsChinese(word)) return word;
    // PinyinHelper.getPinyinE never throws; unrecognised chars become '#'.
    return PinyinHelper.getPinyinE(
      word,
      separator: ' ',
      format: PinyinFormat.WITH_TONE_MARK,
      defPinyin: word, // fallback for unknown characters
    );
  }

  /// Returns pinyin without tone marks (useful for typing-practice mode).
  String getPinyinNoTones(String word) {
    if (!_containsChinese(word)) return word;
    return PinyinHelper.getPinyinE(
      word,
      separator: ' ',
      format: PinyinFormat.WITHOUT_TONE,
      defPinyin: word,
    );
  }

  /// Annotates every Chinese word in [words] with its pinyin, returning a map
  /// of word → pinyin.  Words that contain no Chinese are mapped to themselves.
  Map<String, String> batchGetPinyin(List<String> words) {
    return {for (final w in words) w: getPinyin(w)};
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _assertInitialised() {
    if (!_initialised) {
      throw StateError(
        'ChineseSegmentationService.init() has not been awaited. '
        'Call await chineseSegService.init() during app startup.',
      );
    }
  }

  /// Returns true when a token is worth showing as a tappable word in the
  /// reader (i.e. it is not pure punctuation or whitespace).
  bool _isLearnableToken(String word) {
    if (word.trim().isEmpty) return false;
    // Reject tokens composed entirely of CJK punctuation or ASCII punctuation.
    return word.runes.any((r) {
      final c = String.fromCharCode(r);
      // Accept if any character is a letter/number (CJK or Latin).
      return RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(c);
    });
  }

  bool _containsChinese(String text) =>
      RegExp(r'[\u4e00-\u9fff\u3400-\u4dbf]').hasMatch(text);
}

/// A word token produced by [ChineseSegmentationService.segmentWords].
class SegmentedWord {
  /// The word string as it appears in the source text.
  final String word;

  /// Inclusive start offset (code-unit index) in the source string.
  final int start;

  /// Exclusive end offset (code-unit index) in the source string.
  final int end;

  const SegmentedWord({
    required this.word,
    required this.start,
    required this.end,
  });

  @override
  String toString() => 'SegmentedWord("$word", $start..$end)';
}
