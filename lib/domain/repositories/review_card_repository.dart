import '../entities/review_card.dart';

abstract class ReviewCardRepository {
  Future<String> create(ReviewCardRecord record);
  Future<ReviewCardRecord?> getByTermId(String termId);
  Future<int> update(ReviewCardRecord record);
  Future<int> deleteByTermId(String termId);
  Future<List<ReviewCardRecord>> getDueCards(String languageId, {DateTime? now, int? limit});
  Future<int> getDueCount(String languageId, {DateTime? now});
  Future<int> getClozeDueCount(String languageId, {DateTime? now});
  Future<DateTime?> getNextDueDate(String languageId);
  Future<ReviewCardRecord> getOrCreate(String termId);
  Future<void> ensureCardsExist(List<String> termIds);
}
