import '../entities/review_card.dart';
import '../value_objects/review_scope.dart';

abstract class ReviewCardRepository {
  Future<String> create(ReviewCardRecord record);
  Future<ReviewCardRecord?> getByTermId(String termId);
  Future<int> update(ReviewCardRecord record);
  Future<int> deleteByTermId(String termId);
  Future<List<ReviewCardRecord>> getDueCards(String languageId,
      {DateTime? now, int? limit, ReviewScope scope = const ReviewScope()});
  Future<int> getDueCount(String languageId,
      {DateTime? now, ReviewScope scope = const ReviewScope()});

  /// Due cards that have at least one stored sentence. Honours the ignored
  /// guard, the scope and the daily new-card budget, but deliberately NOT the
  /// session card limit: the caller must first drop the cards whose sentence
  /// has no usable occurrence, and only then trim to the session size.
  Future<List<ReviewCardRecord>> getClozeDueCandidates(String languageId,
      {DateTime? now, ReviewScope scope = const ReviewScope()});
  Future<DateTime?> getNextDueDate(String languageId);
  Future<ReviewCardRecord> getOrCreate(String termId);
  Future<void> ensureCardsExist(List<String> termIds);

  /// Number of cards due per day for the next [days] days. The first bucket
  /// (today) folds in any overdue cards. Every day in the range is present,
  /// including those with a zero count, for a continuous chart.
  Future<List<({DateTime date, int count})>> getDueForecast(
    String languageId, {
    int days,
    DateTime? now,
  });
}
