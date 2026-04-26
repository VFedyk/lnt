import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/term.dart';
import '../domain/events/term_event.dart';
import '../services/data_change_notifier.dart';
import 'base_repository.dart';

const _uuid = Uuid();

class TermRepository extends BaseRepository {
  final EventStream<TermEvent>? termEvents;

  TermRepository(super.getDatabase, {super.onChange, this.termEvents});

  Future<String> create(Term term) async {
    final db = await getDatabase();
    final id = term.id ?? _uuid.v4();
    await db.insert(
      'terms',
      term.copyWith(id: id).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyChange();
    termEvents?.emit(TermWritten(id, term.status));
    return id;
  }

  Future<List<Term>> getAll({String? languageId, int? status}) async {
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

  Future<Term?> getByText(String languageId, String text) async {
    final db = await getDatabase();
    final maps = await db.query(
      'terms',
      where: 'language_id = ? AND lower_text = ?',
      whereArgs: [languageId, text.toLowerCase()],
    );
    if (maps.isEmpty) return null;
    return Term.fromMap(maps.first);
  }

  Future<Term?> getById(String id) async {
    final db = await getDatabase();
    final maps = await db.query(
      'terms',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Term.fromMap(maps.first);
  }

  Future<List<Term>> getLinkedTerms(String baseTermId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'terms',
      where: 'base_term_id = ?',
      whereArgs: [baseTermId],
      orderBy: 'lower_text ASC',
    );
    return maps.map((map) => Term.fromMap(map)).toList();
  }

  Future<Map<String, Term>> getMapByLanguage(String languageId) async {
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

  Future<Map<String, Term>> getByIds(List<String> ids) async {
    if (ids.isEmpty) return {};

    final db = await getDatabase();
    final result = <String, Term>{};
    const batchSize = 500;

    for (var i = 0; i < ids.length; i += batchSize) {
      final batch = ids.skip(i).take(batchSize).toList();
      final placeholders = List.filled(batch.length, '?').join(',');
      final maps = await db.rawQuery(
        'SELECT * FROM terms WHERE id IN ($placeholders)',
        batch,
      );
      for (final map in maps) {
        final term = Term.fromMap(map);
        result[term.id!] = term;
      }
    }
    return result;
  }

  Future<int> update(Term term) async {
    final db = await getDatabase();
    final result = await db.update(
      'terms',
      term.toMap(),
      where: 'id = ?',
      whereArgs: [term.id],
    );
    notifyChange();
    termEvents?.emit(TermWritten(term.id!, term.status));
    return result;
  }

  Future<int> delete(String id) async {
    final db = await getDatabase();
    final result = await db.delete('terms', where: 'id = ?', whereArgs: [id]);
    notifyChange();
    return result;
  }

  Future<int> deleteByLanguage(String languageId) async {
    final db = await getDatabase();
    final result = await db.delete(
      'terms',
      where: 'language_id = ?',
      whereArgs: [languageId],
    );
    notifyChange();
    return result;
  }

  Future<Map<int, int>> getCountsByStatus(String languageId) async {
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

  Future<int> getTotalCount(String languageId) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM terms WHERE language_id = ?',
      [languageId],
    );
    return result.first['count'] as int;
  }

  Future<void> bulkCreate(List<Term> terms) async {
    if (terms.isEmpty) return;
    final db = await getDatabase();
    final batch = db.batch();
    final written = <({String id, int status})>[];
    for (final term in terms) {
      final id = term.id ?? _uuid.v4();
      batch.insert('terms', term.copyWith(id: id).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      written.add((id: id, status: term.status));
    }
    await batch.commit(noResult: true);
    notifyChange();
    if (written.isNotEmpty) termEvents?.emit(TermsBulkWritten(written));
  }

  Future<void> bulkUpdateStatus(List<String> termIds, int newStatus) async {
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
    notifyChange();
    if (termIds.isNotEmpty) {
      termEvents?.emit(TermsBulkWritten(
        termIds.map((id) => (id: id, status: newStatus)).toList(),
      ));
    }
  }

  Future<Map<String, int>> getCreatedCountsByDay(String languageId, String sinceIso) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      '''
      SELECT DATE(created_at) as date, COUNT(*) as cnt
      FROM terms
      WHERE language_id = ? AND created_at >= ?
      GROUP BY DATE(created_at)
      ''',
      [languageId, sinceIso],
    );
    return {for (var row in result) row['date'] as String: row['cnt'] as int};
  }

  Future<List<Term>> search(String languageId, String query) async {
    final db = await getDatabase();
    final escaped = '%${BaseRepository.escapeLike(query)}%';
    final maps = await db.rawQuery(
      r"""
      SELECT DISTINCT t.* FROM terms t
      LEFT JOIN translations tr ON tr.term_id = t.id
      WHERE t.language_id = ? AND (t.text LIKE ? ESCAPE '\' OR t.translation LIKE ? ESCAPE '\' OR tr.meaning LIKE ? ESCAPE '\')
      ORDER BY t.last_accessed DESC
      LIMIT 100
      """,
      [languageId, escaped, escaped, escaped],
    );
    return maps.map((map) => Term.fromMap(map)).toList();
  }
}
