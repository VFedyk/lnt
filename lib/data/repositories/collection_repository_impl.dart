import 'package:uuid/uuid.dart';
import '../../domain/entities/book_progress.dart';
import '../../domain/entities/collection.dart';
import '../../domain/entities/text_document.dart';
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

  /// Last-write timestamp stamped on every mutation, so sync can order edits.
  static String _nowIso() => DateTime.now().toUtc().toIso8601String();

  @override
  Future<String> create(Collection collection) async {
    final db = await getDatabase();
    final id = collection.id ?? _uuid.v4();
    final coverImageId = await BaseRepository.getOrCreateCoverImageId(db, collection.coverImage);
    await db.insert('collections',
        collection.copyWith(id: id, coverImageId: coverImageId).toMap()
          ..['updated_at'] = _nowIso());
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
      collection.copyWith(coverImageId: coverImageId).toMap()
        ..['updated_at'] = _nowIso(),
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
      {'parent_id': parentId, 'updated_at': _nowIso()},
      where: 'id = ?',
      whereArgs: [collectionId],
    );
    notifyChange();
  }

  @override
  Future<int> delete(String id) async {
    final db = await getDatabase();
    final result = await db.delete('collections', where: 'id = ?', whereArgs: [id]);
    if (result > 0) await BaseRepository.recordTombstone(db, 'collection', id);
    notifyChange();
    return result;
  }

  @override
  Future<List<BookProgress>> getBookProgress(
    String languageId, {
    int? limit,
    bool excludeCompleted = false,
  }) async {
    final db = await getDatabase();
    final maps = await db.rawQuery('''
      SELECT
        c.id                                                          AS collection_id,
        c.name                                                        AS name,
        ci.local_path                                                 AS cover_image,
        SUM(LENGTH(t.content))                                        AS total_length,
        SUM(CASE WHEN t.status = 2 THEN LENGTH(t.content) ELSE 0 END) AS read_length,
        COUNT(t.id)                                                   AS total_texts,
        SUM(CASE WHEN t.status = 2 THEN 1 ELSE 0 END)                 AS finished_texts,
        MAX(t.last_read)                                              AS last_read
      FROM collections c
      JOIN texts t              ON t.collection_id = c.id
      LEFT JOIN cover_images ci ON ci.id = c.cover_image_id
      WHERE c.language_id = ? AND c.is_continuous = 1
      GROUP BY c.id
      HAVING total_length > 0
        ${excludeCompleted ? 'AND read_length < total_length' : ''}
      ORDER BY last_read DESC
      ${limit != null ? 'LIMIT ?' : ''}
    ''', [languageId, ?limit]);
    return maps.map(BookProgress.fromMap).toList();
  }

  @override
  Future<TextDocument?> getNextUnfinishedText(String collectionId) async {
    final db = await getDatabase();
    final maps = await db.rawQuery('''
      SELECT t.*, ci.local_path AS cover_image
      FROM texts t
      LEFT JOIN cover_images ci ON ci.id = t.cover_image_id
      WHERE t.collection_id = ?
      ORDER BY (t.status = 2) ASC, t.sort_order ASC, t.title ASC
      LIMIT 1
    ''', [collectionId]);
    if (maps.isEmpty) return null;
    return TextDocument.fromMap(maps.first);
  }
}
