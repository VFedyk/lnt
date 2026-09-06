import '../../../domain/entities/language.dart';
import '../../../domain/repositories/review_card_repository.dart';
import '../../../domain/repositories/term_repository.dart';
import '../../../domain/repositories/term_sentence_repository.dart';
import '../../../domain/value_objects/review_scope.dart';
import '../../../services/text_parser_service.dart';

/// Number of cards a cloze session would actually serve — i.e. due cards whose
/// stored sentence contains the term at a word boundary. The old SQL `EXISTS`
/// count over-reported, because the screen silently drops every card it cannot
/// blank.
class CountClozeDue {
  CountClozeDue({
    required ReviewCardRepository reviewCards,
    required TermRepository terms,
    required TermSentenceRepository sentences,
  })  : _reviewCards = reviewCards,
        _terms = terms,
        _sentences = sentences;

  final ReviewCardRepository _reviewCards;
  final TermRepository _terms;
  final TermSentenceRepository _sentences;

  Future<int> call(
    Language language, {
    ReviewScope scope = const ReviewScope(),
  }) async {
    final candidates = await _reviewCards.getClozeDueCandidates(
      language.id!,
      scope: scope,
    );
    if (candidates.isEmpty) return 0;

    final termIds = candidates.map((c) => c.termId).toList();
    final termsById = await _terms.getByIds(termIds);
    final sentencesByTerm = await _sentences.getByTermIds(termIds);

    var count = 0;
    for (final rc in candidates) {
      final term = termsById[rc.termId];
      if (term == null || term.lowerText.isEmpty) continue;
      final sentences = sentencesByTerm[rc.termId] ?? const <String>[];
      final servable = sentences.any(
        (s) =>
            TextParserService.findOccurrence(
              s,
              term.lowerText,
              language: language,
            ) !=
            null,
      );
      if (servable) count++;
    }
    return count;
  }
}
