import 'dart:developer' as developer;

import '../../../domain/entities/language.dart';
import '../../../domain/entities/term.dart';
import '../../../domain/entities/text_document.dart';
import '../../../domain/repositories/term_repository.dart';
import '../../../domain/value_objects/review_scope.dart';
import '../../../services/text_word_index_service.dart';

/// Resolves the review scope for a single text.
///
/// The word index covers single-form terms; multi-word terms cannot be
/// represented there (the index is a plain, term-independent tokenization), so
/// they are matched against the raw content and passed as explicit extras.
class ResolveTextTerms {
  ResolveTextTerms({
    required TextWordIndexService index,
    required TermRepository terms,
  })  : _index = index,
        _terms = terms;

  final TextWordIndexService _index;
  final TermRepository _terms;

  /// Keeps the extras list well inside SQLite's host-parameter limit.
  static const int maxExtraTermIds = 400;

  Future<ReviewScope> call(
    TextDocument text,
    Language language, {
    List<int>? statuses,
    bool includeNotDue = false,
    Iterable<Term>? knownMultiWordTerms,
  }) async {
    await _index.ensureIndexed(text, language);

    final extras = knownMultiWordTerms != null
        ? knownMultiWordTerms
            .where((t) => t.id != null)
            .map((t) => t.id!)
            .toSet()
            .toList()
        : await _scanMultiWordTerms(text, language);

    if (extras.length > maxExtraTermIds) {
      developer.log(
        'ResolveTextTerms: ${extras.length} multi-word terms in '
        '"${text.title}" — truncating to $maxExtraTermIds',
      );
    }

    return ReviewScope(
      statuses: statuses,
      textId: text.id,
      extraTermIds: extras.take(maxExtraTermIds).toList(),
      includeNotDue: includeNotDue,
    );
  }

  /// Terms whose form spans more than one index token and that literally occur
  /// in the text. One pass over the language's terms; only the multi-word ones
  /// touch the content.
  Future<List<String>> _scanMultiWordTerms(
    TextDocument text,
    Language language,
  ) async {
    final languageId = language.id;
    if (languageId == null) return const [];

    final termsMap = await _terms.getMapByLanguage(languageId);
    final lowerContent = text.content.toLowerCase();
    final result = <String>[];

    for (final entry in termsMap.entries) {
      final key = entry.key;
      final isMultiWord = key.contains(' ') ||
          (language.splitByCharacter &&
              !language.useWordSegmentation &&
              key.length > 1);
      if (!isMultiWord) continue;

      final id = entry.value.id;
      if (id == null) continue;
      if (lowerContent.contains(key)) result.add(id);
    }

    return result;
  }
}
