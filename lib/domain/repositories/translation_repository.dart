import '../entities/term.dart';

abstract class TranslationRepository {
  Future<String> create(Translation translation);
  Future<List<Translation>> getByTermId(String termId);
  Future<Translation?> getById(String id);
  Future<int> update(Translation translation);
  Future<int> delete(String id);
  Future<int> deleteByTermId(String termId);
  Future<Map<String, List<Translation>>> getByTermIds(List<String> termIds);
  Future<void> replaceForTerm(String termId, List<Translation> translations);
}
