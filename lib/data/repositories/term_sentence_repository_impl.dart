import 'package:uuid/uuid.dart';
import '../../domain/entities/term_sentence.dart';
import '../../domain/repositories/term_sentence_repository.dart';
import 'base_repository.dart';

const _uuid = Uuid();

class TermSentenceRepositoryImpl extends BaseRepository
    implements TermSentenceRepository {
  TermSentenceRepositoryImpl(super.getDatabase, {super.onChange});

  @override
  Future<TermSentence> create(
    String termId,
    String sentence, {
    String? sourceTextId,
  }) async {
    final db = await getDatabase();
    final now = DateTime.now();
    final id = _uuid.v4();
    final row = TermSentence(
      id: id,
      termId: termId,
      sentence: sentence,
      sourceTextId: sourceTextId,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('term_sentences', row.toMap());
    notifyChange();
    return row;
  }

  @override
  Future<void> update(String id, String sentence) async {
    final db = await getDatabase();
    await db.update(
      'term_sentences',
      {
        'sentence': sentence,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    notifyChange();
  }

  @override
  Future<List<TermSentence>> getByTermId(String termId) async {
    final db = await getDatabase();
    final rows = await db.query(
      'term_sentences',
      where: 'term_id = ?',
      whereArgs: [termId],
      orderBy: 'created_at ASC',
    );
    return rows.map(TermSentence.fromMap).toList();
  }

  @override
  Future<Map<String, List<String>>> getByTermIds(List<String> termIds) async {
    if (termIds.isEmpty) return {};

    final db = await getDatabase();
    final placeholders = List.filled(termIds.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT term_id, sentence FROM term_sentences WHERE term_id IN ($placeholders) ORDER BY created_at ASC',
      termIds,
    );

    final result = <String, List<String>>{};
    for (final row in rows) {
      final termId = row['term_id'] as String;
      final sentence = row['sentence'] as String;
      (result[termId] ??= []).add(sentence);
    }
    return result;
  }

  @override
  Future<bool> existsForTerm(String termId, String sentence) async {
    final db = await getDatabase();
    final rows = await db.rawQuery(
      'SELECT 1 FROM term_sentences '
      'WHERE term_id = ? AND TRIM(LOWER(sentence)) = ? LIMIT 1',
      [termId, sentence.trim().toLowerCase()],
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> delete(String id) async {
    final db = await getDatabase();
    final count = await db.delete(
      'term_sentences',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count > 0) {
      await BaseRepository.recordTombstone(db, 'term_sentence', id);
      notifyChange();
    }
  }
}
