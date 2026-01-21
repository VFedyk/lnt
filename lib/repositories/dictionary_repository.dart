import '../models/dictionary.dart';
import 'base_repository.dart';

class DictionaryRepository extends BaseRepository {
  DictionaryRepository(super.getDatabase);

  Future<int> create(Dictionary dictionary) async {
    final db = await getDatabase();
    return await db.insert('dictionaries', dictionary.toMap());
  }

  Future<List<Dictionary>> getAll({
    int? languageId,
    bool activeOnly = false,
  }) async {
    final db = await getDatabase();
    String? where;
    List<dynamic>? whereArgs;

    if (languageId != null && activeOnly) {
      where = 'language_id = ? AND is_active = 1';
      whereArgs = [languageId];
    } else if (languageId != null) {
      where = 'language_id = ?';
      whereArgs = [languageId];
    } else if (activeOnly) {
      where = 'is_active = 1';
    }

    final maps = await db.query(
      'dictionaries',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'sort_order ASC, name ASC',
    );

    return maps.map((map) => Dictionary.fromMap(map)).toList();
  }

  Future<Dictionary?> getById(int id) async {
    final db = await getDatabase();
    final maps = await db.query(
      'dictionaries',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Dictionary.fromMap(maps.first);
  }

  Future<int> update(Dictionary dictionary) async {
    final db = await getDatabase();
    return await db.update(
      'dictionaries',
      dictionary.toMap(),
      where: 'id = ?',
      whereArgs: [dictionary.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await getDatabase();
    return await db.delete('dictionaries', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteByLanguage(int languageId) async {
    final db = await getDatabase();
    return await db.delete(
      'dictionaries',
      where: 'language_id = ?',
      whereArgs: [languageId],
    );
  }

  Future<void> reorder(List<Dictionary> dictionaries) async {
    final db = await getDatabase();
    final batch = db.batch();

    for (int i = 0; i < dictionaries.length; i++) {
      batch.update(
        'dictionaries',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [dictionaries[i].id],
      );
    }

    await batch.commit(noResult: true);
  }
}
