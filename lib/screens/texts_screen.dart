import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/collection.dart';
import '../models/term.dart';
import '../services/database_service.dart';
import '../services/import_export_service.dart';
import '../services/epub_import_service.dart';
import '../services/url_import_service.dart';
import '../services/text_parser_service.dart';
import '../widgets/book_cover.dart';
import 'reader_screen.dart';

/// Sorting options for texts
enum TextSortOption {
  name('Name', Icons.sort_by_alpha),
  dateAdded('Date Added', Icons.calendar_today),
  lastRead('Last Read', Icons.history);

  final String label;
  final IconData icon;
  const TextSortOption(this.label, this.icon);
}

/// View mode for texts screen
enum TextViewMode { list, grid }

class TextsScreen extends StatefulWidget {
  final Language language;

  const TextsScreen({super.key, required this.language});

  @override
  State<TextsScreen> createState() => _TextsScreenState();
}

class _TextsScreenState extends State<TextsScreen> {
  List<TextDocument> _texts = [];
  List<Collection> _collections = [];
  Collection? _currentCollection;
  bool _isLoading = true;
  final _searchController = TextEditingController();
  final _importService = ImportExportService();
  final _textParser = TextParserService();

  // Sorting and filtering state
  TextSortOption _sortOption = TextSortOption.lastRead;
  bool _sortAscending = false;
  bool _hideCompleted = false; // Hide texts with 0 unknown words
  TextViewMode _viewMode = TextViewMode.list;

  // Preference keys
  static const String _sortOptionKey = 'texts_sort_option';
  static const String _sortAscendingKey = 'texts_sort_ascending';
  static const String _hideCompletedKey = 'texts_hide_completed';
  static const String _viewModeKey = 'texts_view_mode';

  // Static cache for unknown counts - persists across folder navigations
  // Key: languageId -> (textId -> unknownCount)
  static final Map<int, Map<int, int>> _unknownCountsCache = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences().then((_) => _loadData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<int, int> get _unknownCounts {
    return _unknownCountsCache[widget.language.id!] ??= {};
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final sortIndex =
          prefs.getInt(_sortOptionKey) ?? TextSortOption.lastRead.index;
      _sortOption = TextSortOption
          .values[sortIndex.clamp(0, TextSortOption.values.length - 1)];
      _sortAscending = prefs.getBool(_sortAscendingKey) ?? false;
      _hideCompleted = prefs.getBool(_hideCompletedKey) ?? false;
      final viewModeIndex = prefs.getInt(_viewModeKey) ?? TextViewMode.list.index;
      _viewMode = TextViewMode
          .values[viewModeIndex.clamp(0, TextViewMode.values.length - 1)];
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sortOptionKey, _sortOption.index);
    await prefs.setBool(_sortAscendingKey, _sortAscending);
    await prefs.setBool(_hideCompletedKey, _hideCompleted);
    await prefs.setInt(_viewModeKey, _viewMode.index);
  }

  void _toggleViewMode() {
    setState(() {
      _viewMode = _viewMode == TextViewMode.list
          ? TextViewMode.grid
          : TextViewMode.list;
    });
    _savePreferences();
  }

  void _setSortOption(TextSortOption option) {
    setState(() {
      if (_sortOption == option) {
        // Toggle direction if same option selected
        _sortAscending = !_sortAscending;
      } else {
        _sortOption = option;
        // Default direction based on sort type
        _sortAscending = option == TextSortOption.name;
      }
    });
    _savePreferences();
  }

  void _toggleHideCompleted() {
    setState(() {
      _hideCompleted = !_hideCompleted;
    });
    _savePreferences();
  }

