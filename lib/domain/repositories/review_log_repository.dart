abstract class ReviewLogRepository {
  Future<int> create(String termId, String logDataJson, DateTime reviewedAt);
  Future<int> getReviewCountToday(String languageId);
  Future<Map<String, int>> getReviewCountsByDay(String languageId, String sinceIso);
}
