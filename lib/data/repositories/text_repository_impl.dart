import 'package:uuid/uuid.dart';
import '../../domain/entities/text_document.dart';
import '../../domain/repositories/text_repository.dart';
import 'base_repository.dart';

const _uuid = Uuid();

// All reads JOIN cover_images so TextDocument.coverImage is always populated.
const _select = '''
  SELECT t.*, ci.local_path AS cover_image
  FROM texts t
  LEFT JOIN cover_images ci ON ci.id = t.cover_image_id
''';

class TextRepositoryImpl extends BaseRepository implements TextRepository {
  TextRepositoryImpl(super.getDatabase, {super.onChange});

  @override
  Future<String> create(TextDocument text) async {
    final db = await getDatabase();
    final id = text.id ?? _uuid.v4();
    final now = DateTime.now().toUtc();
    final coverImageId = await BaseRepository.getOrCreateCoverImageId(db, text.coverImage);
    await db.insert(
      'texts',
      text.copyWith(id: id, coverImageId: coverImageId, updatedAt: now).toMap(),
    );
    notifyChange();
    return id;
  }

  @override
  Future<List<TextDocument>> getAll({String? languageId}) async {
    final db = await getDatabase();
    final maps = languageId != null
        ? await db.rawQuery(
            '$_select WHERE t.language_id = ? ORDER BY t.last_read DESC',
            [languageId],
          )
        : await db.rawQuery('$_select ORDER BY t.last_read DESC');
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }

  @override
  Future<TextDocument?> getById(String id) async {
    final db = await getDatabase();
    final maps = await db.rawQuery('$_select WHERE t.id = ?', [id]);
    if (maps.isEmpty) return null;
    return TextDocument.fromMap(maps.first);
  }

  @override
  Future<int> update(TextDocument text) async {
    final db = await getDatabase();
    final now = DateTime.now().toUtc();
    final coverImageId = text.coverImageId ??
        await BaseRepository.getOrCreateCoverImageId(db, text.coverImage);
    final result = await db.update(
      'texts',
      text.copyWith(coverImageId: coverImageId, updatedAt: now).toMap(),
      where: 'id = ?',
      whereArgs: [text.id],
    );
    notifyChange();
    return result;
  }

  @override
  Future<int> delete(String id) async {
    final db = await getDatabase();
    final result = await db.delete('texts', where: 'id = ?', whereArgs: [id]);
    if (result > 0) await BaseRepository.recordTombstone(db, 'text', id);
    notifyChange();
    return result;
  }

  @override
  Future<List<TextDocument>> search(String languageId, String query) async {
    final db = await getDatabase();
    final escaped = '%${BaseRepository.escapeLike(query)}%';
    final maps = await db.rawQuery(
      "$_select WHERE t.language_id = ? AND (t.title LIKE ? ESCAPE '\\' OR t.content LIKE ? ESCAPE '\\') ORDER BY t.last_read DESC LIMIT 50",
      [languageId, escaped, escaped],
    );
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }

  @override
  Future<int> getCountByLanguage(String languageId) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM texts WHERE language_id = ?',
      [languageId],
    );
    return result.first['count'] as int;
  }

  @override
  Future<int> getFinishedCount(String languageId) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM texts WHERE language_id = ? AND status = ?',
      [languageId, TextStatus.finished.value],
    );
    return result.first['count'] as int;
  }

  @override
  Future<int> getCountInCollection(String collectionId) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM texts WHERE collection_id = ?',
      [collectionId],
    );
    return result.first['count'] as int;
  }

  @override
  Future<void> moveToCollection(String textId, String? collectionId) async {
    final db = await getDatabase();
    await db.update(
      'texts',
      {
        'collection_id': collectionId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [textId],
    );
    notifyChange();
  }

  @override
  Future<void> batchCreate(List<TextDocument> texts) async {
    final db = await getDatabase();

    // Resolve cover_image_id for each unique path in one pass
    final uniquePaths = texts
        .map((t) => t.coverImage)
        .whereType<String>()
        .toSet();
    final pathToId = <String, String>{};
    for (final path in uniquePaths) {
      pathToId[path] = (await BaseRepository.getOrCreateCoverImageId(db, path))!;
    }

    final now = DateTime.now().toUtc();
    final batch = db.batch();
    for (final text in texts) {
      final id = text.id ?? _uuid.v4();
      final coverImageId = text.coverImage != null ? pathToId[text.coverImage] : null;
      batch.insert('texts', text.copyWith(id: id, coverImageId: coverImageId, updatedAt: now).toMap());
    }
    await batch.commit(noResult: true);
    notifyChange();
  }

  @override
  Future<List<TextDocument>> getByCollection(String collectionId) async {
    final db = await getDatabase();
    final maps = await db.rawQuery(
      '$_select WHERE t.collection_id = ? ORDER BY t.sort_order ASC, t.title ASC',
      [collectionId],
    );
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }

  @override
  Future<Map<String, int>> getCompletedCountsByDay(
    String languageId,
    String sinceIso,
  ) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      '''
      SELECT DATE(last_read) as date, COUNT(*) as cnt
      FROM texts
      WHERE language_id = ? AND status = 2 AND last_read >= ?
      GROUP BY DATE(last_read)
      ''',
      [languageId, sinceIso],
    );
    return {for (var row in result) row['date'] as String: row['cnt'] as int};
  }

  @override
  Future<List<TextDocument>> getRecentlyAdded(
    String languageId, {
    int limit = 5,
  }) async {
    final db = await getDatabase();
    final maps = await db.rawQuery(
      '$_select WHERE t.language_id = ? ORDER BY t.created_at DESC LIMIT ?',
      [languageId, limit],
    );
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }

  @override
  Future<List<TextDocument>> getRecentlyRead(
    String languageId, {
    int limit = 5,
  }) async {
    final db = await getDatabase();
    final maps = await db.rawQuery(
      '$_select WHERE t.language_id = ? AND t.status IN (1, 2) ORDER BY t.last_read DESC LIMIT ?',
      [languageId, limit],
    );
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }
}
