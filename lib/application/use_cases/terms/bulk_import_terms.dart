import 'package:uuid/uuid.dart';

import '../../../domain/entities/term.dart';
import '../../../domain/repositories/term_repository.dart';
import '../../../domain/repositories/term_sentence_repository.dart';

const _uuid = Uuid();

class BulkImportTerms {
  BulkImportTerms({
    required TermRepository terms,
    required TermSentenceRepository sentences,
  })  : _terms = terms,
        _sentences = sentences;

  final TermRepository _terms;
  final TermSentenceRepository _sentences;

  /// Creates [terms] and, for any term carrying a non-empty [Term.sentence],
  /// a matching `term_sentences` row (the legacy `terms.sentence` column is no
  /// longer a read source). Ids are assigned here so the sentence rows can
  /// reference their parent term.
  Future<void> call(List<Term> terms) async {
    if (terms.isEmpty) return;

    final withIds = [
      for (final t in terms) t.copyWith(id: t.id ?? _uuid.v4(), sentence: ''),
    ];
    await _terms.bulkCreate(withIds);

    for (var i = 0; i < terms.length; i++) {
      final sentence = terms[i].sentence.trim();
      if (sentence.isEmpty) continue;
      await _sentences.create(withIds[i].id!, sentence);
    }
  }
}
