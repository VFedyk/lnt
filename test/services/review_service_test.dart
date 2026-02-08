import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:language_nerd_tools/models/term.dart';
import 'package:language_nerd_tools/services/review_service.dart';

void main() {
  late ReviewService service;

  setUp(() {
    service = ReviewService();
    service.initialize();
  });

  group('mapFsrsToTermStatus', () {
    test('learning state with step 0 returns unknown', () {
      final card = fsrs.Card(cardId: 1)
        ..state = fsrs.State.learning
        ..step = 0;
      expect(ReviewService.mapFsrsToTermStatus(card), TermStatus.unknown);
    });

    test('learning state with step > 0 returns learning2', () {
      final card = fsrs.Card(cardId: 2)
        ..state = fsrs.State.learning
        ..step = 1;
      expect(ReviewService.mapFsrsToTermStatus(card), TermStatus.learning2);
    });

    test('relearning state returns learning2', () {
      final card = fsrs.Card(cardId: 3)..state = fsrs.State.relearning;
      expect(ReviewService.mapFsrsToTermStatus(card), TermStatus.learning2);
    });

    test('review state with stability < 7 returns learning3', () {
      final card = fsrs.Card(cardId: 4)
        ..state = fsrs.State.review
        ..stability = 5.0;
      expect(ReviewService.mapFsrsToTermStatus(card), TermStatus.learning3);
    });

    test('review state with stability < 30 returns learning4', () {
      final card = fsrs.Card(cardId: 5)
        ..state = fsrs.State.review
        ..stability = 15.0;
      expect(ReviewService.mapFsrsToTermStatus(card), TermStatus.learning4);
    });

    test('review state with stability < 90 returns known', () {
      final card = fsrs.Card(cardId: 6)
        ..state = fsrs.State.review
        ..stability = 50.0;
      expect(ReviewService.mapFsrsToTermStatus(card), TermStatus.known);
    });

    test('review state with stability >= 90 returns wellKnown', () {
      final card = fsrs.Card(cardId: 7)
        ..state = fsrs.State.review
        ..stability = 100.0;
      expect(ReviewService.mapFsrsToTermStatus(card), TermStatus.wellKnown);
    });
  });

  group('getNextIntervals', () {
    test('returns an interval for each rating', () {
      final card = fsrs.Card(cardId: 10);
      final intervals = service.getNextIntervals(card);

      expect(intervals.keys, containsAll(fsrs.Rating.values));
      for (final duration in intervals.values) {
        expect(duration, isA<Duration>());
      }
    });
  });

  group('getRetrievability', () {
    test('returns 0 for card with no lastReview', () {
      final card = fsrs.Card(cardId: 20);
      final r = service.getRetrievability(card);
      expect(r, 0.0);
    });

    test('returns value between 0 and 1 for reviewed card', () {
      final card = fsrs.Card(cardId: 21)
        ..state = fsrs.State.review
        ..stability = 10.0
        ..lastReview = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final r = service.getRetrievability(card);
      expect(r, greaterThan(0.0));
      expect(r, lessThanOrEqualTo(1.0));
    });
  });
}
