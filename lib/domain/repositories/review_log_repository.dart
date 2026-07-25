abstract class ReviewLogRepository {
  Future<int> create(String termId, String logDataJson, DateTime reviewedAt);
  Future<int> getReviewCountToday(String languageId);
  Future<Map<String, int>> getReviewCountsByDay(String languageId, String sinceIso);

  /// Retention over the last [days]: how many reviews were recalled (rated
  /// better than "again") out of the total in the window.
  Future<({int total, int recalled})> getRetention(
    String languageId, {
    int days,
  });

  /// Number of `again` ratings per term within the last [days]. Only the given
  /// [termIds] are inspected, so the JSON decode stays bounded. Terms with no
  /// lapses are absent from the result.
  Future<Map<String, int>> getLapseCounts(List<String> termIds, {int days = 90});

  /// All reviews for a single term, oldest first. `rating` is the FSRS rating
  /// (1=again … 4=easy); `durationMs` is the review duration if recorded.
  Future<List<({DateTime reviewedAt, int rating, int? durationMs})>> getByTermId(
    String termId,
  );
}
