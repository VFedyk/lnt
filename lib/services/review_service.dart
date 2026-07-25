import 'package:fsrs/fsrs.dart' as fsrs;
import '../application/use_cases/review/review_term.dart';
import '../domain/entities/review_card.dart';
import '../domain/value_objects/term_status.dart';
import '../service_locator.dart';

class ReviewService {
  final ReviewTerm _reviewTerm;

  ReviewService(this._reviewTerm);

  /// Loads the persisted desired retention and applies it to the scheduler.
  /// Called once at app startup.
  Future<void> initialize() async {
    final retention = await settings.getDesiredRetention();
    _reviewTerm.configure(desiredRetention: retention);
  }

  /// Rebuilds the scheduler with a new desired retention rate. Call after the
  /// setting changes so interval previews and future scheduling reflect it.
  void configure({required double desiredRetention}) {
    _reviewTerm.configure(desiredRetention: desiredRetention);
  }

  Future<({ReviewCardRecord updatedCard, int newStatus})> reviewTerm(
    ReviewCardRecord record,
    fsrs.Rating rating, {
    bool notify = true,
  }) async {
    final result = await _reviewTerm(record, rating);
    if (notify) {
      dataChanges.reviewCards.notify();
      dataChanges.terms.notify();
    }
    return result;
  }

  /// Practice pass: persists nothing.
  ///
  /// Reviewing ahead of schedule shrinks elapsed-days and depresses FSRS's
  /// stability gain, so a text-scoped "practice all" session must not grade.
  /// Kept as an explicit call site rather than a bare `if` at each rating
  /// handler so the "nothing is written" decision stays visible.
  Future<void> practiceTerm(ReviewCardRecord record, fsrs.Rating rating) async {
    // Intentionally empty.
  }

  Map<fsrs.Rating, Duration> getNextIntervals(Map<String, dynamic> cardData) =>
      _reviewTerm.nextIntervals(cardData);

  double getRetrievability(Map<String, dynamic> cardData) =>
      _reviewTerm.retrievability(cardData);

  Future<void> seedCardsForLanguage(String languageId) async {
    final allTerms = await db.terms.getAll(languageId: languageId);
    final eligibleIds = allTerms
        .where(
          (t) => t.id != null && t.status != TermStatus.ignored,
        )
        .map((t) => t.id!)
        .toList();
    if (eligibleIds.isNotEmpty) {
      await db.reviewCards.ensureCardsExist(eligibleIds);
    }
  }
}
