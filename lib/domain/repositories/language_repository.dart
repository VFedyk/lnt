import '../entities/language.dart';

abstract class LanguageRepository {
  Future<String> create(Language language);
  Future<List<Language>> getAll();
  Future<Language?> getById(String id);
  Future<int> update(Language language);
  Future<int> delete(String id);
}
