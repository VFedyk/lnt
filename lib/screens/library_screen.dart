import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../controllers/library_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/collection.dart';
import '../services/import_export_service.dart';
import '../services/epub_import_service.dart';
import '../widgets/add_text_dialog.dart';
import '../widgets/book_cover.dart';
import '../widgets/collection_dialog.dart';
import '../widgets/text_edit_dialog.dart';
import '../widgets/url_import_dialog.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import 'reader_screen.dart';

abstract class _LibraryScreenConstants {
  static const double gridMaxCrossAxisExtent = 140.0;
  static const double gridChildAspectRatio = 0.45;
  static const double sortArrowIconSize = 16.0;
  static const double badgeVerticalPadding = 2.0;
  static const double finishedBackgroundAlpha = 0.2;
  static const int maxWarningsShown = 3;
  static const double fabMenuVerticalOffset = 200.0;

  static const String actionAdd = 'add';
  static const String actionUrl = 'url';
  static const String actionTxt = 'txt';
  static const String actionEpub = 'epub';
  static const String actionCover = 'cover';
  static const String actionEdit = 'edit';
  static const String actionDelete = 'delete';
}

class LibraryScreen extends StatefulWidget {
  final Language language;

  const LibraryScreen({super.key, required this.language});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  final _importService = ImportExportService();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Dialog orchestration ──

  Future<void> _addText(LibraryController ctrl) async {
    final result = await showDialog<TextDocument>(
      context: context,
      builder: (context) => AddTextDialog(
        languageId: widget.language.id!,
        collectionId: ctrl.currentCollection?.id,
      ),
    );
    if (result != null) await ctrl.createText(result);
  }

  Future<void> _addCollection(LibraryController ctrl) async {
    final result = await showDialog<Collection>(
      context: context,
      builder: (context) => CollectionDialog(
        languageId: widget.language.id!,
        parentId: ctrl.currentCollection?.id,
      ),
    );
    if (result != null) await ctrl.createCollection(result);
  }

  Future<void> _editText(LibraryController ctrl, TextDocument text) async {
    final result = await showDialog<TextDocument>(
      context: context,
      builder: (context) => TextEditDialog(text: text),
    );
    if (result != null) await ctrl.updateText(result);
  }

  Future<void> _editCollection(
    LibraryController ctrl,
    Collection collection,
  ) async {
    final result = await showDialog<Collection>(
      context: context,
      builder: (context) => CollectionDialog(
        languageId: widget.language.id!,
        parentId: collection.parentId,
        existingCollection: collection,
      ),
    );
    if (result != null) await ctrl.updateCollection(result);
  }

