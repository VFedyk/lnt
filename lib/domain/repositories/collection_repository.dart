import '../entities/collection.dart';

abstract class CollectionRepository {
  Future<String> create(Collection collection);
  Future<List<Collection>> getAll({String? languageId, String? parentId});
  Future<Collection?> getById(String id);
  Future<int> update(Collection collection);
  Future<void> move(String collectionId, String? parentId);
  Future<int> delete(String id);
}
