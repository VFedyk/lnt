import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:mocktail/mocktail.dart';

import 'package:language_nerd_tools/application/use_cases/review/review_term.dart';
import 'package:language_nerd_tools/domain/entities/review_card.dart';
import 'package:language_nerd_tools/domain/entities/term.dart';
import 'package:language_nerd_tools/domain/repositories/review_card_repository.dart';
import 'package:language_nerd_tools/domain/repositories/review_log_repository.dart';
import 'package:language_nerd_tools/domain/repositories/term_repository.dart';
import 'package:language_nerd_tools/domain/repositories/term_status_log_repository.dart';
import 'package:language_nerd_tools/domain/value_objects/term_status.dart';

class MockReviewCardRepository extends Mock implements ReviewCardRepository {}
class MockTermRepository extends Mock implements TermRepository {}
class MockReviewLogRepository extends Mock implements ReviewLogRepository {}
class MockTermStatusLogRepository extends Mock implements TermStatusLogRepository {}
class _FakeReviewCardRecord extends Fake implements ReviewCardRecord {}
class _FakeTerm extends Fake implements Term {}

ReviewCardRecord _makeRecord({String termId = 'term-1'}) {
  final now = DateTime.now().toUtc();
  return ReviewCardRecord(
    id: 'card-1',
    termId: termId,
    cardData: fsrs.Card(cardId: 1).toMap(),
    nextDue: now,
    createdAt: now,
    updatedAt: now,
  );
}

Term _makeTerm({String id = 'term-1', int status = TermStatus.unknown}) =>
    Term(id: id, languageId: 'lang-1', text: 'hello', lowerText: 'hello', status: status);

void main() {
  late MockReviewCardRepository mockReviewCards;
  late MockTermRepository mockTerms;
  late MockReviewLogRepository mockReviewLogs;
  late MockTermStatusLogRepository mockTermStatusLog;
  late ReviewTerm useCase;

  setUpAll(() {
    registerFallbackValue(_FakeReviewCardRecord());
    registerFallbackValue(_FakeTerm());
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    mockReviewCards = MockReviewCardRepository();
    mockTerms = MockTermRepository();
    mockReviewLogs = MockReviewLogRepository();
    mockTermStatusLog = MockTermStatusLogRepository();

    useCase = ReviewTerm(
      reviewCards: mockReviewCards,
      terms: mockTerms,
      reviewLogs: mockReviewLogs,
      termStatusLog: mockTermStatusLog,
    );

    when(() => mockReviewLogs.create(any(), any(), any())).thenAnswer((_) async => 1);
    when(() => mockReviewCards.update(any())).thenAnswer((_) async => 1);
    when(() => mockTerms.update(any())).thenAnswer((_) async => 1);
    when(() => mockTermStatusLog.logChange(any(), any(), any())).thenAnswer((_) async {});
  });

  group('call()', () {
    test('writes review log, updates card, updates term status', () async {
      final record = _makeRecord();
      final term = _makeTerm();
      when(() => mockTerms.getById(record.termId)).thenAnswer((_) async => term);

      final result = await useCase(record, fsrs.Rating.good);

      verify(() => mockReviewLogs.create(record.termId, any(), any())).called(1);
      verify(() => mockReviewCards.update(any())).called(1);
      verify(() => mockTerms.update(any())).called(1);
      verify(() => mockTermStatusLog.logChange(record.termId, any(), any())).called(1);
      expect(result.updatedCard.termId, record.termId);
      expect(result.newStatus, isA<int>());
    });

    test('skips term update when term status is ignored', () async {
      final record = _makeRecord();
      final ignoredTerm = _makeTerm(status: TermStatus.ignored);
      when(() => mockTerms.getById(record.termId)).thenAnswer((_) async => ignoredTerm);

      await useCase(record, fsrs.Rating.good);

      verifyNever(() => mockTerms.update(any()));
      verifyNever(() => mockTermStatusLog.logChange(any(), any(), any()));
      // review log and card still get written
      verify(() => mockReviewLogs.create(any(), any(), any())).called(1);
      verify(() => mockReviewCards.update(any())).called(1);
    });

    test('skips term update when term not found', () async {
      final record = _makeRecord();
      when(() => mockTerms.getById(record.termId)).thenAnswer((_) async => null);

      await useCase(record, fsrs.Rating.good);

      verifyNever(() => mockTerms.update(any()));
      verifyNever(() => mockTermStatusLog.logChange(any(), any(), any()));
    });

    test('returned updatedCard has correct termId and non-null id', () async {
      final record = _makeRecord();
      when(() => mockTerms.getById(any())).thenAnswer((_) async => _makeTerm());

      final result = await useCase(record, fsrs.Rating.again);

      expect(result.updatedCard.id, record.id);
      expect(result.updatedCard.termId, record.termId);
    });
  });

  group('nextIntervals()', () {
    test('returns a duration for every Rating value', () {
      final card = fsrs.Card(cardId: 1);
      final intervals = useCase.nextIntervals(card.toMap());

      expect(intervals.keys, containsAll(fsrs.Rating.values));
    });

    test('all durations are positive', () {
      final card = fsrs.Card(cardId: 2);
      final intervals = useCase.nextIntervals(card.toMap());

      for (final d in intervals.values) {
        expect(d.isNegative, isFalse);
      }
    });
  });

  group('retrievability()', () {
    test('returns 0 for a brand-new card', () {
      final card = fsrs.Card(cardId: 10);
      expect(useCase.retrievability(card.toMap()), 0.0);
    });

    test('returns value in (0, 1] for a reviewed card', () {
      final card = fsrs.Card(cardId: 11)
        ..state = fsrs.State.review
        ..stability = 10.0
        ..lastReview = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final r = useCase.retrievability(card.toMap());
      expect(r, greaterThan(0.0));
      expect(r, lessThanOrEqualTo(1.0));
    });
  });

  group('mapFsrsToTermStatus()', () {
    test('learning step 0 → unknown', () {
      final card = fsrs.Card(cardId: 20)
        ..state = fsrs.State.learning
        ..step = 0;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.unknown);
    });

    test('learning step 1 → learning2', () {
      final card = fsrs.Card(cardId: 21)
        ..state = fsrs.State.learning
        ..step = 1;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.learning2);
    });

    test('relearning → learning2', () {
      final card = fsrs.Card(cardId: 22)..state = fsrs.State.relearning;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.learning2);
    });

    test('review stability 5 → learning3', () {
      final card = fsrs.Card(cardId: 23)
        ..state = fsrs.State.review
        ..stability = 5.0;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.learning3);
    });

    test('review stability 15 → learning4', () {
      final card = fsrs.Card(cardId: 24)
        ..state = fsrs.State.review
        ..stability = 15.0;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.learning4);
    });

    test('review stability 60 → known', () {
      final card = fsrs.Card(cardId: 25)
        ..state = fsrs.State.review
        ..stability = 60.0;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.known);
    });

    test('review stability 100 → wellKnown', () {
      final card = fsrs.Card(cardId: 26)
        ..state = fsrs.State.review
        ..stability = 100.0;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.wellKnown);
    });
  });
}
