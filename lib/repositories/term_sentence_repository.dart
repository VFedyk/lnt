import 'package:uuid/uuid.dart';
import '../models/term_sentence.dart';
import 'base_repository.dart';

const _uuid = Uuid();

class TermSentenceRepository extends BaseRepository {
  TermSentenceRepository(super.getDatabase, {super.onChange});

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
    );
    await db.insert('term_sentences', row.toMap());
    notifyChange();
    return row;
  }

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

  /// Returns a map of termId → list of sentence strings for batch loading.
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

  Future<void> delete(String id) async {
    final db = await getDatabase();
    await db.delete('term_sentences', where: 'id = ?', whereArgs: [id]);
    notifyChange();
  }
}