  Future<void> _deleteText(LibraryController ctrl, TextDocument text) async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteText),
        content: Text(l10n.deleteTextConfirm(text.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm == true) await ctrl.deleteText(text.id!);
  }

  Future<void> _deleteCollection(
    LibraryController ctrl,
    Collection collection,
  ) async {
    final l10n = AppLocalizations.of(context);
    final textCount = await ctrl.getTextCountInCollection(collection.id!);
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCollection),
        content: Text(
          textCount > 0
              ? l10n.deleteCollectionConfirm(collection.name, textCount)
              : l10n.deleteCollectionSimple(collection.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirm == true) await ctrl.deleteCollection(collection.id!);
  }

  Future<void> _setCoverImage(
    LibraryController ctrl,
    TextDocument text,
  ) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      await ctrl.setCoverImage(text, result.files.single.path!);
    }
  }

  // ── Import ──

  Future<void> _importFromTextFile(LibraryController ctrl) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      final content = await _importService.readTextFile(File(file.path!));

      final text = TextDocument(
        languageId: widget.language.id!,
        collectionId: ctrl.currentCollection?.id,
        title: file.name.replaceAll('.txt', ''),
        content: _importService.cleanTextForImport(content),
      );
      await ctrl.createText(text);
    }
  }

  Future<void> _importFromEpub(LibraryController ctrl) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;
    if (!mounted) return;

    final file = result.files.single;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: AppConstants.spacingL),
            Expanded(child: Text(l10n.importingEpub)),
          ],
        ),
      ),
    );

    try {
      final epubService = EpubImportService();
      final importResult = await epubService.importEpub(
        epubBytes: file.bytes!,
        languageId: widget.language.id!,
        parentCollectionId: ctrl.currentCollection?.id,
      );

      if (!mounted) return;
      Navigator.pop(context);

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.importComplete),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${l10n.book}: ${importResult.bookTitle}'),
              if (importResult.author != null)
                Text('${l10n.author}: ${importResult.author}'),
              Text('${l10n.chapters}: ${importResult.totalChapters}'),
              if (importResult.totalParts > importResult.totalChapters)
                Text('${l10n.totalParts}: ${importResult.totalParts}'),
              Text('${l10n.characters}: ${importResult.totalCharacters}'),
              if (importResult.warnings.isNotEmpty) ...[
                const SizedBox(height: AppConstants.spacingS),
                Text(
                  '${l10n.notes}:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                ...importResult.warnings
                    .take(_LibraryScreenConstants.maxWarningsShown)
                    .map((w) => Text('\u2022 $w')),
                if (importResult.warnings.length >
                    _LibraryScreenConstants.maxWarningsShown)
                  Text(
                    '... and ${importResult.warnings.length - _LibraryScreenConstants.maxWarningsShown} more',
                  ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );

      await ctrl.loadData();
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.importFailedTitle),
          content: Text(l10n.couldNotImportEpub(e.toString())),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.ok),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _importFromUrl(LibraryController ctrl) async {
    final result = await showDialog<TextDocument>(
      context: context,
      builder: (context) => UrlImportDialog(
        languageId: widget.language.id!,
        collectionId: ctrl.currentCollection?.id,
      ),
    );
    if (result != null) await ctrl.createText(result);
  }

  void _showAddMenu(BuildContext context, Offset position, LibraryController ctrl) {
    final l10n = AppLocalizations.of(context);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx, position.dy, position.dx, position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _LibraryScreenConstants.actionAdd,
          child: Row(
            children: [
              const Icon(Icons.edit),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.addText),
            ],
          ),
        ),
        PopupMenuItem(
          value: _LibraryScreenConstants.actionUrl,
          child: Row(
            children: [
              const Icon(Icons.link),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.importFromUrl),
            ],
          ),
        ),
        PopupMenuItem(
          value: _LibraryScreenConstants.actionTxt,
          child: Row(
            children: [
              const Icon(Icons.text_snippet),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.importTxt),
            ],
          ),
        ),
        PopupMenuItem(
          value: _LibraryScreenConstants.actionEpub,
          child: Row(
            children: [
              const Icon(Icons.book),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.importEpub),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case _LibraryScreenConstants.actionAdd:
          _addText(ctrl);
        case _LibraryScreenConstants.actionTxt:
          _importFromTextFile(ctrl);
        case _LibraryScreenConstants.actionEpub:
          _importFromEpub(ctrl);
        case _LibraryScreenConstants.actionUrl:
          _importFromUrl(ctrl);
      }
    });
  }

  void _showCollectionOptions(LibraryController ctrl, Collection collection) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                _editCollection(ctrl, collection);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text(
                l10n.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteCollection(ctrl, collection);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTextOptions(LibraryController ctrl, TextDocument text) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: Text(l10n.setCover),
              onTap: () {
                Navigator.pop(context);
                _setCoverImage(ctrl, text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                _editText(ctrl, text);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text(
                l10n.delete,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _deleteText(ctrl, text);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final ctrl = LibraryController(language: widget.language);
        ctrl.loadPreferences().then((_) => ctrl.loadData());
        return ctrl;
      },
      child: Builder(builder: (context) {
        final ctrl = context.watch<LibraryController>();
        return _buildScaffold(context, ctrl);
      }),
    );
  }

  Widget _buildScaffold(BuildContext context, LibraryController ctrl) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.textsTitle(widget.language.name)),
            if (ctrl.currentCollection != null)
              Text(
                ctrl.currentCollection!.name,
                style: const TextStyle(fontSize: AppConstants.fontSizeBody),
              ),
          ],
        ),
        leading: ctrl.currentCollection != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: ctrl.goBack,
              )
            : null,
        actions: [
          IconButton(
            icon: Icon(
              _showSearch ? Icons.search_off : Icons.search,
              color: _showSearch ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: l10n.search,
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) _searchController.clear();
              });
            },
          ),
          IconButton(
            icon: Icon(
              ctrl.viewMode == TextViewMode.list ? Icons.grid_view : Icons.list,
            ),
            tooltip: ctrl.viewMode == TextViewMode.list
                ? l10n.switchToGridView
                : l10n.switchToListView,
            onPressed: ctrl.toggleViewMode,
          ),
          PopupMenuButton<TextSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: l10n.sort,
            onSelected: ctrl.setSortOption,
            itemBuilder: (context) => TextSortOption.values.map((option) {
              final isSelected = ctrl.sortOption == option;
              return PopupMenuItem(
                value: option,
                child: Row(
                  children: [
                    Icon(
                      option.icon,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: AppConstants.spacingS),
                    Expanded(
                      child: Text(
                        option.localizedLabel(l10n),
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        ctrl.sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: _LibraryScreenConstants.sortArrowIconSize,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          IconButton(
            icon: Icon(
              ctrl.hideCompleted ? Icons.visibility_off : Icons.visibility,
              color: ctrl.hideCompleted
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: ctrl.hideCompleted
                ? l10n.showCompletedTexts
                : l10n.hideCompletedTexts,
            onPressed: ctrl.toggleHideCompleted,
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: l10n.newCollection,
            onPressed: () => _addCollection(ctrl),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_upload),
            tooltip: l10n.import,
            onSelected: (value) {
              switch (value) {
                case _LibraryScreenConstants.actionTxt:
                  _importFromTextFile(ctrl);
                case _LibraryScreenConstants.actionEpub:
                  _importFromEpub(ctrl);
                case _LibraryScreenConstants.actionUrl:
                  _importFromUrl(ctrl);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _LibraryScreenConstants.actionUrl,
                child: Row(
                  children: [
                    const Icon(Icons.link),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.importFromUrl),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _LibraryScreenConstants.actionTxt,
                child: Row(
                  children: [
                    const Icon(Icons.text_snippet),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.importTxt),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _LibraryScreenConstants.actionEpub,
                child: Row(
                  children: [
                    const Icon(Icons.book),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.importEpub),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.searchTexts,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() => _searchController.clear());
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadiusM),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          _buildSortFilterBar(ctrl),
          Expanded(
            child: ctrl.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ctrl.viewMode == TextViewMode.list
                    ? _buildContentList(ctrl)
                    : _buildContentGrid(ctrl),
          ),
        ],
      ),
      floatingActionButton: Builder(
        builder: (fabContext) => FloatingActionButton(
          onPressed: () {
            final RenderBox button =
                fabContext.findRenderObject() as RenderBox;
            final Offset position = button.localToGlobal(Offset.zero);
            _showAddMenu(
              context,
              Offset(
                position.dx,
                position.dy - _LibraryScreenConstants.fabMenuVerticalOffset,
              ),
              ctrl,
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildSortFilterBar(LibraryController ctrl) {
    final l10n = AppLocalizations.of(context);
    final sortedTexts =
        ctrl.getSortedAndFilteredTexts(_searchController.text);
    final totalTexts = ctrl.texts.length;
    final shownTexts = sortedTexts.length;
    final hiddenCount = totalTexts - shownTexts;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingL,
        vertical: AppConstants.spacingS,
      ),
      child: Row(
        children: [
          Icon(
            ctrl.sortOption.icon,
            size: _LibraryScreenConstants.sortArrowIconSize,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: AppConstants.spacingXS),
          Text(
            '${ctrl.sortOption.localizedLabel(l10n)} ${ctrl.sortAscending ? '\u2191' : '\u2193'}',
            style: TextStyle(
              fontSize: AppConstants.fontSizeCaption,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          if (ctrl.hideCompleted && hiddenCount > 0) ...[
            const SizedBox(width: AppConstants.spacingM),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingS,
                vertical: _LibraryScreenConstants.badgeVerticalPadding,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius:
                    BorderRadius.circular(AppConstants.borderRadiusL),
              ),
              child: Text(
                l10n.completedHidden(hiddenCount),
                style: TextStyle(
                  fontSize: AppConstants.fontSizeCaption,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
          const Spacer(),
          Text(
            l10n.textCount(shownTexts),
            style: TextStyle(
              fontSize: AppConstants.fontSizeCaption,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentList(LibraryController ctrl) {
    final l10n = AppLocalizations.of(context);
    final sortedTexts =
        ctrl.getSortedAndFilteredTexts(_searchController.text);

    if (ctrl.collections.isEmpty && sortedTexts.isEmpty) {
      if (ctrl.hideCompleted && ctrl.texts.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: AppConstants.emptyStateIconSize,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: AppConstants.spacingL),
              Text(
                l10n.allTextsCompleted,
                style: TextStyle(
                  fontSize: AppConstants.fontSizeSubtitle,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              TextButton.icon(
                onPressed: ctrl.toggleHideCompleted,
                icon: const Icon(Icons.visibility),
                label: Text(l10n.showCompletedTexts),
              ),
            ],
          ),
        );
      }
      return Center(child: Text(l10n.noCollectionsOrTexts));
    }

    return ListView(
      children: [
        ...ctrl.collections.map(
          (collection) => Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingL,
              vertical: AppConstants.spacingXS,
            ),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.folder)),
              title: Tooltip(
                message: collection.name,
                child: Text(collection.name, overflow: TextOverflow.ellipsis),
              ),
              subtitle: collection.description.isNotEmpty
                  ? Text(collection.description)
                  : null,
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _LibraryScreenConstants.actionEdit,
                    child: Row(
                      children: [
                        const Icon(Icons.edit),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(l10n.edit),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _LibraryScreenConstants.actionDelete,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(l10n.delete),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == _LibraryScreenConstants.actionEdit) {
                    _editCollection(ctrl, collection);
                  } else if (value == _LibraryScreenConstants.actionDelete) {
                    _deleteCollection(ctrl, collection);
                  }
                },
              ),
              onTap: () => ctrl.openCollection(collection),
            ),
          ),
        ),
        ...sortedTexts.map((text) {
          final unknownCount = ctrl.unknownCounts[text.id] ?? 0;
          final totalLabel = widget.language.splitByCharacter
              ? l10n.charactersCount(text.characterCount)
              : l10n.wordsCount(text.wordCount);
          final unknownLabel = widget.language.splitByCharacter
              ? l10n.unknownCharacters(unknownCount)
              : l10n.unknownWords(unknownCount);

          return Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingL,
              vertical: AppConstants.spacingXS,
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: text.status == TextStatus.finished
                    ? context.appColors.success.withValues(
                        alpha:
                            _LibraryScreenConstants.finishedBackgroundAlpha,
                      )
                    : null,
                child: Icon(
                  text.status == TextStatus.finished
                      ? Icons.check
                      : Icons.article,
                  color: text.status == TextStatus.finished
                      ? context.appColors.success
                      : null,
                ),
              ),
              title: Tooltip(
                message: text.title,
                child: Text(text.title, overflow: TextOverflow.ellipsis),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(totalLabel),
                  Text(
                    unknownLabel,
                    style: TextStyle(
                      color: unknownCount > 0
                          ? context.appColors.warning
                          : context.appColors.success,
                      fontSize: AppConstants.fontSizeCaption,
                      fontWeight: unknownCount == 0 ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _LibraryScreenConstants.actionCover,
                    child: Row(
                      children: [
                        const Icon(Icons.image),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(l10n.setCover),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _LibraryScreenConstants.actionEdit,
                    child: Row(
                      children: [
                        const Icon(Icons.edit),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(l10n.edit),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _LibraryScreenConstants.actionDelete,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(l10n.delete),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == _LibraryScreenConstants.actionCover) {
                    _setCoverImage(ctrl, text);
                  } else if (value == _LibraryScreenConstants.actionEdit) {
                    _editText(ctrl, text);
                  } else if (value == _LibraryScreenConstants.actionDelete) {
                    _deleteText(ctrl, text);
                  }
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReaderScreen(
                      text: text,
                      language: widget.language,
                    ),
                  ),
                ).then((_) => ctrl.recalculateUnknownCountForText(text));
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildContentGrid(LibraryController ctrl) {
    final l10n = AppLocalizations.of(context);
    final sortedTexts =
        ctrl.getSortedAndFilteredTexts(_searchController.text);

    if (ctrl.collections.isEmpty && sortedTexts.isEmpty) {
      if (ctrl.hideCompleted && ctrl.texts.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: AppConstants.emptyStateIconSize,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: AppConstants.spacingL),
              Text(
                l10n.allTextsCompleted,
                style: TextStyle(
                  fontSize: AppConstants.fontSizeSubtitle,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: AppConstants.spacingS),
              TextButton.icon(
                onPressed: ctrl.toggleHideCompleted,
                icon: const Icon(Icons.visibility),
                label: Text(l10n.showCompletedTexts),
              ),
            ],
          ),
        );
      }
      return Center(child: Text(l10n.noCollectionsOrTexts));
    }

    final items = <_GridItem>[
      ...ctrl.collections.map((c) => _GridItem(collection: c)),
      ...sortedTexts.map((t) => _GridItem(text: t)),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _LibraryScreenConstants.gridMaxCrossAxisExtent,
        childAspectRatio: _LibraryScreenConstants.gridChildAspectRatio,
        crossAxisSpacing: AppConstants.spacingL,
        mainAxisSpacing: AppConstants.spacingL,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        if (item.collection != null) {
          final collection = item.collection!;
          return BookCover(
            title: collection.name,
            subtitle: collection.description.isNotEmpty
                ? collection.description
                : null,
            imagePath: collection.coverImage,
            isFolder: true,
            onTap: () => ctrl.openCollection(collection),
            onLongPress: () => _showCollectionOptions(ctrl, collection),
          );
        } else {
          final text = item.text!;
          final unknownCount = ctrl.unknownCounts[text.id] ?? 0;
          final unknownLabel = l10n.unknownCount(unknownCount);

          return BookCover(
            title: text.title,
            subtitle: text.status == TextStatus.finished
                ? l10n.completed
                : unknownLabel,
            imagePath: text.coverImage,
            isCompleted: text.status == TextStatus.finished,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReaderScreen(
                    text: text,
                    language: widget.language,
                  ),
                ),
              ).then((_) => ctrl.recalculateUnknownCountForText(text));
            },
            onLongPress: () => _showTextOptions(ctrl, text),
          );
        }
      },
    );
  }
}

class _GridItem {
  final Collection? collection;
  final TextDocument? text;

  _GridItem({this.collection, this.text});
}
