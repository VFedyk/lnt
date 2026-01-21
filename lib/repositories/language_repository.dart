import '../models/language.dart';
import 'base_repository.dart';

class LanguageRepository extends BaseRepository {
  LanguageRepository(super.getDatabase);

  Future<int> create(Language language) async {
    final db = await getDatabase();
    return await db.insert('languages', language.toMap());
  }

  Future<List<Language>> getAll() async {
    final db = await getDatabase();
    final maps = await db.query('languages', orderBy: 'name ASC');
    return maps.map((map) => Language.fromMap(map)).toList();
  }

  Future<Language?> getById(int id) async {
    final db = await getDatabase();
    final maps = await db.query('languages', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Language.fromMap(maps.first);
  }

  Future<int> update(Language language) async {
    final db = await getDatabase();
    return await db.update(
      'languages',
      language.toMap(),
      where: 'id = ?',
      whereArgs: [language.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await getDatabase();
    return await db.delete('languages', where: 'id = ?', whereArgs: [id]);
  }
}
