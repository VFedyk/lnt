import '../../domain/entities/text_foreign_word_record.dart';
import '../../domain/repositories/text_foreign_word_repository.dart';
import 'base_repository.dart';

class TextForeignWordRepositoryImpl extends BaseRepository
    implements TextForeignWordRepository {
  TextForeignWordRepositoryImpl(super.getDatabase);

  @override
  Future<void> saveWords(
    String textId,
    String languageId,
    Map<String, String?> wordsWithTermIds,
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

  @override
  Future<List<ForeignWordRecord>> getByTextId(String textId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'text_foreign_words',
      where: 'text_id = ?',
      whereArgs: [textId],
    );
    return maps
        .map((m) => (
              lowerText: m['lower_text'] as String,
              languageId: m['language_id'] as String,
              termId: m['term_id'] as String?,
            ))
        .toList();
  }

  @override
  Future<int> deleteWord(String textId, String lowerText) async {
    final db = await getDatabase();
    return db.delete(
      'text_foreign_words',
      where: 'text_id = ? AND lower_text = ?',
      whereArgs: [textId, lowerText],
    );
  }

  @override
  Future<int> deleteWords(String textId, List<String> lowerTexts) async {
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
