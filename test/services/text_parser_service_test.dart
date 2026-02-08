import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/models/language.dart';
import 'package:language_nerd_tools/services/text_parser_service.dart';

void main() {
  late TextParserService parser;

  setUp(() {
    parser = TextParserService();
  });

  Language english() => Language(name: 'English');

  Language german() => Language(
        name: 'German',
        characterSubstitutions: 'ß→ss',
      );

  Language chinese() => Language(
        name: 'Chinese',
        splitByCharacter: true,
      );

  Language englishWithExceptions() => Language(
        name: 'English',
        exceptionsSplitSentences: 'Mr.|Dr.|Mrs.|etc.',
      );

  group('splitIntoWords', () {
    test('splits English text into words', () {
      final words = parser.splitIntoWords('Hello world', english());
      expect(words, ['Hello', 'world']);
    });

    test('handles apostrophes', () {
      final words = parser.splitIntoWords("don't can't", english());
      expect(words, ["don't", "can't"]);
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

    test('applies character substitutions', () {
      final words = parser.splitIntoWords('Straße', german());
      expect(words, ['Strasse']);
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
    test('splits on default punctuation', () {
      final sentences = parser.splitIntoSentences(
        'First sentence. Second sentence! Third?',
        english(),
      );
      expect(sentences, ['First sentence', 'Second sentence', 'Third']);
    });

    test('returns empty for empty text', () {
      expect(parser.splitIntoSentences('', english()), isEmpty);
    });

    test('handles text with no sentence-ending punctuation', () {
      final sentences =
          parser.splitIntoSentences('Just one sentence', english());
      expect(sentences, ['Just one sentence']);
    });

    test('protects exceptions from splitting', () {
      final sentences = parser.splitIntoSentences(
        'Mr. Smith went home. He was tired.',
        englishWithExceptions(),
      );
      expect(sentences, hasLength(2));
      expect(sentences[0], 'Mr. Smith went home');
      expect(sentences[1], 'He was tired');
    });
  });

  group('getSentenceAtPosition', () {
    test('returns sentence containing the position', () {
      final text = 'First sentence. Second sentence. Third sentence.';
      final sentence = parser.getSentenceAtPosition(text, 20, english());
      expect(sentence, 'Second sentence');
    });

    test('returns first sentence for position 0', () {
      final text = 'First. Second.';
      final sentence = parser.getSentenceAtPosition(text, 0, english());
      expect(sentence, 'First');
    });

    test('returns empty for empty text', () {
      expect(parser.getSentenceAtPosition('', 0, english()), isEmpty);
    });

    test('protects exceptions', () {
      final text = 'Dr. Smith is here. He said hello.';
      final sentence =
          parser.getSentenceAtPosition(text, 5, englishWithExceptions());
      expect(sentence, 'Dr. Smith is here');
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
