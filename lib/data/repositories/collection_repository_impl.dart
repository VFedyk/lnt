import 'package:uuid/uuid.dart';
import '../../domain/entities/collection.dart';
import '../../domain/repositories/collection_repository.dart';
import 'base_repository.dart';

const _uuid = Uuid();

const _select = '''
  SELECT c.*, ci.local_path AS cover_image
  FROM collections c
  LEFT JOIN cover_images ci ON ci.id = c.cover_image_id
''';

class CollectionRepositoryImpl extends BaseRepository
    implements CollectionRepository {
  CollectionRepositoryImpl(super.getDatabase, {super.onChange});

  @override
  Future<String> create(Collection collection) async {
    final db = await getDatabase();
    final id = collection.id ?? _uuid.v4();
    final coverImageId = await BaseRepository.getOrCreateCoverImageId(db, collection.coverImage);
    await db.insert('collections', collection.copyWith(id: id, coverImageId: coverImageId).toMap());
    notifyChange();
    return id;
  }

  @override
  Future<List<Collection>> getAll({String? languageId, String? parentId}) async {
    final db = await getDatabase();

    String where = '';
    final args = <dynamic>[];

    if (languageId != null && parentId != null) {
      where = 'WHERE c.language_id = ? AND c.parent_id = ?';
      args.addAll([languageId, parentId]);
    } else if (languageId != null) {
      where = 'WHERE c.language_id = ? AND c.parent_id IS NULL';
      args.add(languageId);
    } else if (parentId != null) {
      where = 'WHERE c.parent_id = ?';
      args.add(parentId);
    }

    final maps = await db.rawQuery(
      '$_select $where ORDER BY c.sort_order ASC, c.name ASC',
      args,
    );
    return maps.map((map) => Collection.fromMap(map)).toList();
  }

  @override
  Future<Collection?> getById(String id) async {
    final db = await getDatabase();
    final maps = await db.rawQuery('$_select WHERE c.id = ?', [id]);
    if (maps.isEmpty) return null;
    return Collection.fromMap(maps.first);
  }

  @override
  Future<int> update(Collection collection) async {
    final db = await getDatabase();
    final coverImageId = collection.coverImageId ??
        await BaseRepository.getOrCreateCoverImageId(db, collection.coverImage);
    final result = await db.update(
      'collections',
      collection.copyWith(coverImageId: coverImageId).toMap(),
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
