import '../entities/term.dart';

abstract class TermRepository {
  Future<String> create(Term term);
  Future<List<Term>> getAll({String? languageId, int? status});
  Future<Term?> getByText(String languageId, String text);
  Future<Term?> getById(String id);
  Future<List<Term>> getLinkedTerms(String baseTermId);
  Future<Map<String, Term>> getMapByLanguage(String languageId);
  Future<Map<String, Term>> getByIds(List<String> ids);
  Future<int> update(Term term);
  Future<int> delete(String id);
  Future<int> deleteByLanguage(String languageId);
  Future<Map<int, int>> getCountsByStatus(String languageId);
  Future<int> getTotalCount(String languageId);
  Future<void> bulkCreate(List<Term> terms);
  Future<void> bulkUpdateStatus(List<String> termIds, int newStatus);
  Future<Map<String, int>> getCreatedCountsByDay(String languageId, String sinceIso);
  Future<List<Term>> search(String languageId, String query);
}
