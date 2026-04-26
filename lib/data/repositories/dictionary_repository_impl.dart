import 'package:uuid/uuid.dart';
import '../../domain/entities/dictionary.dart';
import '../../domain/repositories/dictionary_repository.dart';
import 'base_repository.dart';

const _uuid = Uuid();

class DictionaryRepositoryImpl extends BaseRepository
    implements DictionaryRepository {
  DictionaryRepositoryImpl(super.getDatabase, {super.onChange});

  @override
  Future<String> create(Dictionary dictionary) async {
    final db = await getDatabase();
    final id = dictionary.id ?? _uuid.v4();
    await db.insert('dictionaries', dictionary.copyWith(id: id).toMap());
    notifyChange();
    return id;
  }

  @override
  Future<List<Dictionary>> getAll({
    String? languageId,
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

  @override
  Future<Dictionary?> getById(String id) async {
    final db = await getDatabase();
    final maps = await db.query(
      'dictionaries',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Dictionary.fromMap(maps.first);
  }

  @override
  Future<int> update(Dictionary dictionary) async {
    final db = await getDatabase();
    final count = await db.update(
      'dictionaries',
      dictionary.toMap(),
      where: 'id = ?',
      whereArgs: [dictionary.id],
    );
    notifyChange();
    return count;
  }

  @override
  Future<int> delete(String id) async {
    final db = await getDatabase();
    final count = await db.delete('dictionaries', where: 'id = ?', whereArgs: [id]);
    notifyChange();
    return count;
  }

  @override
  Future<int> deleteByLanguage(String languageId) async {
    final db = await getDatabase();
    final count = await db.delete(
      'dictionaries',
      where: 'language_id = ?',
      whereArgs: [languageId],
    );
    notifyChange();
    return count;
  }

  @override
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
    notifyChange();
  }
}
