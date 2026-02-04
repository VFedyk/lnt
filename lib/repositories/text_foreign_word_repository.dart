import 'base_repository.dart';

/// Record representing a stored foreign word assignment
typedef ForeignWordRecord = ({String lowerText, int languageId, int? termId});

class TextForeignWordRepository extends BaseRepository {
  TextForeignWordRepository(super.getDatabase);

  /// Save words as foreign for a given text + language.
  /// Uses INSERT OR REPLACE so re-assigning a word updates its language/term.
  Future<void> saveWords(
    int textId,
    int languageId,
    Map<String, int?> wordsWithTermIds,
  ) async {
    if (wordsWithTermIds.isEmpty) return;
    final db = await getDatabase();
    await db.transaction((txn) async {
      for (final entry in wordsWithTermIds.entries) {
        await txn.rawInsert(
          '''
          INSERT OR REPLACE INTO text_foreign_words
            (text_id, lower_text, language_id, term_id)
          VALUES (?, ?, ?, ?)
          ''',
          [textId, entry.key, languageId, entry.value],
        );
      }
    });
  }

  /// Load all foreign word assignments for a text.
  Future<List<ForeignWordRecord>> getByTextId(int textId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'text_foreign_words',
      where: 'text_id = ?',
      whereArgs: [textId],
    );
    return maps
        .map((m) => (
              lowerText: m['lower_text'] as String,
              languageId: m['language_id'] as int,
              termId: m['term_id'] as int?,
            ))
        .toList();
  }

  /// Delete a single foreign word assignment.
  Future<int> deleteWord(int textId, String lowerText) async {
    final db = await getDatabase();
    return db.delete(
      'text_foreign_words',
      where: 'text_id = ? AND lower_text = ?',
      whereArgs: [textId, lowerText],
    );
  }

  /// Delete multiple foreign word assignments.
  Future<int> deleteWords(int textId, List<String> lowerTexts) async {
    if (lowerTexts.isEmpty) return 0;
    final db = await getDatabase();
    final placeholders = List.filled(lowerTexts.length, '?').join(',');
    return db.delete(
      'text_foreign_words',
      where: 'text_id = ? AND lower_text IN ($placeholders)',
      whereArgs: [textId, ...lowerTexts],
    );
  }
}
