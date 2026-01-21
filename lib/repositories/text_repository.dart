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
}
