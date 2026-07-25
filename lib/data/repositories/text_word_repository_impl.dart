import 'package:sqflite/sqflite.dart';

import '../../domain/repositories/text_word_repository.dart';
import 'base_repository.dart';

class TextWordRepositoryImpl extends BaseRepository
    implements TextWordRepository {
  TextWordRepositoryImpl(super.getDatabase);

  @override
  Future<void> replaceIndex(
    String textId,
    String contentHash,
    Map<String, ({int occurrences, int firstPosition})> words,
  ) async {
    final db = await getDatabase();
    await db.transaction((txn) async {
      await txn.delete('text_words', where: 'text_id = ?', whereArgs: [textId]);
      final batch = txn.batch();
      for (final e in words.entries) {
        batch.insert('text_words', {
          'text_id': textId,
          'lower_text': e.key,
          'occurrences': e.value.occurrences,
          'first_position': e.value.firstPosition,
        });
      }
      await batch.commit(noResult: true);
      // Safe here: text_word_index has no children, so REPLACE cannot cascade
      // anything away. Never use it on text_words.
      await txn.insert(
        'text_word_index',
        {
          'text_id': textId,
          'content_hash': contentHash,
          'word_count': words.length,
          'indexed_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<String?> indexedHash(String textId) async {
    final db = await getDatabase();
    final rows = await db.query(
      'text_word_index',
      columns: ['content_hash'],
      where: 'text_id = ?',
      whereArgs: [textId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['content_hash'] as String?;
  }

  @override
  Future<void> invalidate(String textId) async {
    final db = await getDatabase();
    await db.delete(
      'text_word_index',
      where: 'text_id = ?',
      whereArgs: [textId],
    );
  }

  @override
  Future<List<String>> termIdsInText(String textId, String languageId) async {
    final db = await getDatabase();
    final rows = await db.rawQuery(
      '''
      SELECT t.id
      FROM text_words tw
      INNER JOIN terms t
              ON t.lower_text = tw.lower_text
             AND t.language_id = ?
      WHERE tw.text_id = ?
      ''',
      [languageId, textId],
    );
    return rows.map((r) => r['id'] as String).toList();
  }

  @override
  Future<List<({String textId, String title, int hits})>> textsContainingTerms(
    String languageId,
    List<String> termIds, {
    int minHits = 2,
    int limit = 3,
  }) async {
    if (termIds.isEmpty) return const [];
    final db = await getDatabase();
    final placeholders = List.filled(termIds.length, '?').join(', ');
    final rows = await db.rawQuery(
      '''
      SELECT tx.id AS text_id, tx.title AS title,
             COUNT(DISTINCT tw.lower_text) AS hits
      FROM text_words tw
      INNER JOIN texts tx ON tx.id = tw.text_id
      INNER JOIN terms t  ON t.lower_text = tw.lower_text
                         AND t.language_id = tx.language_id
      WHERE tx.language_id = ?
        AND t.id IN ($placeholders)
      GROUP BY tx.id
      HAVING hits >= ?
      ORDER BY (tx.status != 0) DESC, hits DESC, tx.last_read DESC
      LIMIT ?
      ''',
      [languageId, ...termIds, minHits, limit],
    );
    return rows
        .map((r) => (
              textId: r['text_id'] as String,
              title: (r['title'] as String?) ?? '',
              hits: (r['hits'] as int?) ?? 0,
            ))
        .toList();
  }
}
