import 'package:sqflite/sqflite.dart';
import '../models/term.dart';
import 'base_repository.dart';

class TermRepository extends BaseRepository {
  TermRepository(super.getDatabase);

  Future<int> create(Term term) async {
    final db = await getDatabase();
    return await db.insert(
      'terms',
      term.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Term>> getAll({int? languageId, int? status}) async {
    final db = await getDatabase();
    String? where;
    List<dynamic>? whereArgs;

    if (languageId != null && status != null) {
      where = 'language_id = ? AND status = ?';
      whereArgs = [languageId, status];
    } else if (languageId != null) {
      where = 'language_id = ?';
      whereArgs = [languageId];
    } else if (status != null) {
      where = 'status = ?';
      whereArgs = [status];
    }

    final maps = await db.query(
      'terms',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'last_accessed DESC',
    );
    return maps.map((map) => Term.fromMap(map)).toList();
  }

  Future<Term?> getByText(int languageId, String text) async {
    final db = await getDatabase();
    final maps = await db.query(
      'terms',
      where: 'language_id = ? AND lower_text = ?',
      whereArgs: [languageId, text.toLowerCase()],
    );
    if (maps.isEmpty) return null;
    return Term.fromMap(maps.first);
  }

  Future<Term?> getById(int id) async {
    final db = await getDatabase();
    final maps = await db.query(
      'terms',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Term.fromMap(maps.first);
  }

  Future<List<Term>> getLinkedTerms(int baseTermId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'terms',
      where: 'base_term_id = ?',
      whereArgs: [baseTermId],
      orderBy: 'lower_text ASC',
    );
    return maps.map((map) => Term.fromMap(map)).toList();
  }

  Future<Map<String, Term>> getMapByLanguage(int languageId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'terms',
      where: 'language_id = ?',
      whereArgs: [languageId],
    );
    return {
      for (var map in maps) (map['lower_text'] as String): Term.fromMap(map),
    };
  }

  Future<int> update(Term term) async {
    final db = await getDatabase();
    return await db.update(
      'terms',
      term.toMap(),
      where: 'id = ?',
      whereArgs: [term.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await getDatabase();
    return await db.delete('terms', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteByLanguage(int languageId) async {
    final db = await getDatabase();
    return await db.delete(
      'terms',
      where: 'language_id = ?',
      whereArgs: [languageId],
    );
  }

  Future<Map<int, int>> getCountsByStatus(int languageId) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      '''
      SELECT status, COUNT(*) as count
      FROM terms
      WHERE language_id = ?
      GROUP BY status
      ''',
      [languageId],
    );
    return {for (var row in result) row['status'] as int: row['count'] as int};
  }

  Future<int> getTotalCount(int languageId) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM terms WHERE language_id = ?',
      [languageId],
    );
    return result.first['count'] as int;
  }

  Future<void> bulkUpdateStatus(List<int> termIds, int newStatus) async {
    final db = await getDatabase();
    final batch = db.batch();
    for (final id in termIds) {
      batch.update(
        'terms',
        {
          'status': newStatus,
          'last_accessed': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<Term>> search(int languageId, String query) async {
    final db = await getDatabase();
    final maps = await db.query(
      'terms',
      where: 'language_id = ? AND (text LIKE ? OR translation LIKE ?)',
      whereArgs: [languageId, '%$query%', '%$query%'],
      orderBy: 'last_accessed DESC',
      limit: 100,
    );
    return maps.map((map) => Term.fromMap(map)).toList();
  }
}
