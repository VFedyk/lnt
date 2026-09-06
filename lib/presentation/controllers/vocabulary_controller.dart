import 'dart:io';

import '../../domain/entities/dictionary.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/term.dart';
import '../../service_locator.dart';
import '../../services/dictionary_service.dart';
import '../../services/import_export_service.dart';
import '../../utils/constants.dart';
import 'base_controller.dart';

class VocabularyController extends BaseController {
  final Language language;

  final _dictService = DictionaryService();
  final _importService = ImportExportService();

  List<Term> terms = [];
  List<Term> filteredTerms = [];
  Map<String, List<Translation>> translationsMap = {};
  bool isLoading = true;
  bool _loadInProgress = false;
  bool _pendingReload = false;

  List<Dictionary> dictionaries = [];
  int? statusFilter;
  bool hideIgnored = true;
  int? sortColumnIndex;
  bool sortAscending = true;
  Map<int, int> statusCounts = {};

  String _searchQuery = '';

  VocabularyController({required this.language}) {
    dataChanges.terms.addListener(_onDataChanged);
    loadTerms();
    loadDictionaries();
  }

  void _onDataChanged() {
    if (!isDisposed) loadTerms();
  }

  @override
  void dispose() {
    dataChanges.terms.removeListener(_onDataChanged);
    super.dispose();
  }

  Future<void> loadDictionaries() async {
    final dicts = await _dictService.getActiveDictionaries(language.id!);
    if (!isDisposed) {
      dictionaries = dicts;
      safeNotify();
    }
  }

  Future<void> loadTerms() async {
    if (_loadInProgress) {
      _pendingReload = true;
      return;
    }
    _loadInProgress = true;
    _pendingReload = false;

    if (terms.isEmpty) {
      isLoading = true;
      safeNotify();
    }

    try {
      final loaded = await db.terms.getAll(languageId: language.id!);
      final termIds = loaded.where((t) => t.id != null).map((t) => t.id!).toList();
      final loadedTranslations = await db.translations.getByTermIds(termIds);

      if (!isDisposed) {
        terms = loaded;
        translationsMap = loadedTranslations;
        _applyFiltersInternal();
        isLoading = false;
        safeNotify();
      }
    } finally {
      _loadInProgress = false;
      if (_pendingReload && !isDisposed) {
        loadTerms();
      }
    }
  }

  void applyFilters(String searchQuery) {
    _searchQuery = searchQuery;
    _applyFiltersInternal();
    safeNotify();
  }

  void _applyFiltersInternal() {
    var filtered = terms;

    if (hideIgnored && statusFilter == null) {
      filtered = filtered.where((t) => t.status != AppConstants.statusIgnored).toList();
    }
    if (statusFilter != null) {
      filtered = filtered.where((t) => t.status == statusFilter).toList();
    }

    final query = _searchQuery.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered
          .where(
            (t) =>
                t.text.toLowerCase().contains(query) ||
                t.translation.toLowerCase().contains(query) ||
                _translationsContainQuery(t.id, query),
          )
          .toList();
    }

    filteredTerms = filtered;
    _updateStatusCounts();
  }

  void _updateStatusCounts() {
    statusCounts = {};
    for (final term in terms) {
      statusCounts[term.status] = (statusCounts[term.status] ?? 0) + 1;
    }
  }

  bool _translationsContainQuery(String? termId, String query) {
    if (termId == null) return false;
    final translations = translationsMap[termId];
    if (translations == null) return false;
    return translations.any((t) => t.meaning.toLowerCase().contains(query));
  }

  void setStatusFilter(int? status) {
    statusFilter = status;
    _applyFiltersInternal();
    safeNotify();
  }

  void toggleHideIgnored(bool val) {
    hideIgnored = val;
    _applyFiltersInternal();
    safeNotify();
  }

  void setSortColumn(int? index, bool ascending) {
    sortColumnIndex = index;
    sortAscending = ascending;
    safeNotify();
  }

  List<Term> get sortedTerms {
    final result = List<Term>.from(filteredTerms);
    result.sort((a, b) {
      int cmp;
      switch (sortColumnIndex) {
        case 0:
          cmp = a.text.compareTo(b.text);
        case 1:
          cmp = getTermTranslationText(a).compareTo(getTermTranslationText(b));
        case 2:
          cmp = a.createdAt.compareTo(b.createdAt);
        default:
          cmp = b.createdAt.compareTo(a.createdAt);
      }
      return sortAscending ? cmp : -cmp;
    });
    return result;
  }

  String getTermTranslationText(Term term) {
    final translations = term.id != null ? translationsMap[term.id!] : null;
    if (translations != null && translations.isNotEmpty) {
      return translations.map((t) => t.meaning).join(', ');
    }
    return term.translation;
  }

  Future<void> deleteTerm(Term term) async {
    await db.terms.delete(term.id!);
  }

  Future<int> importTermsFromFile(File csvFile) async {
    final content = await _importService.readTextFile(csvFile);
    final importedTerms = await _importService.importTermsFromCSV(content, language.id!);
    await bulkImportTerms(importedTerms);
    return importedTerms.length;
  }

  Future<void> exportTerms(String format) async {
    final termIds = terms.map((t) => t.id).whereType<String>().toList();
    final grouped = await db.termSentences.getByTermIds(termIds);
    final firstByTermId = {
      for (final entry in grouped.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value.first,
    };
    await _importService.exportAndShare(
      terms,
      format,
      sentencesByTermId: firstByTermId,
    );
  }
}
