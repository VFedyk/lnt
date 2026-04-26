import 'package:uuid/uuid.dart';
import '../../domain/entities/collection.dart';
import '../../domain/repositories/collection_repository.dart';
import 'base_repository.dart';

const _uuid = Uuid();

class CollectionRepositoryImpl extends BaseRepository
    implements CollectionRepository {
  CollectionRepositoryImpl(super.getDatabase, {super.onChange});

  @override
  Future<String> create(Collection collection) async {
    final db = await getDatabase();
    final id = collection.id ?? _uuid.v4();
    await db.insert('collections', collection.copyWith(id: id).toMap());
    notifyChange();
    return id;
  }

  @override
  Future<List<Collection>> getAll({String? languageId, String? parentId}) async {
    final db = await getDatabase();
    String? where;
    List<dynamic>? whereArgs;

    if (languageId != null && parentId != null) {
      where = 'language_id = ? AND parent_id = ?';
      whereArgs = [languageId, parentId];
    } else if (languageId != null) {
      where = 'language_id = ? AND parent_id IS NULL';
      whereArgs = [languageId];
    } else if (parentId != null) {
      where = 'parent_id = ?';
      whereArgs = [parentId];
    }

    final maps = await db.query(
      'collections',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'sort_order ASC, name ASC',
    );

    return maps.map((map) => Collection.fromMap(map)).toList();
  }

  @override
  Future<Collection?> getById(String id) async {
    final db = await getDatabase();
    final maps = await db.query(
      'collections',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Collection.fromMap(maps.first);
  }

  @override
  Future<int> update(Collection collection) async {
    final db = await getDatabase();
    final result = await db.update(
      'collections',
      collection.toMap(),
      where: 'id = ?',
      whereArgs: [collection.id],
    );
    notifyChange();
    return result;
  }

  @override
  Future<void> move(String collectionId, String? parentId) async {
    final db = await getDatabase();
    await db.update(
      'collections',
      {'parent_id': parentId},
      where: 'id = ?',
      whereArgs: [collectionId],
    );
    notifyChange();
  }

  @override
  Future<int> delete(String id) async {
    final db = await getDatabase();
    final result = await db.delete('collections', where: 'id = ?', whereArgs: [id]);
    notifyChange();
    return result;
  }
}
