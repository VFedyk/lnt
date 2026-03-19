import '../models/term_sentence.dart';
import 'base_repository.dart';

class TermSentenceRepository extends BaseRepository {
  TermSentenceRepository(super.getDatabase, {super.onChange});

  Future<TermSentence> create(
    int termId,
    String sentence, {
    int? sourceTextId,
  }) async {
    final db = await getDatabase();
    final now = DateTime.now();
    final row = TermSentence(
      termId: termId,
      sentence: sentence,
      sourceTextId: sourceTextId,
      createdAt: now,
    );
    final id = await db.insert('term_sentences', row.toMap());
    notifyChange();
    return TermSentence(
      id: id,
      termId: termId,
      sentence: sentence,
      sourceTextId: sourceTextId,
      createdAt: now,
    );
  }

  Future<List<TermSentence>> getByTermId(int termId) async {
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
  Future<Map<int, List<String>>> getByTermIds(List<int> termIds) async {
    if (termIds.isEmpty) return {};

    final db = await getDatabase();
    final placeholders = List.filled(termIds.length, '?').join(',');
    final rows = await db.rawQuery(
      'SELECT term_id, sentence FROM term_sentences WHERE term_id IN ($placeholders) ORDER BY created_at ASC',
      termIds,
    );

    final result = <int, List<String>>{};
    for (final row in rows) {
      final termId = row['term_id'] as int;
      final sentence = row['sentence'] as String;
      (result[termId] ??= []).add(sentence);
    }
    return result;
  }

  Future<void> delete(int id) async {
    final db = await getDatabase();
    await db.delete('term_sentences', where: 'id = ?', whereArgs: [id]);
    notifyChange();
  }
}
