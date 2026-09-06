import '../../../domain/entities/term.dart';
import '../../../domain/entities/term_sentence.dart';
import '../../../domain/repositories/term_repository.dart';
import '../../../domain/repositories/term_sentence_repository.dart';
import '../../../domain/repositories/translation_repository.dart';

class SaveTerm {
  SaveTerm({
    required TermRepository terms,
    required TranslationRepository translations,
    required TermSentenceRepository sentences,
  })  : _terms = terms,
        _translations = translations,
        _sentences = sentences;

  final TermRepository _terms;
  final TranslationRepository _translations;
  final TermSentenceRepository _sentences;

  Future<String> call(
    Term term,
    List<Translation> translations, {
    required bool isNew,
    TermSentenceEdits sentences = TermSentenceEdits.empty,
  }) async {
    final String id;
    if (isNew) {
      id = await _terms.create(term);
      await _translations.replaceForTerm(id, translations);
    } else {
      await _terms.update(term);
      await _translations.replaceForTerm(term.id!, translations);
      id = term.id!;
    }

    if (!sentences.isEmpty) {
      for (final deletedId in sentences.deleted) {
        await _sentences.delete(deletedId);
      }
      for (final entry in sentences.edited.entries) {
        await _sentences.update(entry.key, entry.value);
      }
      for (final entry in sentences.added) {
        await _sentences.create(id, entry.text,
            sourceTextId: entry.sourceTextId);
      }
    }

    return id;
  }
}
