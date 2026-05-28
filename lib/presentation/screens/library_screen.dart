import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../controllers/library_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/text_document.dart';
import '../../domain/entities/collection.dart';
import '../../services/import_export_service.dart';
import '../../services/epub_import_service.dart';
import '../widgets/library/add_text_dialog.dart';
import '../widgets/library/collection_dialog.dart';
import '../widgets/library/library_empty_state.dart';
import '../widgets/library/library_grid_content.dart';
import '../widgets/library/library_import_menu.dart';
import '../widgets/library/library_list_content.dart';
import '../widgets/library/library_search_bar.dart';
import '../widgets/library/library_status_bar.dart';
import '../widgets/library/text_edit_dialog.dart';
import '../widgets/library/url_import_dialog.dart';
import '../../utils/constants.dart';
import '../../utils/dialog_helpers.dart';
import 'reader_screen.dart';

abstract class _LibraryScreenConstants {
  static const double sortArrowIconSize = 16.0;
  static const int maxWarningsShown = 3;
  static const double fabMenuVerticalOffset = 200.0;
}

enum _LibraryAddAction { addCollection, addText, importUrl, importTxt, importEpub }

class LibraryScreen extends StatefulWidget {
  final Language language;

  const LibraryScreen({super.key, required this.language});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  final _importService = ImportExportService();
  final _focusNode = FocusNode();
  bool _showSearch = false;
  LibraryController? _ctrl;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKey);
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.keyN) return false;
    final kb = HardwareKeyboard.instance;
    if (!kb.isMetaPressed && !kb.isControlPressed) return false;
    if (!mounted || _ctrl == null) return false;
    _showAddMenuAtCenter(context, _ctrl!);
    return true;
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
    final confirm = await DialogHelpers.showDestructiveDialog(
      context,
      title: l10n.deleteText,
      message: l10n.deleteTextConfirm(text.title),
      confirmText: l10n.delete,
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

    final confirm = await DialogHelpers.showDestructiveDialog(
      context,
      title: l10n.deleteCollection,
      message: textCount > 0
          ? l10n.deleteCollectionConfirm(collection.name, textCount)
          : l10n.deleteCollectionSimple(collection.name),
      confirmText: l10n.delete,
    );
    if (confirm == true) await ctrl.deleteCollection(collection.id!);
  }

  void _onDrop(
    LibraryController ctrl,
    Object item,
    Collection? targetCollection,
  ) {
    final targetId = targetCollection?.id ?? ctrl.currentCollection?.parentId;
    if (item is TextDocument) {
      ctrl.moveText(item, targetId);
    } else if (item is Collection) {
      ctrl.moveCollection(item, targetId);
    }
  }

  Future<void> _setCoverImage(LibraryController ctrl, TextDocument text) async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      await ctrl.setCoverImage(text, result.files.single.path!);
    }
  }

  // ── Import ──

  Future<void> _importFromTextFile(LibraryController ctrl) async {
    final result = await FilePicker.pickFiles(
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
    final result = await FilePicker.pickFiles(
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

  void _showAddMenu(
    BuildContext context,
    Offset position,
    LibraryController ctrl,
  ) {
    final l10n = AppLocalizations.of(context);
    showMenu<_LibraryAddAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      items: [
        PopupMenuItem(
          value: _LibraryAddAction.importUrl,
          child: Row(
            children: [
              const Icon(Icons.link),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.importFromUrl),
            ],
          ),
        ),
        PopupMenuItem(
          value: _LibraryAddAction.importEpub,
          child: Row(
            children: [
              const Icon(Icons.book),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.importEpub),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _LibraryAddAction.addText,
          child: Row(
            children: [
              const Icon(Icons.edit),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.addText),
            ],
          ),
        ),
        PopupMenuItem(
          value: _LibraryAddAction.importTxt,
          child: Row(
            children: [
              const Icon(Icons.text_snippet),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.importTxt),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _LibraryAddAction.addCollection,
          child: Row(
            children: [
              const Icon(Icons.create_new_folder),
              const SizedBox(width: AppConstants.spacingS),
              Text(l10n.newCollection),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case _LibraryAddAction.addCollection:
          _addCollection(ctrl);
        case _LibraryAddAction.addText:
          _addText(ctrl);
        case _LibraryAddAction.importTxt:
          _importFromTextFile(ctrl);
        case _LibraryAddAction.importEpub:
          _importFromEpub(ctrl);
        case _LibraryAddAction.importUrl:
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
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
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
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
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
      child: Builder(
        builder: (context) {
          final ctrl = context.watch<LibraryController>();
          _ctrl = ctrl;
          return _buildScaffold(context, ctrl);
        },
      ),
    );
  }

  void _showAddMenuAtCenter(BuildContext context, LibraryController ctrl) {
    final size = MediaQuery.of(context).size;
    _showAddMenu(
      context,
      Offset(size.width / 2, size.height / 2),
      ctrl,
    );
  }

  Widget _buildScaffold(BuildContext context, LibraryController ctrl) {
    final l10n = AppLocalizations.of(context);
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.libraryTitle(widget.language.name)),
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
          LibraryImportMenu(
            l10n: l10n,
            onSelected: (value) {
              switch (value) {
                case LibraryImportAction.url:
                  _importFromUrl(ctrl);
                case LibraryImportAction.txt:
                  _importFromTextFile(ctrl);
                case LibraryImportAction.epub:
                  _importFromEpub(ctrl);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showSearch)
            LibrarySearchBar(
              controller: _searchController,
              hintText: l10n.searchTexts,
              onChanged: (_) => setState(() {}),
              onClear: () {
                setState(() => _searchController.clear());
              },
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
            final RenderBox button = fabContext.findRenderObject() as RenderBox;
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
    ),
  );
  }

  Widget _buildSortFilterBar(LibraryController ctrl) {
    final l10n = AppLocalizations.of(context);
    final sortedTexts = ctrl.getSortedAndFilteredTexts(_searchController.text);
    final totalTexts = ctrl.texts.length;
    final shownTexts = sortedTexts.length;
    final hiddenCount = totalTexts - shownTexts;

    return LibraryStatusBar(
      sortIcon: ctrl.sortOption.icon,
      sortLabel:
          '${ctrl.sortOption.localizedLabel(l10n)} ${ctrl.sortAscending ? '\u2191' : '\u2193'}',
      showHiddenBadge: ctrl.hideCompleted && hiddenCount > 0,
      hiddenCountLabel: l10n.completedHidden(hiddenCount),
      textCountLabel: l10n.textCount(shownTexts),
    );
  }

  Widget _buildEmptyState(LibraryController ctrl) {
    final l10n = AppLocalizations.of(context);
    return LibraryEmptyState(
      showCompletedState: ctrl.hideCompleted && ctrl.texts.isNotEmpty,
      allTextsCompletedLabel: l10n.allTextsCompleted,
      showCompletedLabel: l10n.showCompletedTexts,
      noCollectionsOrTextsLabel: l10n.noCollectionsOrTexts,
      onShowCompleted: ctrl.toggleHideCompleted,
    );
  }

  Widget _buildContentList(LibraryController ctrl) {
    final l10n = AppLocalizations.of(context);
    final sortedTexts = ctrl.getSortedAndFilteredTexts(_searchController.text);

    if (ctrl.collections.isEmpty && sortedTexts.isEmpty) {
      return _buildEmptyState(ctrl);
    }

    return LibraryListContent(
      language: widget.language,
      l10n: l10n,
      collections: ctrl.collections,
      texts: sortedTexts,
      unknownCounts: ctrl.unknownCounts,
      isInsideCollection: ctrl.currentCollection != null,
      onOpenCollection: ctrl.openCollection,
      onEditCollection: (collection) => _editCollection(ctrl, collection),
      onDeleteCollection: (collection) => _deleteCollection(ctrl, collection),
      onOpenText: (text) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderScreen(text: text, language: widget.language),
          ),
        ).then((_) => ctrl.recalculateUnknownCountForText(text));
      },
      onSetCover: (text) => _setCoverImage(ctrl, text),
      onEditText: (text) => _editText(ctrl, text),
      onDeleteText: (text) => _deleteText(ctrl, text),
      onDrop: (item, target) => _onDrop(ctrl, item, target),
    );
  }

  Widget _buildContentGrid(LibraryController ctrl) {
    final l10n = AppLocalizations.of(context);
    final sortedTexts = ctrl.getSortedAndFilteredTexts(_searchController.text);

    if (ctrl.collections.isEmpty && sortedTexts.isEmpty) {
      return _buildEmptyState(ctrl);
    }

    return LibraryGridContent(
      l10n: l10n,
      collections: ctrl.collections,
      texts: sortedTexts,
      unknownCounts: ctrl.unknownCounts,
      isInsideCollection: ctrl.currentCollection != null,
      onOpenCollection: ctrl.openCollection,
      onShowCollectionOptions: (collection) =>
          _showCollectionOptions(ctrl, collection),
      onOpenText: (text) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReaderScreen(text: text, language: widget.language),
          ),
        ).then((_) => ctrl.recalculateUnknownCountForText(text));
      },
      onShowTextOptions: (text) => _showTextOptions(ctrl, text),
      onDrop: (item, target) => _onDrop(ctrl, item, target),
    );
  }
}