  List<TextDocument> _getSortedAndFilteredTexts(List<TextDocument> texts) {
    // First filter by search query
    final query = _searchController.text.toLowerCase();
    var filtered = query.isEmpty
        ? texts
        : texts.where((t) => t.title.toLowerCase().contains(query)).toList();

    // Then filter by completion status
    if (_hideCompleted) {
      filtered = filtered.where((t) {
        final unknownCount = _unknownCounts[t.id] ?? 0;
        return unknownCount > 0;
      }).toList();
    }

    // Finally sort
    filtered.sort((a, b) {
      int comparison;
      switch (_sortOption) {
        case TextSortOption.name:
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case TextSortOption.dateAdded:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
        case TextSortOption.lastRead:
          comparison = a.lastRead.compareTo(b.lastRead);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final collections = await DatabaseService.instance.getCollections(
      languageId: widget.language.id!,
      parentId: _currentCollection?.id,
    );

    final texts = await DatabaseService.instance.getTexts(
      languageId: widget.language.id!,
    );

    // Filter texts by current collection
    final filteredTexts = _currentCollection == null
        ? texts.where((t) => t.collectionId == null).toList()
        : texts.where((t) => t.collectionId == _currentCollection!.id).toList();

    // Find texts that need unknown count calculation (not in cache)
    final textsToCalculate = filteredTexts
        .where((t) => !_unknownCounts.containsKey(t.id!))
        .toList();

    // Only load terms map if we have texts to calculate
    if (textsToCalculate.isNotEmpty) {
      final termsMap = await DatabaseService.instance.getTermsMap(
        widget.language.id!,
      );

      // Calculate unknown counts only for texts not in cache
      for (final text in textsToCalculate) {
        _unknownCounts[text.id!] = _calculateUnknownCount(text, termsMap);
      }
    }

    setState(() {
      _collections = collections;
      _texts = filteredTexts;
      _isLoading = false;
    });
  }

  int _calculateUnknownCount(TextDocument text, Map<String, Term> termsMap) {
    final words = _textParser.splitIntoWords(text.content, widget.language);
    int unknownCount = 0;

    final seenWords = <String>{};
    for (final word in words) {
      final normalized = word.toLowerCase();
      if (seenWords.contains(normalized)) continue;
      seenWords.add(normalized);

      final term = termsMap[normalized];
      // Count as unknown if no term exists or status is Unknown
      if (term == null || term.status == TermStatus.unknown) {
        unknownCount++;
      }
    }

    return unknownCount;
  }

  Future<void> _recalculateUnknownCountForText(TextDocument text) async {
    final termsMap = await DatabaseService.instance.getTermsMap(
      widget.language.id!,
    );
    final newCount = _calculateUnknownCount(text, termsMap);
    setState(() {
      _unknownCounts[text.id!] = newCount;
    });
  }

  Future<void> _openCollection(Collection collection) async {
    setState(() => _currentCollection = collection);
    await _loadData();
  }

  Future<void> _goBack() async {
    if (_currentCollection != null) {
      if (_currentCollection!.parentId != null) {
        final parent = await DatabaseService.instance.getCollection(
          _currentCollection!.parentId!,
        );
        setState(() => _currentCollection = parent);
      } else {
        setState(() => _currentCollection = null);
      }
      await _loadData();
    }
  }

  Future<void> _addCollection() async {
    final result = await showDialog<Collection>(
      context: context,
      builder: (context) => _CollectionDialog(
        languageId: widget.language.id!,
        parentId: _currentCollection?.id,
      ),
    );

    if (result != null) {
      await DatabaseService.instance.createCollection(result);
      _loadData();
    }
  }

  Future<void> _addText() async {
    final result = await showDialog<TextDocument>(
      context: context,
      builder: (context) => _AddTextDialog(
        languageId: widget.language.id!,
        collectionId: _currentCollection?.id,
      ),
    );

    if (result != null) {
      await DatabaseService.instance.createText(result);
      _loadData();
    }
  }

  Future<void> _importFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
    );

    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      final content = await _importService.readTextFile(File(file.path!));

      final text = TextDocument(
        languageId: widget.language.id!,
        collectionId: _currentCollection?.id,
        title: file.name.replaceAll('.txt', ''),
        content: _importService.cleanTextForImport(content),
      );

      await DatabaseService.instance.createText(text);
      _loadData();
    }
  }

