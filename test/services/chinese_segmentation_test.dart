// test/services/chinese_segmentation_test.dart
//
// Tests for ChineseSegmentationService and the jieba integration path in
// TextParserService.
//
// NOTE: Because jieba_flutter loads dictionary data from Flutter assets,
// these tests use a lightweight stub/mock strategy so they can run via
// `flutter test` without a full device or asset bundle.
//
// The real ChineseSegmentationService is exercised in a separate
// integration test (see test/integration/chinese_segmentation_integration_test.dart).

import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/services/chinese_segmentation_service.dart';
import 'package:language_nerd_tools/services/text_parser_service.dart';

// ─── Stub ─────────────────────────────────────────────────────────────────────

/// A deterministic stand-in that splits on a simple heuristic (every 2 chars)
/// so tests do not depend on loading the jieba asset bundle.
class _StubChineseSegmentationService extends ChineseSegmentationService {
  // Fixed segmentation results keyed by input string.
  final Map<String, List<SegmentedWord>> _results;

  _StubChineseSegmentationService(this._results);

  @override
  Future<void> init() async {} // no-op

  @override
  List<SegmentedWord> segmentWords(String text) {
    return _results[text] ??
        // Fallback: treat every non-space character as its own token.
        List.generate(
          text.length,
          (i) => SegmentedWord(word: text[i], start: i, end: i + 1),
        ).where((w) => w.word.trim().isNotEmpty).toList();
  }

  @override
  String getPinyin(String word) => '<pinyin:$word>';
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Language _chineseWordSeg() => Language(
  name: 'Chinese',
  languageCode: 'zh',
  splitByCharacter: true,
  useWordSegmentation: true,
  showRomanization: true,
);

Language _chineseCharSeg() => Language(
  name: 'Chinese (char)',
  languageCode: 'zh',
  splitByCharacter: true,
  useWordSegmentation: false,
);

Language _english() => Language(name: 'English', languageCode: 'en');

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('SegmentedWord', () {
    test('stores word, start, and end correctly', () {
      const w = SegmentedWord(word: '学生', start: 0, end: 2);
      expect(w.word, '学生');
      expect(w.start, 0);
      expect(w.end, 2);
    });

    test('toString includes all fields', () {
      const w = SegmentedWord(word: '你好', start: 3, end: 5);
      expect(w.toString(), contains('你好'));
      expect(w.toString(), contains('3'));
      expect(w.toString(), contains('5'));
    });
  });

  group('TextParserService — Chinese word segmentation path', () {
    late _StubChineseSegmentationService stub;
    late TextParserService parser;

    setUp(() {
      // Arrange: stub returns specific word tokens for our test sentences.
      stub = _StubChineseSegmentationService({
        '我喜欢学习中文': [
          SegmentedWord(word: '我', start: 0, end: 1),
          SegmentedWord(word: '喜欢', start: 1, end: 3),
          SegmentedWord(word: '学习', start: 3, end: 5),
          SegmentedWord(word: '中文', start: 5, end: 7),
        ],
        '北京大学': [
          SegmentedWord(word: '北京', start: 0, end: 2),
          SegmentedWord(word: '大学', start: 2, end: 4),
          SegmentedWord(
            word: '北京大学',
            start: 0,
            end: 4,
          ), // SEARCH mode sub-token
        ],
      });
      parser = TextParserService(chineseSeg: stub);
    });

    test('getWordMatches delegates to jieba when useWordSegmentation=true', () {
      final lang = _chineseWordSeg();
      final matches = parser.getWordMatches('我喜欢学习中文', lang);

      expect(matches.map((m) => m.word), containsAll(['我', '喜欢', '学习', '中文']));
    });

    test('getWordMatches returns WordMatch objects with correct offsets', () {
      final lang = _chineseWordSeg();
      final matches = parser.getWordMatches('我喜欢学习中文', lang);

      final xiHuan = matches.firstWhere((m) => m.word == '喜欢');
      expect(xiHuan.start, 1);
      expect(xiHuan.end, 3);
    });

    test(
      'getWordMatches falls back to per-character when useWordSegmentation=false',
      () {
        final lang = _chineseCharSeg();
        final matches = parser.getWordMatches('中文', lang);

        // Character mode: every character is its own token.
        expect(matches.length, 2);
        expect(matches[0].word, '中');
        expect(matches[1].word, '文');
      },
    );

    test('getWordMatches uses regex for non-CJK languages (English)', () {
      final lang = _english();
      final matches = parser.getWordMatches('Hello world', lang);

      expect(matches.map((m) => m.word), containsAll(['Hello', 'world']));
    });

    test('splitIntoWords with useWordSegmentation returns jieba tokens', () {
      final lang = _chineseWordSeg();
      final words = parser.splitIntoWords('我喜欢学习中文', lang);

      expect(words, containsAll(['我', '喜欢', '学习', '中文']));
    });

    test('getWordMatches with empty string returns empty list', () {
      final lang = _chineseWordSeg();
      expect(parser.getWordMatches('', lang), isEmpty);
    });

    test('SEARCH mode can return overlapping sub-tokens (北京 in 北京大学)', () {
      final lang = _chineseWordSeg();
      final matches = parser.getWordMatches('北京大学', lang);

      final words = matches.map((m) => m.word).toSet();
      expect(words, containsAll(['北京', '大学']));
    });
  });

