import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:mocktail/mocktail.dart';

import 'package:language_nerd_tools/application/use_cases/review/count_cloze_due.dart';
import 'package:language_nerd_tools/domain/entities/language.dart';
import 'package:language_nerd_tools/domain/entities/review_card.dart';
import 'package:language_nerd_tools/domain/entities/term.dart';
import 'package:language_nerd_tools/domain/repositories/review_card_repository.dart';
import 'package:language_nerd_tools/domain/repositories/term_repository.dart';
import 'package:language_nerd_tools/domain/repositories/term_sentence_repository.dart';
import 'package:language_nerd_tools/domain/value_objects/review_scope.dart';

class _MockCards extends Mock implements ReviewCardRepository {}

class _MockTerms extends Mock implements TermRepository {}

class _MockSentences extends Mock implements TermSentenceRepository {}

ReviewCardRecord _card(String termId) => ReviewCardRecord(
      termId: termId,
      cardData: fsrs.Card(cardId: 1, due: DateTime.now()).toMap(),
      nextDue: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

Term _term(String id, String text) =>
    Term(id: id, languageId: 'l1', text: text, lowerText: text.toLowerCase());

void main() {
  setUpAll(() => registerFallbackValue(const ReviewScope()));

  late _MockCards cards;
  late _MockTerms terms;
  late _MockSentences sentences;
  late CountClozeDue useCase;

  final language = Language(id: 'l1', name: 'English', languageCode: 'en');

  setUp(() {
    cards = _MockCards();
    terms = _MockTerms();
    sentences = _MockSentences();
    useCase = CountClozeDue(
      reviewCards: cards,
      terms: terms,
      sentences: sentences,
    );
  });

  test('excludes a term whose only sentence has no boundary occurrence',
      () async {
    when(() => cards.getClozeDueCandidates(any(),
        now: any(named: 'now'),
        scope: any(named: 'scope'))).thenAnswer((_) async => [_card('t1')]);
    when(() => terms.getByIds(any()))
        .thenAnswer((_) async => {'t1': _term('t1', 'on')});
    when(() => sentences.getByTermIds(any())).thenAnswer(
        (_) async => {'t1': ['I went to London yesterday.']});

    expect(await useCase(language), 0);
  });

  test('counts a term once when at least one of its sentences is usable',
      () async {
    when(() => cards.getClozeDueCandidates(any(),
        now: any(named: 'now'),
        scope: any(named: 'scope'))).thenAnswer((_) async => [_card('t1')]);
    when(() => terms.getByIds(any()))
        .thenAnswer((_) async => {'t1': _term('t1', 'cat')});
    when(() => sentences.getByTermIds(any())).thenAnswer((_) async => {
          't1': ['No match here.', 'The cat sat down.'],
        });

    expect(await useCase(language), 1);
  });
}
