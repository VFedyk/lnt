import 'package:sqflite/sqflite.dart';
import '../models/term.dart';
import 'base_repository.dart';

class TranslationRepository extends BaseRepository {
  TranslationRepository(super.getDatabase);

  Future<int> create(Translation translation) async {
    final db = await getDatabase();
    return await db.insert(
      'translations',
      translation.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Translation>> getByTermId(int termId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'translations',
      where: 'term_id = ?',
      whereArgs: [termId],
      orderBy: 'sort_order ASC',
    );
    return maps.map((map) => Translation.fromMap(map)).toList();
  }

  Future<Translation?> getById(int id) async {
    final db = await getDatabase();
    final maps = await db.query(
      'translations',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Translation.fromMap(maps.first);
  }

  Future<int> update(Translation translation) async {
    final db = await getDatabase();
    return await db.update(
      'translations',
      translation.toMap(),
      where: 'id = ?',
      whereArgs: [translation.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await getDatabase();
    return await db.delete('translations', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteByTermId(int termId) async {
    final db = await getDatabase();
    return await db.delete(
      'translations',
      where: 'term_id = ?',
      whereArgs: [termId],
    );
  }

  /// Get all translations for multiple terms at once (for batch loading)
  Future<Map<int, List<Translation>>> getByTermIds(List<int> termIds) async {
    if (termIds.isEmpty) return {};

    final db = await getDatabase();
    final result = <int, List<Translation>>{};
    const batchSize = 500;

    for (var i = 0; i < termIds.length; i += batchSize) {
      final batch = termIds.skip(i).take(batchSize).toList();
      final placeholders = List.filled(batch.length, '?').join(',');
      final maps = await db.rawQuery(
        'SELECT * FROM translations WHERE term_id IN ($placeholders) ORDER BY sort_order ASC',
        batch,
      );
      for (final map in maps) {
        final termId = map['term_id'] as int;
        result.putIfAbsent(termId, () => []).add(Translation.fromMap(map));
      }
    }
    return result;
  }

  /// Replace all translations for a term (delete existing, insert new)
  Future<void> replaceForTerm(int termId, List<Translation> translations) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      await txn.delete('translations', where: 'term_id = ?', whereArgs: [termId]);
      for (var i = 0; i < translations.length; i++) {
        final t = translations[i].copyWith(termId: termId, sortOrder: i);
        await txn.insert('translations', t.toMap());
      }
    });
  }
}