  group('Language model — useWordSegmentation', () {
    test('defaults to false', () {
      final lang = Language(name: 'Test', languageCode: 'zh');
      expect(lang.useWordSegmentation, isFalse);
    });

    test('can be set to true', () {
      final lang = Language(
        name: 'Chinese',
        languageCode: 'zh',
        splitByCharacter: true,
        useWordSegmentation: true,
      );
      expect(lang.useWordSegmentation, isTrue);
    });

    test('serialises to/from map correctly', () {
      final lang = Language(
        name: 'Chinese',
        languageCode: 'zh',
        splitByCharacter: true,
        useWordSegmentation: true,
      );
      final map = lang.toMap();
      expect(map['use_word_segmentation'], 1);

      final restored = Language.fromMap(map);
      expect(restored.useWordSegmentation, isTrue);
    });

    test('fromMap with missing column defaults to false (migration safety)', () {
      // Simulate a map from an older DB that has no use_word_segmentation key.
      final map = {
        'id': 'lang-zh',
        'name': 'Chinese',
        'language_code': 'zh',
        'right_to_left': 0,
        'show_romanization': 0,
        'split_by_character': 1,
        // 'use_word_segmentation' intentionally absent
        'character_substitutions': '',
        'regexp_word_characters': '',
        'regexp_split_sentences': '',
        'exceptions_split_sentences': '',
      };
      final lang = Language.fromMap(map);
      expect(lang.useWordSegmentation, isFalse);
    });

    test('copyWith preserves useWordSegmentation when not overridden', () {
      final lang = Language(
        name: 'Chinese',
        languageCode: 'zh',
        useWordSegmentation: true,
      );
      final copied = lang.copyWith(name: 'Mandarin');
      expect(copied.useWordSegmentation, isTrue);
    });

    test('copyWith can change useWordSegmentation', () {
      final lang = Language(
        name: 'Chinese',
        languageCode: 'zh',
        useWordSegmentation: true,
      );
      final disabled = lang.copyWith(useWordSegmentation: false);
      expect(disabled.useWordSegmentation, isFalse);
    });
  });

  group('ChineseSegmentationService — unit (stub)', () {
    test('getPinyin returns annotated stub value', () {
      final svc = _StubChineseSegmentationService({});
      expect(svc.getPinyin('你好'), '<pinyin:你好>');
    });

    test('segmentWords falls back for unknown input', () {
      final svc = _StubChineseSegmentationService({});
      final words = svc.segmentWords('AB');
      // Fallback: character by character, whitespace filtered.
      expect(words.map((w) => w.word), containsAll(['A', 'B']));
    });
  });
}
