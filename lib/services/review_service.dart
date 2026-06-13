import 'package:fsrs/fsrs.dart' as fsrs;
import '../application/use_cases/review/review_term.dart';
import '../domain/entities/review_card.dart';
import '../domain/value_objects/term_status.dart';
import '../service_locator.dart';

class ReviewService {
  final ReviewTerm _reviewTerm;

  ReviewService(this._reviewTerm);

  void initialize() {}

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
