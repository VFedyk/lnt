/// Access to the local, derived text ↔ word-form index.
///
/// The index is keyed on normalized word forms rather than term ids, so it is
/// invariant under term CRUD — only a change to the text's content invalidates
/// it. It is never synced and is rebuildable from `texts.content` at any time.
abstract class TextWordRepository {
  /// Replaces the whole index for [textId] in one transaction.
  /// [words] maps normalized form → (occurrences, firstPosition).
  Future<void> replaceIndex(
    String textId,
    String contentHash,
    Map<String, ({int occurrences, int firstPosition})> words,
  );

  /// The content hash recorded for [textId], or null when never indexed.
  Future<String?> indexedHash(String textId);

  /// Drops the meta row so the next ensureIndexed() call rebuilds.
  Future<void> invalidate(String textId);

  /// Distinct normalized forms in [textId] that match an existing term
  /// in the text's language. Returns term ids.
  Future<List<String>> termIdsInText(String textId, String languageId);

  /// Texts in [languageId] containing at least [minHits] of [termIds],
  /// best candidate first. Already-read texts outrank unread ones.
  Future<List<({String textId, String title, int hits})>> textsContainingTerms(
    String languageId,
    List<String> termIds, {
    int minHits = 2,
    int limit = 3,
  });
}
