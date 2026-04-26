import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/term.dart';
import 'base_repository.dart';

const _uuid = Uuid();

class TranslationRepository extends BaseRepository {
  TranslationRepository(super.getDatabase, {super.onChange});

  Future<String> create(Translation translation) async {
    final db = await getDatabase();
    final id = translation.id ?? _uuid.v4();
    await db.insert(
      'translations',
      translation.copyWith(id: id).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChange();
    return id;
  }

  Future<List<Translation>> getByTermId(String termId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'translations',
      where: 'term_id = ?',
      whereArgs: [termId],
      orderBy: 'sort_order ASC',
    );
    return maps.map((map) => Translation.fromMap(map)).toList();
  }

  Future<Translation?> getById(String id) async {
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
    final count = await db.update(
      'translations',
      translation.toMap(),
      where: 'id = ?',
      whereArgs: [translation.id],
    );
    notifyChange();
    return count;
  }

  Future<int> delete(String id) async {
    final db = await getDatabase();
    final count = await db.delete('translations', where: 'id = ?', whereArgs: [id]);
    notifyChange();
    return count;
  }

  Future<int> deleteByTermId(String termId) async {
    final db = await getDatabase();
    final count = await db.delete(
      'translations',
      where: 'term_id = ?',
      whereArgs: [termId],
    );
    notifyChange();
    return count;
  }

  /// Get all translations for multiple terms at once (for batch loading)
  Future<Map<String, List<Translation>>> getByTermIds(List<String> termIds) async {
    if (termIds.isEmpty) return {};

    final db = await getDatabase();
    final result = <String, List<Translation>>{};
    const batchSize = 500;

    for (var i = 0; i < termIds.length; i += batchSize) {
      final batch = termIds.skip(i).take(batchSize).toList();
      final placeholders = List.filled(batch.length, '?').join(',');
      final maps = await db.rawQuery(
        'SELECT * FROM translations WHERE term_id IN ($placeholders) ORDER BY sort_order ASC',
        batch,
      );
      for (final map in maps) {
        final termId = map['term_id'] as String;
        result.putIfAbsent(termId, () => []).add(Translation.fromMap(map));
      }
    }
    return result;
  }

  /// Update translations for a term, preserving IDs where possible
  /// to maintain baseTranslationId references from other translations
  Future<void> replaceForTerm(String termId, List<Translation> translations) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      // Get existing translation IDs for this term
      final existingMaps = await txn.query(
        'translations',
        columns: ['id'],
        where: 'term_id = ?',
        whereArgs: [termId],
      );
      final existingIds = existingMaps.map((m) => m['id'] as String).toSet();

      // Track which existing IDs we're keeping
      final keptIds = <String>{};

      for (var i = 0; i < translations.length; i++) {
        final t = translations[i].copyWith(termId: termId, sortOrder: i);
        final map = t.toMap();

        if (t.id != null && existingIds.contains(t.id)) {
          // Update existing translation (preserves ID for baseTranslationId refs)
          await txn.update('translations', map, where: 'id = ?', whereArgs: [t.id]);
          keptIds.add(t.id!);
        } else {
          // Insert new translation with a new UUID
          final newId = _uuid.v4();
          map['id'] = newId;
          await txn.insert('translations', map);
        }
      }

      // Delete translations that were removed
      final toDelete = existingIds.difference(keptIds);
      for (final id in toDelete) {
        await txn.delete('translations', where: 'id = ?', whereArgs: [id]);
      }
    });
    notifyChange();
  }
}