  Future<void> _importFromEpub() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub'],
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    final file = result.files.single;

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Importing EPUB...')),
          ],
        ),
      ),
    );

    try {
      final epubService = EpubImportService();
      final importResult = await epubService.importEpub(
        epubBytes: file.bytes!,
        languageId: widget.language.id!,
        parentCollectionId: _currentCollection?.id,
      );

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // Show success dialog
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Complete'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Book: ${importResult.bookTitle}'),
              if (importResult.author != null)
                Text('Author: ${importResult.author}'),
              Text('Chapters: ${importResult.totalChapters}'),
              if (importResult.totalParts > importResult.totalChapters)
                Text('Total parts: ${importResult.totalParts}'),
              Text('Characters: ${importResult.totalCharacters}'),
              if (importResult.warnings.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...importResult.warnings.take(3).map((w) => Text('• $w')),
                if (importResult.warnings.length > 3)
                  Text('... and ${importResult.warnings.length - 3} more'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      _loadData();
    } catch (e) {
      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Failed'),
          content: Text('Could not import EPUB: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _importFromUrl() async {
    final result = await showDialog<TextDocument>(
      context: context,
      builder: (context) => _UrlImportDialog(
        languageId: widget.language.id!,
        collectionId: _currentCollection?.id,
      ),
    );

    if (result != null) {
      await DatabaseService.instance.createText(result);
      _loadData();
    }
  }

  Future<void> _deleteText(TextDocument text) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Text?'),
        content: Text('Delete "${text.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteText(text.id!);
      _loadData();
    }
  }

  Future<void> _editText(TextDocument text) async {
    final result = await showDialog<TextDocument>(
      context: context,
      builder: (context) => _EditTextDialog(text: text),
    );

    if (result != null) {
      await DatabaseService.instance.updateText(result);
      _loadData();
    }
  }

  Future<void> _deleteCollection(Collection collection) async {
    final textCount = await DatabaseService.instance.getTextCountInCollection(
      collection.id!,
    );

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: Text(
          textCount > 0
              ? 'Delete "${collection.name}" and its $textCount text(s)?'
              : 'Delete "${collection.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseService.instance.deleteCollection(collection.id!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Texts - ${widget.language.name}'),
            if (_currentCollection != null)
              Text(
                _currentCollection!.name,
                style: const TextStyle(fontSize: 14),
              ),
          ],
        ),
        leading: _currentCollection != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goBack)
            : null,
        actions: [
          // View mode toggle
          IconButton(
            icon: Icon(
              _viewMode == TextViewMode.list ? Icons.grid_view : Icons.list,
            ),
            tooltip: _viewMode == TextViewMode.list
                ? 'Switch to grid view'
                : 'Switch to list view',
            onPressed: _toggleViewMode,
          ),
          // Sort button
          PopupMenuButton<TextSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: _setSortOption,
            itemBuilder: (context) => TextSortOption.values.map((option) {
              final isSelected = _sortOption == option;
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        option.label,
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
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
          // Filter button
          IconButton(
            icon: Icon(
              _hideCompleted ? Icons.visibility_off : Icons.visibility,
              color: _hideCompleted
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: _hideCompleted
                ? 'Show completed texts'
                : 'Hide completed texts',
            onPressed: _toggleHideCompleted,
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: 'New Collection',
            onPressed: _addCollection,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import',
            onSelected: (value) {
              switch (value) {
                case 'txt':
                  _importFromFile();
                  break;
                case 'epub':
                  _importFromEpub();
                  break;
                case 'url':
                  _importFromUrl();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'url',
                child: Row(
                  children: [
                    Icon(Icons.link),
                    SizedBox(width: 8),
                    Text('Import from URL'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'txt',
                child: Row(
                  children: [
                    Icon(Icons.text_snippet),
                    SizedBox(width: 8),
                    Text('Import TXT'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'epub',
                child: Row(
                  children: [
                    Icon(Icons.book),
                    SizedBox(width: 8),
                    Text('Import EPUB'),
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
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search texts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Sort/Filter info bar
          _buildSortFilterBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _viewMode == TextViewMode.list
                    ? _buildContentList()
                    : _buildContentGrid(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addText,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSortFilterBar() {
    final sortedTexts = _getSortedAndFilteredTexts(_texts);
    final totalTexts = _texts.length;
    final shownTexts = sortedTexts.length;
    final hiddenCount = totalTexts - shownTexts;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            _sortOption.icon,
            size: 16,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 4),
          Text(
            '${_sortOption.label} ${_sortAscending ? '↑' : '↓'}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          if (_hideCompleted && hiddenCount > 0) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$hiddenCount completed hidden',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
          const Spacer(),
          Text(
            '$shownTexts text${shownTexts == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentList() {
    final sortedTexts = _getSortedAndFilteredTexts(_texts);

    if (_collections.isEmpty && sortedTexts.isEmpty) {
      if (_hideCompleted && _texts.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'All texts completed!',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _toggleHideCompleted,
                icon: const Icon(Icons.visibility),
                label: const Text('Show completed texts'),
              ),
            ],
          ),
        );
      }
      return const Center(child: Text('No collections or texts'));
    }

    return ListView(
      children: [
        // Collections first (not affected by text sorting/filtering)
        ..._collections.map(
          (collection) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.folder)),
              title: Tooltip(
                message: collection.name,
                child: Text(
                  collection.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              subtitle: collection.description.isNotEmpty
                  ? Text(collection.description)
                  : null,
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'edit') {
                    _editCollection(collection);
                  } else if (value == 'delete') {
                    _deleteCollection(collection);
                  }
                },
              ),
              onTap: () => _openCollection(collection),
            ),
          ),
        ),

        // Then texts (sorted and filtered)
        ...sortedTexts.map((text) {
          final unknownCount = _unknownCounts[text.id] ?? 0;
          final totalLabel = text.getCountLabel(
            widget.language.splitByCharacter,
          );
          final unknownLabel = widget.language.splitByCharacter
              ? '$unknownCount unknown characters'
              : '$unknownCount unknown words';

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: unknownCount == 0
                    ? Colors.green.withOpacity(0.2)
                    : null,
                child: Icon(
                  unknownCount == 0 ? Icons.check : Icons.article,
                  color: unknownCount == 0 ? Colors.green : null,
                ),
              ),
              title: Tooltip(
                message: text.title,
                child: Text(
                  text.title,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(totalLabel),
                  Text(
                    unknownCount == 0 ? 'Completed!' : unknownLabel,
                    style: TextStyle(
                      color: unknownCount > 0 ? Colors.orange : Colors.green,
                      fontSize: 12,
                      fontWeight: unknownCount == 0 ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'cover',
                    child: Row(
                      children: [
                        Icon(Icons.image),
                        SizedBox(width: 8),
                        Text('Set Cover'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'cover') {
                    _setCoverImage(text);
                  } else if (value == 'edit') {
                    _editText(text);
                  } else if (value == 'delete') {
                    _deleteText(text);
                  }
                },
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ReaderScreen(text: text, language: widget.language),
                  ),
                ).then((_) => _recalculateUnknownCountForText(text));
              },
            ),
          );
        }),
      ],
    );
  }

  Widget _buildContentGrid() {
    final sortedTexts = _getSortedAndFilteredTexts(_texts);

    if (_collections.isEmpty && sortedTexts.isEmpty) {
      if (_hideCompleted && _texts.isNotEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'All texts completed!',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _toggleHideCompleted,
                icon: const Icon(Icons.visibility),
                label: const Text('Show completed texts'),
              ),
            ],
          ),
        );
      }
      return const Center(child: Text('No collections or texts'));
    }

    // Combine collections and texts into a single list for grid
    final items = <_GridItem>[
      ..._collections.map((c) => _GridItem(collection: c)),
      ...sortedTexts.map((t) => _GridItem(text: t)),
    ];

    // Max cover height: 256px with 2:3 aspect ratio = ~170px width
    // Plus ~50px for title/subtitle text
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        childAspectRatio: 0.45,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
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
            onTap: () => _openCollection(collection),
            onLongPress: () => _showCollectionOptions(collection),
          );
        } else {
          final text = item.text!;
          final unknownCount = _unknownCounts[text.id] ?? 0;
          final unknownLabel = widget.language.splitByCharacter
              ? '$unknownCount unknown'
              : '$unknownCount unknown';

          return BookCover(
            title: text.title,
            subtitle: unknownCount == 0 ? 'Completed!' : unknownLabel,
            imagePath: text.coverImage,
            isCompleted: unknownCount == 0,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ReaderScreen(text: text, language: widget.language),
                ),
              ).then((_) => _recalculateUnknownCountForText(text));
            },
            onLongPress: () => _showTextOptions(text),
          );
        }
      },
    );
  }

  void _showCollectionOptions(Collection collection) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editCollection(collection);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteCollection(collection);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showTextOptions(TextDocument text) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Set Cover'),
              onTap: () {
                Navigator.pop(context);
                _setCoverImage(text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _editText(text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteText(text);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setCoverImage(TextDocument text) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      final sourcePath = result.files.single.path!;
      final sourceFile = File(sourcePath);

      // Copy to app's documents directory for persistent access
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      // Generate unique filename using timestamp
      final extension = p.extension(sourcePath);
      final newFileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
      final newPath = p.join(coversDir.path, newFileName);

      await sourceFile.copy(newPath);

      final updatedText = text.copyWith(coverImage: newPath);
      await DatabaseService.instance.updateText(updatedText);
      _loadData();
    }
  }

  Future<void> _editCollection(Collection collection) async {
    final result = await showDialog<Collection>(
      context: context,
      builder: (context) => _CollectionDialog(
        languageId: widget.language.id!,
        parentId: collection.parentId,
        existingCollection: collection,
      ),
    );

    if (result != null) {
      await DatabaseService.instance.updateCollection(result);
      _loadData();
    }
  }
}

