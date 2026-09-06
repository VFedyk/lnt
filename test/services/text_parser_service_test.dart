import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/domain/value_objects/text_parsing_defaults.dart';
import 'package:language_nerd_tools/services/text_parser_service.dart';

void main() {
  late TextParserService parser;

  setUp(() {
    parser = TextParserService();
  });

  Language english() => Language(name: 'English', languageCode: 'en');

  Language german() => Language(
        name: 'German',
        languageCode: 'de',
        characterSubstitutions: 'ß→ss',
      );

  Language chinese() => Language(
        name: 'Chinese',
        languageCode: 'zh',
        splitByCharacter: true,
      );

  Language englishWithExceptions() => Language(
        name: 'English',
        languageCode: 'en',
        exceptionsSplitSentences: 'Mr.|Dr.|Mrs.|etc.',
      );

  // The exact broken literal shipped in Language up to 2026-09 — three ASCII
  // apostrophes in the character class.
  Language legacyEnglish() => Language(
        name: 'English',
        languageCode: 'en',
        regexpWordCharacters: r"[\p{L}\p{M}]+(?:['''][\p{L}\p{M}]+)*",
      );

  group('T1 — no-migration sentinel', () {
    test('fresh Language no longer holds a legacy word pattern', () {
      expect(
        TextParsingDefaults.legacyWordPatterns
            .contains(english().regexpWordCharacters),
        isFalse,
      );
    });

    test('legacy stored pattern is treated as unconfigured', () {
      // The pre-fix literal must still be recognised as a sentinel so the
      // corrected default applies without a migration.
      expect(
        TextParsingDefaults.legacyWordPatterns
            .contains(legacyEnglish().regexpWordCharacters),
        isTrue,
      );
      expect(parser.splitIntoWords('You’ve gone', legacyEnglish()),
          ['You’ve', 'gone']);
    });
  });

  group('splitIntoWords', () {
    test('splits English text into words', () {
      final words = parser.splitIntoWords('Hello world', english());
      expect(words, ['Hello', 'world']);
    });

    test('handles ASCII apostrophes', () {
      final words = parser.splitIntoWords("don't can't", english());
      expect(words, ["don't", "can't"]);
    });

    test('T2 — handles typographic apostrophes (U+2019)', () {
      final words = parser.splitIntoWords('You’ve don’t he’d', english());
      expect(words, ['You’ve', 'don’t', 'he’d']);
    });

    test('skips punctuation and numbers in default pattern', () {
      final words = parser.splitIntoWords('Hello, world! 123', english());
      expect(words, ['Hello', 'world']);
    });

    test('returns empty list for empty input', () {
      expect(parser.splitIntoWords('', english()), isEmpty);
    });

    test('splits character-based language by character', () {
      final words = parser.splitIntoWords('你好世界', chinese());
      expect(words, ['你', '好', '世', '界']);
    });

    test('character-based split skips whitespace and punctuation', () {
      final words = parser.splitIntoWords('你好，世界！', chinese());
      expect(words, ['你', '好', '世', '界']);
    });

    test('T3 — non-length-preserving substitution is dropped', () {
      expect(parser.splitIntoWords('Straße', german()), ['Straße']);
    });

    test('T3 — length-preserving substitution still applies', () {
      final lang = Language(
        name: 'French',
        languageCode: 'fr',
        characterSubstitutions: 'é→e',
      );
      expect(parser.splitIntoWords('café', lang), ['cafe']);
    });
  });

  group('getWordMatches', () {
    test('returns correct positions', () {
      final matches = parser.getWordMatches('Hello world', english());
      expect(matches, hasLength(2));
      expect(matches[0].word, 'Hello');
      expect(matches[0].start, 0);
      expect(matches[0].end, 5);
      expect(matches[1].word, 'world');
      expect(matches[1].start, 6);
      expect(matches[1].end, 11);
    });

    test('returns correct positions for character-based language', () {
      final matches = parser.getWordMatches('你好', chinese());
      expect(matches, hasLength(2));
      expect(matches[0].word, '你');
      expect(matches[0].start, 0);
      expect(matches[1].word, '好');
      expect(matches[1].start, 1);
    });

    test('returns empty for empty text', () {
      expect(parser.getWordMatches('', english()), isEmpty);
    });
  });

  group('splitIntoSentences', () {
    test('T5 — splits on default punctuation, keeping the delimiter', () {
      final sentences = parser.splitIntoSentences(
        'First sentence. Second sentence! Third?',
        english(),
      );
      expect(sentences,
          ['First sentence.', 'Second sentence!', 'Third?']);
    });

    test('returns empty for empty text', () {
      expect(parser.splitIntoSentences('', english()), isEmpty);
    });

    test('handles text with no sentence-ending punctuation', () {
      final sentences =
          parser.splitIntoSentences('Just one sentence', english());
      expect(sentences, ['Just one sentence']);
    });

    test('T5 — protects exceptions and keeps the delimiter', () {
      final sentences = parser.splitIntoSentences(
        'Mr. Smith went home. He was tired.',
        englishWithExceptions(),
      );
      expect(sentences, ['Mr. Smith went home.', 'He was tired.']);
    });

    test('T4 — closing quote stays with the sentence it ends', () {
      final ranges = parser.sentenceRanges(
        'He said time.’\n\n‘Yes.’',
        english(),
      );
      final texts = ranges
          .map((r) => 'He said time.’\n\n‘Yes.’'.substring(r.start, r.end))
          .toList();
      expect(texts, ['He said time.’', '‘Yes.’']);
      expect(texts.any((t) => t.contains('\n\n')), isFalse);
    });

    test('T6 — CJK terminal punctuation splits', () {
      final sentences = parser.splitIntoSentences(
        '他说他会来。我不相信他！你觉得呢？',
        Language(name: 'Chinese', languageCode: 'zh', splitByCharacter: true),
      );
      expect(sentences, hasLength(3));
    });

    test('T7 — abbreviations, decimals and initials with default config', () {
      final sentences = parser.splitIntoSentences(
        'He waited… then left. Dr. Smith arrived at 3.5 km '
        'from the U.S. border. Next one.',
        english(),
      );
      expect(sentences, hasLength(3));
      expect(sentences[0], 'He waited… then left.');
      expect(sentences[2], 'Next one.');
    });

    test('T8 — exception protection is case-insensitive', () {
      final sentences = parser.splitIntoSentences(
        'Dr. Smith met dr. Jones. Then left.',
        english(),
      );
      expect(sentences, hasLength(2));
    });

    test('T9 — blank line is a hard boundary without punctuation', () {
      final sentences = parser.splitIntoSentences(
        'a line of lyrics\n\nanother line of lyrics\n\nyet another',
        english(),
      );
      expect(sentences, hasLength(3));
    });
  });

  group('getSentenceAtPosition', () {
    test('returns sentence containing the position', () {
      final text = 'First sentence. Second sentence. Third sentence.';
      final sentence = parser.getSentenceAtPosition(text, 20, english());
      expect(sentence, 'Second sentence.');
    });

    test('returns first sentence for position 0', () {
      final text = 'First. Second.';
      final sentence = parser.getSentenceAtPosition(text, 0, english());
      expect(sentence, 'First.');
    });

    test('returns empty for empty text', () {
      expect(parser.getSentenceAtPosition('', 0, english()), isEmpty);
    });

    test('protects exceptions', () {
      final text = 'Dr. Smith is here. He said hello.';
      final sentence =
          parser.getSentenceAtPosition(text, 5, englishWithExceptions());
      expect(sentence, 'Dr. Smith is here.');
    });

    test('T10 — position inside a delimiter run resolves to that sentence', () {
      final text = 'First. Second.';
      // index 5 is the '.' terminating "First".
      expect(parser.getSentenceAtPosition(text, 5, english()), 'First.');
    });
  });

  group('T11 — findOccurrence', () {
    test('does not match inside a longer word', () {
      expect(TextParserService.findOccurrence('In London', 'on'), isNull);
      expect(TextParserService.findOccurrence('another', 'he'), isNull);
    });

    test('matches a whole word', () {
      final r = TextParserService.findOccurrence('In London', 'london');
      expect(r, isNotNull);
      expect('In London'.substring(r!.start, r.end), 'London');
    });

    test('matches multi-word terms across whitespace', () {
      final r = TextParserService.findOccurrence(
          'This is my mother tongue now', 'mother tongue');
      expect(r, isNotNull);
      expect('This is my mother tongue now'.substring(r!.start, r.end),
          'mother tongue');
    });

    test('returns null for an empty term', () {
      expect(TextParserService.findOccurrence('anything', ''), isNull);
    });
  });

  group('normalizeWord', () {
    test('lowercases and trims', () {
      expect(parser.normalizeWord(' Hello '), 'hello');
    });

    test('handles already normalized word', () {
      expect(parser.normalizeWord('hello'), 'hello');
    });
  });
}
