import '../entities/text_document.dart';

abstract class TextRepository {
  Future<String> create(TextDocument text);
  Future<List<TextDocument>> getAll({String? languageId});
  Future<TextDocument?> getById(String id);
  Future<int> update(TextDocument text);
  Future<int> delete(String id);
  Future<List<TextDocument>> search(String languageId, String query);
  Future<int> getCountByLanguage(String languageId);
  Future<int> getFinishedCount(String languageId);
  Future<int> getCountInCollection(String collectionId);
  Future<void> moveToCollection(String textId, String? collectionId);
  Future<void> batchCreate(List<TextDocument> texts);
  Future<List<TextDocument>> getByCollection(String collectionId);
  Future<Map<String, int>> getCompletedCountsByDay(String languageId, String sinceIso);
  Future<List<TextDocument>> getRecentlyAdded(String languageId, {int limit = 5});
  Future<List<TextDocument>> getRecentlyRead(String languageId, {int limit = 5});
}
