import '../models/text_document.dart';
import 'base_repository.dart';

class TextRepository extends BaseRepository {
  TextRepository(super.getDatabase);

  Future<int> create(TextDocument text) async {
    final db = await getDatabase();
    return await db.insert('texts', text.toMap());
  }

  Future<List<TextDocument>> getAll({int? languageId}) async {
    final db = await getDatabase();
    final maps = languageId != null
        ? await db.query(
            'texts',
            where: 'language_id = ?',
            whereArgs: [languageId],
            orderBy: 'last_read DESC',
          )
        : await db.query('texts', orderBy: 'last_read DESC');
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }

  Future<TextDocument?> getById(int id) async {
    final db = await getDatabase();
    final maps = await db.query('texts', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return TextDocument.fromMap(maps.first);
  }

  Future<int> update(TextDocument text) async {
    final db = await getDatabase();
    return await db.update(
      'texts',
      text.toMap(),
      where: 'id = ?',
      whereArgs: [text.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await getDatabase();
    return await db.delete('texts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TextDocument>> search(int languageId, String query) async {
    final db = await getDatabase();
    final maps = await db.query(
      'texts',
      where: 'language_id = ? AND (title LIKE ? OR content LIKE ?)',
      whereArgs: [languageId, '%$query%', '%$query%'],
      orderBy: 'last_read DESC',
      limit: 50,
    );
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }

  Future<int> getCountByLanguage(int languageId) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM texts WHERE language_id = ?',
      [languageId],
    );
    return result.first['count'] as int;
  }

  Future<int> getCountInCollection(int collectionId) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM texts WHERE collection_id = ?',
      [collectionId],
    );
    return result.first['count'] as int;
  }

  Future<void> moveToCollection(int textId, int? collectionId) async {
    final db = await getDatabase();
    await db.update(
      'texts',
      {'collection_id': collectionId},
      where: 'id = ?',
      whereArgs: [textId],
    );
  }

  Future<void> batchCreate(List<TextDocument> texts) async {
    final db = await getDatabase();
    final batch = db.batch();
    for (final text in texts) {
      batch.insert('texts', text.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<TextDocument>> getByCollection(int collectionId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'texts',
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'sort_order ASC, title ASC',
    );
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }

  Future<Map<String, int>> getCompletedCountsByDay(int languageId, String sinceIso) async {
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

  Future<List<TextDocument>> getRecentlyAdded(int languageId, {int limit = 5}) async {
    final db = await getDatabase();
    final maps = await db.query(
      'texts',
      where: 'language_id = ?',
      whereArgs: [languageId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }

  Future<List<TextDocument>> getRecentlyRead(int languageId, {int limit = 5}) async {
    final db = await getDatabase();
    // Only return texts that are in progress (1) or finished (2)
    final maps = await db.query(
      'texts',
      where: 'language_id = ? AND status IN (1, 2)',
      whereArgs: [languageId],
      orderBy: 'last_read DESC',
      limit: limit,
    );
    return maps.map((map) => TextDocument.fromMap(map)).toList();
  }
}
