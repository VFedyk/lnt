import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/term.dart';
import '../../service_locator.dart';
import '../../utils/async_helpers.dart';
import '../../utils/constants.dart';
import '../../utils/dictionary_navigation.dart';
import '../../utils/snackbar_helpers.dart';
import '../theme/term_status_ui.dart';
import '../controllers/vocabulary_controller.dart';
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

class VocabularyScreen extends StatelessWidget {
  final Language language;

  const VocabularyScreen({super.key, required this.language});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VocabularyController(language: language),
      child: const _VocabularyView(),
    );
  }
}

class _VocabularyView extends StatefulWidget {
  const _VocabularyView();

  @override
  State<_VocabularyView> createState() => _VocabularyViewState();
}

class _VocabularyViewState extends State<_VocabularyView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _exportTerms(
    BuildContext context,
    VocabularyController controller,
    String format,
  ) async {
    final l10n = AppLocalizations.of(context);
    await AsyncHelpers.run(
      context,
      operation: () => controller.exportTerms(format),
      successMessage: l10n.exportedTerms(controller.terms.length),
      errorMessageBuilder: (e) => l10n.exportFailed(e.toString()),
    );
  }

  Future<void> _importFromCSV(
    BuildContext context,
    VocabularyController controller,
  ) async {
    final l10n = AppLocalizations.of(context);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );

    if (result != null && result.files.single.path != null && context.mounted) {
      int importedCount = 0;
      await AsyncHelpers.run(
        context,
        operation: () async {
          importedCount = await controller.importTermsFromFile(
            File(result.files.single.path!),
          );
        },
        errorMessageBuilder: (e) => l10n.importFailed(e.toString()),
      );

      if (context.mounted && importedCount > 0) {
        SnackbarHelpers.showSuccess(context, l10n.importedTerms(importedCount));
      }
    }
  }

  Future<void> _addTerm(BuildContext context, VocabularyController controller) async {
    final language = controller.language;
    final newTerm = Term(
      languageId: language.id!,
      text: '',
      lowerText: '',
    );
    final dialogResult = await TermDialog.show(
      context,
      term: newTerm,
      sentence: '',
      onLookup: (ctx, dictNum) {},
      dictionaries: const [],
      languageId: language.id!,
      languageName: language.name,
      languageCode: language.languageCode,
    );

    if (!context.mounted) return;
    if (dialogResult != null && !dialogResult.deleted) {
      await saveTerm(dialogResult.term, dialogResult.translations, isNew: true);
    }
  }

  Future<void> _editTerm(
    BuildContext context,
    VocabularyController controller,
    Term term,
  ) async {
    final language = controller.language;
    final dialogResult = await TermDialog.show(
      context,
      term: term,
      sentence: term.sentence,
      onLookup: (ctx, dict) => openDictionaryLookup(ctx, term.text, dict),
      dictionaries: controller.dictionaries,
      languageId: language.id!,
      languageName: language.name,
      languageCode: language.languageCode,
    );

    if (!context.mounted) return;
    if (dialogResult == null) return;
    if (dialogResult.deleted) {
      await controller.deleteTerm(term);
    } else {
      await saveTerm(dialogResult.term, dialogResult.translations, isNew: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VocabularyController>();
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.vocabularyTitle(controller.language.name)),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'import':
                  _importFromCSV(context, controller);
                case 'export_csv':
                  _exportTerms(context, controller, 'csv');
                case 'export_anki':
                  _exportTerms(context, controller, 'anki');
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
        onPressed: () => _addTerm(context, controller),
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
                      borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
                    ),
                  ),
                  onChanged: (q) => controller.applyFilters(q),
                ),
                const SizedBox(height: AppConstants.spacingS),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: Text('${l10n.all} (${controller.terms.length})'),
                        selected: controller.statusFilter == null,
                        onSelected: (_) => controller.setStatusFilter(null),
                      ),
                      const SizedBox(width: AppConstants.spacingS),
                      ...List.generate(_TermsConstants.statusFilterCount, (i) {
                        final status = i == _TermsConstants.wellKnownStatusIndex
                            ? _TermsConstants.wellKnownStatusValue
                            : i;
                        final statusName = TermStatusUI.localizedNameFor(status, l10n);
                        final count = controller.statusCounts[status] ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(right: AppConstants.spacingS),
                          child: FilterChip(
                            label: Text('$statusName ($count)'),
                            selected: controller.statusFilter == status,
                            onSelected: (_) => controller.setStatusFilter(status),
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
                        selected: controller.hideIgnored,
                        onSelected: controller.statusFilter == null
                            ? (val) => controller.toggleHideIgnored(val)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildTermsList(context, controller, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsList(
    BuildContext context,
    VocabularyController controller,
    AppLocalizations l10n,
  ) {
    if (controller.filteredTerms.isEmpty) {
      return AppEmptyState(icon: Icons.search_off, title: l10n.noTermsFound);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _TermsConstants.wideLayoutBreakpoint) {
          return _buildDataTable(context, controller, l10n);
        }
        return _buildCompactList(context, controller, l10n);
      },
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    VocabularyController controller,
    AppLocalizations l10n,
  ) {
    final terms = controller.sortedTerms;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
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
                  active: controller.sortColumnIndex == 0,
                  ascending: controller.sortAscending,
                  onTap: () {
                    final newAsc = controller.sortColumnIndex == 0
                        ? !controller.sortAscending
                        : true;
                    controller.setSortColumn(0, newAsc);
                  },
                  style: textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: AppConstants.spacingL),
              Expanded(
                flex: 2,
                child: _SortableHeader(
                  label: l10n.translation,
                  active: controller.sortColumnIndex == 1,
                  ascending: controller.sortAscending,
                  onTap: () {
                    final newAsc = controller.sortColumnIndex == 1
                        ? !controller.sortAscending
                        : true;
                    controller.setSortColumn(1, newAsc);
                  },
                  style: textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: AppConstants.spacingL),
              _SortableHeader(
                label: l10n.addedAt,
                active: controller.sortColumnIndex == 2,
                ascending: controller.sortAscending,
                onTap: () {
                  final newAsc = controller.sortColumnIndex == 2
                      ? !controller.sortAscending
                      : true;
                  controller.setSortColumn(2, newAsc);
                },
                style: textTheme.labelLarge,
              ),
              const SizedBox(width: AppConstants.spacingXL),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            itemCount: terms.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final term = terms[index];
              final translationText = controller.getTermTranslationText(term);
              return InkWell(
                onTap: () => _editTerm(context, controller, term),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                    vertical: AppConstants.spacingS,
                  ),
                  child: Row(
                    children: [
                      Tooltip(
                        message: TermStatusUI.localizedNameFor(term.status, l10n),
                        child: Container(
                          width: _TermsConstants.statusDotSize,
                          height: _TermsConstants.statusDotSize,
                          decoration: BoxDecoration(
                            color: TermStatusUI.colorFor(term.status),
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
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      const SizedBox(width: AppConstants.spacingL),
                      Text(
                        DateFormat('dd MMM yyyy').format(term.createdAt),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: AppConstants.fontSizeCaption,
                        ),
                      ),
                      _buildRowMenu(context, controller, term, l10n),
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

  Widget _buildCompactList(
    BuildContext context,
    VocabularyController controller,
    AppLocalizations l10n,
  ) {
    final terms = controller.sortedTerms;
    return ListView.separated(
      controller: _scrollController,
      itemCount: terms.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final term = terms[index];
        final translationText = controller.getTermTranslationText(term);
        return InkWell(
          onTap: () => _editTerm(context, controller, term),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingL,
              vertical: AppConstants.spacingS,
            ),
            child: Row(
              children: [
                Tooltip(
                  message: TermStatusUI.localizedNameFor(term.status, l10n),
                  child: Container(
                    width: _TermsConstants.statusDotSize,
                    height: _TermsConstants.statusDotSize,
                    decoration: BoxDecoration(
                      color: TermStatusUI.colorFor(term.status),
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                _buildRowMenu(context, controller, term, l10n),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRowMenu(
    BuildContext context,
    VocabularyController controller,
    Term term,
    AppLocalizations l10n,
  ) {
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
          _editTerm(context, controller, term);
        } else if (value == 'delete') {
          controller.deleteTerm(term);
        }
      },
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
