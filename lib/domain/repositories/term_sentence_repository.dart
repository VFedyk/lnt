import '../entities/term_sentence.dart';

abstract class TermSentenceRepository {
  Future<TermSentence> create(String termId, String sentence, {String? sourceTextId});
  Future<void> update(String id, String sentence);
  Future<List<TermSentence>> getByTermId(String termId);
  Future<Map<String, List<String>>> getByTermIds(List<String> termIds);

  /// Case-insensitive, whitespace-insensitive existence check, so the reader's
  /// "Mine sentence" cannot silently store the same sentence twice.
  Future<bool> existsForTerm(String termId, String sentence);

  Future<void> delete(String id);
}
