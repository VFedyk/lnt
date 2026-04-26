import '../../../domain/entities/term.dart';
import '../../../domain/repositories/term_repository.dart';
import '../../../domain/repositories/translation_repository.dart';

class SaveTerm {
  SaveTerm({
    required TermRepository terms,
    required TranslationRepository translations,
  })  : _terms = terms,
        _translations = translations;

  final TermRepository _terms;
  final TranslationRepository _translations;

  Future<String> call(
    Term term,
    List<Translation> translations, {
    required bool isNew,
  }) async {
    if (isNew) {
      final id = await _terms.create(term);
      await _translations.replaceForTerm(id, translations);
      return id;
    } else {
      await _terms.update(term);
      await _translations.replaceForTerm(term.id!, translations);
      return term.id!;
    }
  }
}
