import '../entities/dictionary.dart';

abstract class DictionaryRepository {
  Future<String> create(Dictionary dictionary);
  Future<List<Dictionary>> getAll({String? languageId, bool activeOnly = false});
  Future<Dictionary?> getById(String id);
  Future<int> update(Dictionary dictionary);
  Future<int> delete(String id);
  Future<int> deleteByLanguage(String languageId);
  Future<void> reorder(List<Dictionary> dictionaries);
}
