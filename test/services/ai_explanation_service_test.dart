import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/data/services/ai_explanation_service.dart';

void main() {
  group('stripThinking', () {
    test('removes a closed think block', () {
      const raw = '<think>let me consider…</think>\ncat | noun';
      expect(AiExplanationService.stripThinking(raw), 'cat | noun');
    });

    test('removes multiple closed think blocks', () {
      const raw = '<think>a</think>cat | noun\n<think>b</think>dog | noun';
      expect(
        AiExplanationService.stripThinking(raw),
        'cat | noun\ndog | noun',
      );
    });

    test('truncates from an unclosed think tag', () {
      const raw = 'cat | noun\n<think>the answer was cut off mid-';
      expect(AiExplanationService.stripThinking(raw), 'cat | noun');
    });

    test('leaves content without tags unchanged', () {
      const raw = 'cat | noun\ndog | noun';
      expect(AiExplanationService.stripThinking(raw), raw);
    });

    test('is case-insensitive', () {
      const raw = '<THINK>hmm</Think>\ncat | noun';
      expect(AiExplanationService.stripThinking(raw), 'cat | noun');
    });

    test('returns empty string when only thinking is present', () {
      expect(AiExplanationService.stripThinking('<think>only</think>'), '');
    });
  });

  group('parseTranslationLine', () {
    test('parses a plain line', () {
      final result = AiExplanationService.parseTranslationLine('cat | noun');
      expect(result.meaning, 'cat');
      expect(result.partOfSpeech, 'noun');
    });

    test('strips numbering', () {
      final result = AiExplanationService.parseTranslationLine('1. cat | noun');
      expect(result.meaning, 'cat');
      expect(result.partOfSpeech, 'noun');
    });

    test('strips parenthesized numbering', () {
      final result = AiExplanationService.parseTranslationLine('2) cat | noun');
      expect(result.meaning, 'cat');
      expect(result.partOfSpeech, 'noun');
    });

    test('strips bullets', () {
      final result = AiExplanationService.parseTranslationLine('- cat | noun');
      expect(result.meaning, 'cat');
      expect(result.partOfSpeech, 'noun');
    });

    test('strips bold markers around the whole line', () {
      final result = AiExplanationService.parseTranslationLine(
        '**cat | noun**',
      );
      expect(result.meaning, 'cat');
      expect(result.partOfSpeech, 'noun');
    });

    test('strips italic markers around the whole line', () {
      final result = AiExplanationService.parseTranslationLine('*cat | noun*');
      expect(result.meaning, 'cat');
      expect(result.partOfSpeech, 'noun');
    });

    test('line without a pipe yields null part of speech', () {
      final result = AiExplanationService.parseTranslationLine('cat');
      expect(result.meaning, 'cat');
      expect(result.partOfSpeech, isNull);
    });

    test('invalid part of speech yields null', () {
      final result = AiExplanationService.parseTranslationLine(
        'cat | substantive',
      );
      expect(result.meaning, 'cat');
      expect(result.partOfSpeech, isNull);
    });

    test('part of speech is normalized to lowercase', () {
      final result = AiExplanationService.parseTranslationLine('cat | Noun');
      expect(result.partOfSpeech, 'noun');
    });

    test('translation containing a pipe splits on the last pipe', () {
      final result = AiExplanationService.parseTranslationLine(
        'to run | to race | verb',
      );
      expect(result.meaning, 'to run | to race');
      expect(result.partOfSpeech, 'verb');
    });

    test('empty meaning falls back to the whole line', () {
      final result = AiExplanationService.parseTranslationLine('| noun');
      expect(result.meaning, '| noun');
      expect(result.partOfSpeech, 'noun');
    });
  });
}
