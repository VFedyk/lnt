// FILE: lib/screens/vocabulary_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/term.dart';
import '../models/dictionary.dart';
import '../service_locator.dart';
import '../services/dictionary_service.dart';
import '../services/import_export_service.dart';
import '../utils/async_helpers.dart';
import '../utils/constants.dart';
import '../utils/snackbar_helpers.dart';
import '../widgets/shared/app_empty_state.dart';
import '../widgets/shared/term_dialog.dart';

abstract class _TermsConstants {
  static const double filterChipAvatarRadius = 8.0;
  static const int statusFilterCount = 7;
  static const int wellKnownStatusIndex = 6;
  static const int wellKnownStatusValue = 99;
  static const double wideLayoutBreakpoint = 600.0;
  static const double statusDotSize = 10.0;
}

class VocabularyScreen extends StatefulWidget {
  final Language language;

  const VocabularyScreen({super.key, required this.language});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  List<Term> _terms = [];
  List<Term> _filteredTerms = [];
  Map<int, List<Translation>> _translationsMap = {};
  bool _isLoading = true;
  bool _loadInProgress = false;
  bool _pendingReload = false;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _importService = ImportExportService();
  final _dictService = DictionaryService();
  List<Dictionary> _dictionaries = [];
  int? _statusFilter;
  bool _hideIgnored = true;
  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    dataChanges.terms.addListener(_loadTerms);
    _loadTerms();
    _loadDictionaries();
  }

  Future<void> _loadDictionaries() async {
    final dicts = await _dictService.getActiveDictionaries(widget.language.id!);
    if (mounted) setState(() => _dictionaries = dicts);
  }

  @override
  void dispose() {
    dataChanges.terms.removeListener(_loadTerms);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTerms() async {
    if (_loadInProgress) {
      _pendingReload = true;
      return;
    }
    _loadInProgress = true;
    _pendingReload = false;

    final isInitialLoad = _terms.isEmpty;
    if (isInitialLoad) setState(() => _isLoading = true);

    final scrollOffset =
        !isInitialLoad && _scrollController.hasClients
            ? _scrollController.offset
            : 0.0;

    try {
      final terms = await db.terms.getAll(languageId: widget.language.id!);
      // Batch load translations for all terms
      final termIds = terms
          .where((t) => t.id != null)
          .map((t) => t.id!)
          .toList();
      final translationsMap = await db.translations.getByTermIds(termIds);
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _translationsMap = translationsMap;
        _applyFilters();
        _isLoading = false;
      });
      if (scrollOffset > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            );
          }
        });
      }
    } finally {
      _loadInProgress = false;
      if (_pendingReload && mounted) {
        _loadTerms();
      }
    }
  }

  Map<int, int> _statusCounts = {};

  void _applyFilters() {
    var filtered = _terms;

    if (_hideIgnored && _statusFilter == null) {
      filtered = filtered.where((t) => t.status != AppConstants.statusIgnored).toList();
    }

    if (_statusFilter != null) {
      filtered = filtered.where((t) => t.status == _statusFilter).toList();
    }

    final query = _searchController.text.toLowerCase();
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

    _filteredTerms = filtered;
    _updateStatusCounts();
  }

  void _updateStatusCounts() {
    _statusCounts = {};
    for (final term in _terms) {
      _statusCounts[term.status] = (_statusCounts[term.status] ?? 0) + 1;
    }
  }

  Future<void> _exportTerms(String format) async {
    final l10n = AppLocalizations.of(context);
    await AsyncHelpers.run(
      context,
      operation: () => _importService.exportAndShare(_terms, format),
      successMessage: l10n.exportedTerms(_terms.length),
      errorMessageBuilder: (e) => l10n.exportFailed(e.toString()),
    );
  }

  Future<void> _importFromCSV() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );

    if (result != null && result.files.single.path != null && mounted) {
      int importedCount = 0;
      await AsyncHelpers.run(
        context,
        operation: () async {
          final file = File(result.files.single.path!);
          final content = await _importService.readTextFile(file);
          final importedTerms = await _importService.importTermsFromCSV(
            content,
            widget.language.id!,
          );
          await db.terms.bulkCreate(importedTerms);
          importedCount = importedTerms.length;
        },
        errorMessageBuilder: (e) => l10n.importFailed(e.toString()),
      );

      if (mounted && importedCount > 0) {
        SnackbarHelpers.showSuccess(context, l10n.importedTerms(importedCount));
      }
    }
  }

  Future<void> _deleteTerm(Term term) async {
    await db.terms.delete(term.id!);
  }

  Future<void> _addTerm() async {
    final newTerm = Term(
      languageId: widget.language.id!,
      text: '',
      lowerText: '',
    );
    final dialogResult = await showDialog<TermDialogResult?>(
      context: context,
      builder: (dialogContext) => TermDialog(
        term: newTerm,
        sentence: '',
        onLookup: (ctx, dictNum) {},
        dictionaries: const [],
        languageId: widget.language.id!,
        languageName: widget.language.name,
        languageCode: widget.language.languageCode,
      ),
    );

    if (dialogResult != null) {
      final id = await db.terms.create(dialogResult.term);
      await db.translations.replaceForTerm(id, dialogResult.translations);
    }
  }

  Future<void> _editTerm(Term term) async {
    final dialogResult = await showDialog<TermDialogResult?>(
      context: context,
      builder: (dialogContext) => TermDialog(
        term: term,
        sentence: term.sentence,
        onLookup: (ctx, dict) => _dictService.lookupWord(ctx, term.text, dict),
        dictionaries: _dictionaries,
        languageId: widget.language.id!,
        languageName: widget.language.name,
        languageCode: widget.language.languageCode,
      ),
    );

    if (dialogResult != null) {
      await db.terms.update(dialogResult.term);
      await db.translations.replaceForTerm(
        dialogResult.term.id!,
        dialogResult.translations,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vocabularyTitle(widget.language.name)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _importFromCSV();
                  break;
                case 'export_csv':
                  _exportTerms('csv');
                  break;
                case 'export_anki':
                  _exportTerms('anki');
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'import',
                child: Row(
                  children: [
                    const Icon(Icons.file_upload),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.importCsv),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    const Icon(Icons.file_download),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.exportCsv),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'export_anki',
                child: Row(
                  children: [
                    const Icon(Icons.file_download),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.exportAnki),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTerm,
        tooltip: l10n.addTerm,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.searchTerms,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.borderRadiusM,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() => _applyFilters()),
                ),
                const SizedBox(height: AppConstants.spacingS),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('${l10n.all} (${_terms.length})'),
                        selected: _statusFilter == null,
                        onSelected: (_) {
                          setState(() {
                            _statusFilter = null;
                            _applyFilters();
                          });
                        },
                      ),
                      const SizedBox(width: AppConstants.spacingS),
                      ...List.generate(_TermsConstants.statusFilterCount, (i) {
                        final status = i == _TermsConstants.wellKnownStatusIndex
                            ? _TermsConstants.wellKnownStatusValue
                            : i;
                        final statusName = TermStatus.localizedNameFor(
                          status,
                          l10n,
                        );
                        final count = _statusCounts[status] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(
                            right: AppConstants.spacingS,
                          ),
                          child: FilterChip(
                            label: Text('$statusName ($count)'),
                            selected: _statusFilter == status,
                            onSelected: (_) {
                              setState(() {
                                _statusFilter = status;
                                _applyFilters();
                              });
                            },
                            avatar: CircleAvatar(
                              backgroundColor: _getStatusColor(status),
                              radius: _TermsConstants.filterChipAvatarRadius,
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: AppConstants.spacingS),
                      FilterChip(
                        label: Text(l10n.hideIgnored),
                        selected: _hideIgnored,
                        onSelected: _statusFilter == null
                            ? (val) => setState(() {
                                  _hideIgnored = val;
                                  _applyFilters();
                                })
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTermsList(),
          ),
        ],
      ),
    );
  }

  List<Term> get _sortedTerms {
    final terms = List<Term>.from(_filteredTerms);
    terms.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0:
          cmp = a.text.compareTo(b.text);
        case 1:
          cmp = _termTranslationText(a).compareTo(_termTranslationText(b));
        case 2:
          cmp = a.createdAt.compareTo(b.createdAt);
        default:
          // Default: newest first
          cmp = b.createdAt.compareTo(a.createdAt);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return terms;
  }

  String _termTranslationText(Term term) {
    final translations = term.id != null ? _translationsMap[term.id!] : null;
    if (translations != null && translations.isNotEmpty) {
      return translations.map((t) => t.meaning).join(', ');
    }
    return term.translation;
  }

  Widget _buildTermsList() {
    final l10n = AppLocalizations.of(context);
    if (_filteredTerms.isEmpty) {
      return AppEmptyState(icon: Icons.search_off, title: l10n.noTermsFound);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _TermsConstants.wideLayoutBreakpoint) {
          return _buildDataTable(l10n);
        }
        return _buildCompactList(l10n);
      },
    );
  }

  Widget _buildDataTable(AppLocalizations l10n) {
    final terms = _sortedTerms;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        // Sticky header
        Container(
          color: colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingL,
            vertical: AppConstants.spacingS,
          ),
          child: Row(
            children: [
              const SizedBox(width: _TermsConstants.statusDotSize + AppConstants.spacingM),
              Expanded(
                child: _SortableHeader(
                  label: l10n.term,
                  active: _sortColumnIndex == 0,
                  ascending: _sortAscending,
                  onTap: () => setState(() {
                    if (_sortColumnIndex == 0) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortColumnIndex = 0;
                      _sortAscending = true;
                    }
                  }),
                  style: textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: AppConstants.spacingL),
              Expanded(
                flex: 2,
                child: _SortableHeader(
                  label: l10n.translation,
                  active: _sortColumnIndex == 1,
                  ascending: _sortAscending,
                  onTap: () => setState(() {
                    if (_sortColumnIndex == 1) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortColumnIndex = 1;
                      _sortAscending = true;
                    }
                  }),
                  style: textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: AppConstants.spacingL),
              _SortableHeader(
                label: l10n.addedAt,
                active: _sortColumnIndex == 2,
                ascending: _sortAscending,
                onTap: () => setState(() {
                  if (_sortColumnIndex == 2) {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortColumnIndex = 2;
                    _sortAscending = true;
                  }
                }),
                style: textTheme.labelLarge,
              ),
              const SizedBox(width: AppConstants.spacingXL),
            ],
          ),
        ),
        const Divider(height: 1),
        // Virtualized rows
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            itemCount: terms.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final term = terms[index];
              final translationText = _termTranslationText(term);
              return InkWell(
                onTap: () => _editTerm(term),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                    vertical: AppConstants.spacingS,
                  ),
                  child: Row(
                    children: [
                      Tooltip(
                        message: TermStatus.localizedNameFor(term.status, l10n),
                        child: Container(
                          width: _TermsConstants.statusDotSize,
                          height: _TermsConstants.statusDotSize,
                          decoration: BoxDecoration(
                            color: term.statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(term.text),
                            if (term.romanization.isNotEmpty)
                              Text(
                                term.romanization,
                                style: TextStyle(
                                  color: AppConstants.subtitleColor,
                                  fontSize: AppConstants.fontSizeCaption,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingL),
                      Expanded(
                        flex: 2,
                        child: Text(
                          translationText,
                          style: TextStyle(color: AppConstants.subtitleColor),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingL),
                      Text(
                        DateFormat('dd MMM yyyy').format(term.createdAt),
                        style: TextStyle(
                          color: AppConstants.subtitleColor,
                          fontSize: AppConstants.fontSizeCaption,
                        ),
                      ),
                      _buildRowMenu(term, l10n),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCompactList(AppLocalizations l10n) {
    final terms = _sortedTerms;
    return ListView.separated(
      controller: _scrollController,
      itemCount: terms.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final term = terms[index];
        final translationText = _termTranslationText(term);
        return InkWell(
          onTap: () => _editTerm(term),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingL,
              vertical: AppConstants.spacingS,
            ),
            child: Row(
              children: [
                Tooltip(
                  message: TermStatus.localizedNameFor(term.status, l10n),
                  child: Container(
                    width: _TermsConstants.statusDotSize,
                    height: _TermsConstants.statusDotSize,
                    decoration: BoxDecoration(
                      color: term.statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        term.text,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      if (term.romanization.isNotEmpty)
                        Text(
                          term.romanization,
                          style: TextStyle(
                            color: AppConstants.subtitleColor,
                            fontSize: AppConstants.fontSizeCaption,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  flex: 3,
                  child: Text(
                    translationText,
                    style: TextStyle(color: AppConstants.subtitleColor),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                _buildRowMenu(term, l10n),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRowMenu(Term term, AppLocalizations l10n) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: AppConstants.iconSizeS),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.edit),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: AppConstants.spacingS),
              Text(
                l10n.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        if (value == 'edit') {
          _editTerm(term);
        } else if (value == 'delete') {
          _deleteTerm(term);
        }
      },
    );
  }

  bool _translationsContainQuery(int? termId, String query) {
    if (termId == null) return false;
    final translations = _translationsMap[termId];
    if (translations == null) return false;
    return translations.any((t) => t.meaning.toLowerCase().contains(query));
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 0:
        return Colors.grey.shade400;
      case 1:
        return Colors.red.shade400;
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.yellow.shade700;
      case 4:
        return Colors.lightGreen.shade500;
      case 5:
        return Colors.green.shade600;
      case 99:
        return Colors.blue.shade400;
      default:
        return Colors.grey;
    }
  }
}

class _SortableHeader extends StatelessWidget {
  final String label;
  final bool active;
  final bool ascending;
  final VoidCallback onTap;
  final TextStyle? style;

  const _SortableHeader({
    required this.label,
    required this.active,
    required this.ascending,
    required this.onTap,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          if (active) ...[
            const SizedBox(width: AppConstants.spacingXS),
            Icon(
              ascending ? Icons.arrow_upward : Icons.arrow_downward,
              size: AppConstants.iconSizeS,
            ),
          ],
        ],
      ),
    );
  }
}
