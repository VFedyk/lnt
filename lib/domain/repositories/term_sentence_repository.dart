import '../entities/term_sentence.dart';

abstract class TermSentenceRepository {
  Future<TermSentence> create(String termId, String sentence, {String? sourceTextId});
  Future<List<TermSentence>> getByTermId(String termId);
  Future<Map<String, List<String>>> getByTermIds(List<String> termIds);
  Future<void> delete(String id);
}
