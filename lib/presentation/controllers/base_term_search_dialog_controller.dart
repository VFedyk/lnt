import '../../domain/entities/term.dart';
import '../../domain/value_objects/term_status.dart';
import '../../service_locator.dart';
import 'base_controller.dart';

class BaseTermSearchDialogController extends BaseController {
  final String languageId;
  final String? excludeTermId;

  List<Term> searchResults = [];
  Map<String, List<Translation>> translationsMap = {};
  bool isSearching = false;

  BaseTermSearchDialogController({
    required this.languageId,
    this.excludeTermId,
  });

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      searchResults = [];
      safeNotify();
      return;
    }

    isSearching = true;
    safeNotify();

    final results = await db.terms.search(languageId, query.trim());
    if (isDisposed) return;

    final lowerQuery = query.trim().toLowerCase();
    final filtered = results.where((t) => t.id != excludeTermId).toList();
    filtered.sort((a, b) {
      final aStarts = a.lowerText.startsWith(lowerQuery);
      final bStarts = b.lowerText.startsWith(lowerQuery);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return 0;
    });

    final termIds =
        filtered.where((t) => t.id != null).map((t) => t.id!).toList();
    final translations = termIds.isNotEmpty
        ? await db.translations.getByTermIds(termIds)
        : <String, List<Translation>>{};

    if (!isDisposed) {
      searchResults = filtered;
      translationsMap = translations;
      isSearching = false;
      safeNotify();
    }
  }

  /// Adds a translation to an existing term and reloads its translations.
  Future<void> addTranslationToTerm(Term term, Translation translation) async {
    if (term.id == null) return;
    final saved = translation.copyWith(termId: term.id!);
    await db.translations.create(saved);
    if (isDisposed) return;
    final updated = await db.translations.getByTermId(term.id!);
    if (!isDisposed) {
      translationsMap[term.id!] = updated;
      safeNotify();
    }
  }

  /// Creates a new base term and returns it (the returned term has a db-assigned id).
  Future<Term> createNewBaseTerm(String termText, {String translation = ''}) async {
    final newTerm = Term(
      languageId: languageId,
      text: termText,
      lowerText: termText,
      status: TermStatus.unknown,
      translation: translation,
    );
    final id = await db.terms.create(newTerm);
    return newTerm.copyWith(id: id);
  }
}
