import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:language_nerd_tools/application/use_cases/review/review_term.dart';
import 'package:language_nerd_tools/domain/value_objects/term_status.dart';

// Static method and pure-computation tests now live on ReviewTerm.
// ReviewService delegates everything to ReviewTerm, so testing the pure
// methods here also validates the delegation chain.

void main() {
  group('ReviewTerm — mapFsrsToTermStatus', () {
    test('learning state with step 0 returns unknown', () {
      final card = fsrs.Card(cardId: 1)
        ..state = fsrs.State.learning
        ..step = 0;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.unknown);
    });

    test('learning state with step > 0 returns learning2', () {
      final card = fsrs.Card(cardId: 2)
        ..state = fsrs.State.learning
        ..step = 1;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.learning2);
    });

    test('relearning state returns learning2', () {
      final card = fsrs.Card(cardId: 3)..state = fsrs.State.relearning;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.learning2);
    });

    test('review state with stability < 7 returns learning3', () {
      final card = fsrs.Card(cardId: 4)
        ..state = fsrs.State.review
        ..stability = 5.0;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.learning3);
    });

    test('review state with stability < 30 returns learning4', () {
      final card = fsrs.Card(cardId: 5)
        ..state = fsrs.State.review
        ..stability = 15.0;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.learning4);
    });

    test('review state with stability < 90 returns known', () {
      final card = fsrs.Card(cardId: 6)
        ..state = fsrs.State.review
        ..stability = 50.0;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.known);
    });

    test('review state with stability >= 90 returns wellKnown', () {
      final card = fsrs.Card(cardId: 7)
        ..state = fsrs.State.review
        ..stability = 100.0;
      expect(ReviewTerm.mapFsrsToTermStatus(card), TermStatus.wellKnown);
    });
  });
}
