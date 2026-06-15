import '../entities/review_card.dart';

abstract class ReviewCardRepository {
  Future<String> create(ReviewCardRecord record);
  Future<ReviewCardRecord?> getByTermId(String termId);
  Future<int> update(ReviewCardRecord record);
  Future<int> deleteByTermId(String termId);
  Future<List<ReviewCardRecord>> getDueCards(String languageId,
      {DateTime? now, int? limit, List<int>? statuses});
  Future<int> getDueCount(String languageId, {DateTime? now, List<int>? statuses});
  Future<int> getClozeDueCount(String languageId,
      {DateTime? now, List<int>? statuses});
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
