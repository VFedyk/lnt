import '../entities/text_foreign_word_record.dart';

abstract class TextForeignWordRepository {
  Future<void> saveWords(String textId, String languageId, Map<String, String?> wordsWithTermIds);
  Future<List<ForeignWordRecord>> getByTextId(String textId);
  Future<int> deleteWord(String textId, String lowerText);
  Future<int> deleteWords(String textId, List<String> lowerTexts);
}