class _GridItem {
  final Collection? collection;
  final TextDocument? text;

  _GridItem({this.collection, this.text});
}

class _CollectionDialog extends StatefulWidget {
  final int languageId;
  final int? parentId;
  final Collection? existingCollection;

  const _CollectionDialog({
    required this.languageId,
    this.parentId,
    this.existingCollection,
  });

  bool get isEditing => existingCollection != null;

  @override
  State<_CollectionDialog> createState() => _CollectionDialogState();
}

class _CollectionDialogState extends State<_CollectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _coverImagePath;

  @override
  void initState() {
    super.initState();
    if (widget.existingCollection != null) {
      _nameController.text = widget.existingCollection!.name;
      _descriptionController.text = widget.existingCollection!.description;
      _coverImagePath = widget.existingCollection!.coverImage;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      final sourcePath = result.files.single.path!;
      final sourceFile = File(sourcePath);

      // Copy to app's documents directory for persistent access
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      // Generate unique filename using timestamp
      final extension = p.extension(sourcePath);
      final newFileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
      final newPath = p.join(coversDir.path, newFileName);

      await sourceFile.copy(newPath);

      setState(() {
        _coverImagePath = newPath;
      });
    }
  }

  void _removeCoverImage() {
    setState(() {
      _coverImagePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEditing ? 'Edit Collection' : 'New Collection'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cover image picker
              GestureDetector(
                onTap: _pickCoverImage,
                child: Container(
                  width: 100,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                    image: _coverImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_coverImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _coverImagePath == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 32, color: Colors.grey[600]),
                            const SizedBox(height: 4),
                            Text(
                              'Add Cover',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              if (_coverImagePath != null)
                TextButton(
                  onPressed: _removeCoverImage,
                  child: const Text('Remove Cover'),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
                autofocus: !widget.isEditing,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final collection = widget.isEditing
                  ? widget.existingCollection!.copyWith(
                      name: _nameController.text,
                      description: _descriptionController.text,
                      coverImage: _coverImagePath,
                      clearCoverImage: _coverImagePath == null &&
                          widget.existingCollection!.coverImage != null,
                    )
                  : Collection(
                      languageId: widget.languageId,
                      parentId: widget.parentId,
                      name: _nameController.text,
                      description: _descriptionController.text,
                      coverImage: _coverImagePath,
                    );
              Navigator.pop(context, collection);
            }
          },
          child: Text(widget.isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _AddTextDialog extends StatefulWidget {
  final int languageId;
  final int? collectionId;

  const _AddTextDialog({required this.languageId, this.collectionId});

  @override
  State<_AddTextDialog> createState() => _AddTextDialogState();
}

class _AddTextDialogState extends State<_AddTextDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Text'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Text Content',
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final text = TextDocument(
                languageId: widget.languageId,
                collectionId: widget.collectionId,
                title: _titleController.text,
                content: _contentController.text,
              );
              Navigator.pop(context, text);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _EditTextDialog extends StatefulWidget {
  final TextDocument text;

  const _EditTextDialog({required this.text});

  @override
  State<_EditTextDialog> createState() => _EditTextDialogState();
}

class _EditTextDialogState extends State<_EditTextDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  String? _coverImagePath;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.text.title);
    _contentController = TextEditingController(text: widget.text.content);
    _coverImagePath = widget.text.coverImage;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      final sourcePath = result.files.single.path!;
      final sourceFile = File(sourcePath);

      // Copy to app's documents directory for persistent access
      final appDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(p.join(appDir.path, 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      // Generate unique filename using timestamp
      final extension = p.extension(sourcePath);
      final newFileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
      final newPath = p.join(coversDir.path, newFileName);

      await sourceFile.copy(newPath);

      setState(() {
        _coverImagePath = newPath;
      });
    }
  }

  void _removeCoverImage() {
    setState(() {
      _coverImagePath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Text'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cover image picker
              GestureDetector(
                onTap: _pickCoverImage,
                child: Container(
                  width: 100,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[400]!),
                    image: _coverImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_coverImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _coverImagePath == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 32, color: Colors.grey[600]),
                            const SizedBox(height: 4),
                            Text(
                              'Add Cover',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              if (_coverImagePath != null)
                TextButton(
                  onPressed: _removeCoverImage,
                  child: const Text('Remove Cover'),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Text Content',
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final updatedText = widget.text.copyWith(
                title: _titleController.text,
                content: _contentController.text,
                coverImage: _coverImagePath,
                clearCoverImage: _coverImagePath == null &&
                    widget.text.coverImage != null,
              );
              Navigator.pop(context, updatedText);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _UrlImportDialog extends StatefulWidget {
  final int languageId;
  final int? collectionId;

  const _UrlImportDialog({required this.languageId, this.collectionId});

  @override
  State<_UrlImportDialog> createState() => _UrlImportDialogState();
}

class _UrlImportDialogState extends State<_UrlImportDialog> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _urlImportService = UrlImportService();

  bool _isLoading = false;
  bool _isFetched = false;
  String? _error;
  String _content = '';
  String? _coverImagePath;

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _fetchUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter a URL');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _urlImportService.importFromUrl(url);
      setState(() {
        _titleController.text = result.title;
        _content = result.content;
        _coverImagePath = result.coverImagePath;
        _isFetched = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _import() {
    if (_titleController.text.isEmpty) {
      setState(() => _error = 'Please enter a title');
      return;
    }

    final text = TextDocument(
      languageId: widget.languageId,
      collectionId: widget.collectionId,
      title: _titleController.text,
      content: _content,
      sourceUri: _urlController.text.trim(),
      coverImage: _coverImagePath,
    );
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import from URL'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: 'URL',
                  hintText: 'https://example.com/article',
                  prefixIcon: const Icon(Icons.link),
                  suffixIcon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.download),
                          tooltip: 'Fetch content',
                          onPressed: _fetchUrl,
                        ),
                ),
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _fetchUrl(),
                enabled: !_isLoading,
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (_isFetched) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Preview',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Container(
                  height: 200,
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _content,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_content.split(RegExp(r'\\s+')).length} words',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (_isFetched)
          TextButton(
            onPressed: _import,
            child: const Text('Import'),
          ),
      ],
    );
  }
}
