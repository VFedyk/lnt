// FILE: lib/screens/terms_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/term.dart';
import '../service_locator.dart';
import '../services/import_export_service.dart';
import '../utils/constants.dart';
import '../widgets/term_dialog.dart';

abstract class _TermsConstants {
  static const double filterChipAvatarRadius = 8.0;
  static const int statusFilterCount = 7;
  static const int wellKnownStatusIndex = 6;
  static const int wellKnownStatusValue = 99;
}

class TermsScreen extends StatefulWidget {
  final Language language;

  const TermsScreen({super.key, required this.language});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  List<Term> _terms = [];
  List<Term> _filteredTerms = [];
  Map<int, List<Translation>> _translationsMap = {};
  bool _isLoading = true;
  bool _loadInProgress = false;
  bool _pendingReload = false;
  final _searchController = TextEditingController();
  final _importService = ImportExportService();
  int? _statusFilter;

  @override
  void initState() {
    super.initState();
    dataChanges.terms.addListener(_loadTerms);
    _loadTerms();
  }

  @override
  void dispose() {
    dataChanges.terms.removeListener(_loadTerms);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTerms() async {
    if (_loadInProgress) {
      _pendingReload = true;
      return;
    }
    _loadInProgress = true;
    _pendingReload = false;

    setState(() => _isLoading = true);
    try {
      final terms = await db.terms.getAll(
        languageId: widget.language.id!,
      );
      // Batch load translations for all terms
      final termIds = terms.where((t) => t.id != null).map((t) => t.id!).toList();
      final translationsMap = await db.translations.getByTermIds(termIds);
      if (!mounted) return;
      setState(() {
        _terms = terms;
        _translationsMap = translationsMap;
        _applyFilters();
        _isLoading = false;
      });
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
    try {
      await _importService.exportAndShare(_terms, format);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportedTerms(_terms.length))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.exportFailed(e.toString()))));
      }
    }
  }

  Future<void> _importFromCSV() async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      try {
        final file = File(result.files.single.path!);
        final content = await _importService.readTextFile(file);
        final importedTerms = await _importService.importTermsFromCSV(
          content,
          widget.language.id!,
        );

        for (final term in importedTerms) {
          await db.terms.create(term);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.importedTerms(importedTerms.length))),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.importFailed(e.toString()))));
        }
      }
    }
  }

  Future<void> _deleteTerm(Term term) async {
    await db.terms.delete(term.id!);
  }

  Future<void> _editTerm(Term term) async {
    final dialogResult = await showDialog<TermDialogResult?>(
      context: context,
      builder: (dialogContext) => TermDialog(
        term: term,
        sentence: term.sentence,
        onLookup: (ctx, dictNum) {},
        dictionaries: const [],
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
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
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
                        final statusName = TermStatus.localizedNameFor(status, l10n);
                        final count = _statusCounts[status] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppConstants.spacingS),
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

  Widget _buildTermsList() {
    final l10n = AppLocalizations.of(context);
    if (_filteredTerms.isEmpty) {
      return Center(child: Text(l10n.noTermsFound));
    }

    return ListView.builder(
      itemCount: _filteredTerms.length,
      itemBuilder: (context, index) {
        final term = _filteredTerms[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingL,
            vertical: AppConstants.spacingXS,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: term.statusColor,
              child: Text(
                term.status.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: AppConstants.fontSizeCaption,
                ),
              ),
            ),
            title: Text(term.text),
            subtitle: _buildTermSubtitle(term, l10n),
            trailing: PopupMenuButton(
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
                      const Icon(Icons.delete, color: AppConstants.deleteColor),
                      const SizedBox(width: AppConstants.spacingS),
                      Text(l10n.delete, style: const TextStyle(color: AppConstants.deleteColor)),
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
            ),
            onTap: () => _editTerm(term),
          ),
        );
      },
    );
  }


  bool _translationsContainQuery(int? termId, String query) {
    if (termId == null) return false;
    final translations = _translationsMap[termId];
    if (translations == null) return false;
    return translations.any((t) => t.meaning.toLowerCase().contains(query));
  }

  Widget? _buildTermSubtitle(Term term, AppLocalizations l10n) {
    final translations = term.id != null ? _translationsMap[term.id!] : null;
    final hasTranslations = translations != null && translations.isNotEmpty;
    final hasLegacyTranslation = term.translation.isNotEmpty;
    final hasRomanization = term.romanization.isNotEmpty;

    if (!hasTranslations && !hasLegacyTranslation && !hasRomanization) {
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasTranslations)
          ...translations.map((t) => Text(
            t.partOfSpeech != null
                ? '${t.meaning} (${PartOfSpeech.localizedNameFor(t.partOfSpeech!, l10n)})'
                : t.meaning,
          ))
        else if (hasLegacyTranslation)
          Text(term.translation),
        if (hasRomanization)
          Text(
            term.romanization,
            style: TextStyle(
              color: AppConstants.subtitleColor,
              fontSize: AppConstants.fontSizeCaption,
            ),
          ),
      ],
    );
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
