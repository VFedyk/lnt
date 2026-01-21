import '../models/collection.dart';
import 'base_repository.dart';

class CollectionRepository extends BaseRepository {
  CollectionRepository(super.getDatabase);

  Future<int> create(Collection collection) async {
    final db = await getDatabase();
    return await db.insert('collections', collection.toMap());
  }

  Future<List<Collection>> getAll({int? languageId, int? parentId}) async {
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

  Future<Collection?> getById(int id) async {
    final db = await getDatabase();
    final maps = await db.query(
      'collections',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Collection.fromMap(maps.first);
  }

  Future<int> update(Collection collection) async {
    final db = await getDatabase();
    return await db.update(
      'collections',
      collection.toMap(),
      where: 'id = ?',
      whereArgs: [collection.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await getDatabase();
    return await db.delete('collections', where: 'id = ?', whereArgs: [id]);
  }
}
