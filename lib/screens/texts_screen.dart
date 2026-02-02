import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/collection.dart';
import '../models/term.dart';
import '../services/database_service.dart';
import '../services/import_export_service.dart';
import '../services/epub_import_service.dart';
import '../services/text_parser_service.dart';
import '../widgets/add_text_dialog.dart';
import '../widgets/book_cover.dart';
import '../widgets/collection_dialog.dart';
import '../widgets/text_edit_dialog.dart';
import '../widgets/url_import_dialog.dart';
import '../utils/constants.dart';
import 'reader_screen.dart';

abstract class _TextsScreenConstants {
  // Grid layout
  static const double gridMaxCrossAxisExtent = 140.0;
  static const double gridChildAspectRatio = 0.45;

  // Icon sizes
  static const double sortArrowIconSize = 16.0;

  // Hidden count badge vertical padding
  static const double badgeVerticalPadding = 2.0;

  // Finished text background opacity
  static const double finishedBackgroundAlpha = 0.2;

  // Max warnings shown in import result
  static const int maxWarningsShown = 3;

  // Preference keys
  static const String sortOptionKey = 'texts_sort_option';
  static const String sortAscendingKey = 'texts_sort_ascending';
  static const String hideCompletedKey = 'texts_hide_completed';
  static const String viewModeKey = 'texts_view_mode';
}

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
          prefs.getInt(_TextsScreenConstants.sortOptionKey) ?? TextSortOption.lastRead.index;
      _sortOption = TextSortOption
          .values[sortIndex.clamp(0, TextSortOption.values.length - 1)];
      _sortAscending = prefs.getBool(_TextsScreenConstants.sortAscendingKey) ?? false;
      _hideCompleted = prefs.getBool(_TextsScreenConstants.hideCompletedKey) ?? false;
      final viewModeIndex =
          prefs.getInt(_TextsScreenConstants.viewModeKey) ?? TextViewMode.list.index;
      _viewMode = TextViewMode
          .values[viewModeIndex.clamp(0, TextViewMode.values.length - 1)];
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_TextsScreenConstants.sortOptionKey, _sortOption.index);
    await prefs.setBool(_TextsScreenConstants.sortAscendingKey, _sortAscending);
    await prefs.setBool(_TextsScreenConstants.hideCompletedKey, _hideCompleted);
    await prefs.setInt(_TextsScreenConstants.viewModeKey, _viewMode.index);
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
        return t.status != TextStatus.finished;
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
    // For character-based languages, use character-based counting
    if (widget.language.splitByCharacter) {
      return _calculateUnknownCountByCharacter(text, termsMap);
    }

    final words = _textParser.splitIntoWords(text.content, widget.language);
    int unknownCount = 0;

    // Get multi-word terms sorted by length (longest first)
    final multiWordTerms =
        termsMap.entries.where((e) => e.key.contains(' ')).toList()
          ..sort((a, b) => b.key.length.compareTo(a.key.length));

    final seenWords = <String>{};
    int wordIndex = 0;

    while (wordIndex < words.length) {
      final word = words[wordIndex];
      final normalized = word.toLowerCase();

      // Check if this word starts a multi-word term
      bool isPartOfMultiWord = false;
      for (final multiWordEntry in multiWordTerms) {
        final multiWordText = multiWordEntry.key; // Already lowercase
        final multiWordParts = multiWordText.split(RegExp(r'\s+'));

        // Check if we have enough words left
        if (wordIndex + multiWordParts.length > words.length) continue;

        // Check if the next N words match this multi-word term
        bool matches = true;
        for (int i = 0; i < multiWordParts.length; i++) {
          if (words[wordIndex + i].toLowerCase() != multiWordParts[i]) {
            matches = false;
            break;
          }
        }

        if (matches) {
          // Found a multi-word term match
          if (!seenWords.contains(multiWordText)) {
            seenWords.add(multiWordText);
            final term = termsMap[multiWordText];
            if (term == null || term.status == TermStatus.unknown) {
              unknownCount++;
            }
          }
          wordIndex += multiWordParts.length;
          isPartOfMultiWord = true;
          break;
        }
      }

      if (isPartOfMultiWord) continue;

      // Single word
      if (!seenWords.contains(normalized)) {
        seenWords.add(normalized);
        final term = termsMap[normalized];
        if (term == null || term.status == TermStatus.unknown) {
          unknownCount++;
        }
      }
      wordIndex++;
    }

    return unknownCount;
  }

  int _calculateUnknownCountByCharacter(
    TextDocument text,
    Map<String, Term> termsMap,
  ) {
    final content = text.content;
    int unknownCount = 0;

    // Get multi-character terms sorted by length (longest first)
    final multiCharTerms =
        termsMap.entries.where((e) => e.key.length > 1).toList()
          ..sort((a, b) => b.key.length.compareTo(a.key.length));

    final seenWords = <String>{};
    int i = 0;

    while (i < content.length) {
      final char = content[i];

      // Skip whitespace and punctuation
      if (char.trim().isEmpty || _isPunctuation(char)) {
        i++;
        continue;
      }

      // Check if this position starts a multi-character term
      bool foundMultiCharTerm = false;
      for (final termEntry in multiCharTerms) {
        final termText = termEntry.value.text;
        final termKey = termEntry.key;
        final termLength = termText.length;

        final endIndex = i + termLength;
        if (endIndex <= content.length) {
          final substring = content.substring(i, endIndex);
          final normalizedSubstring = _textParser.normalizeWord(substring);

          if (normalizedSubstring == termKey) {
            if (!seenWords.contains(termKey)) {
              seenWords.add(termKey);
              final term = termsMap[termKey];
              if (term == null || term.status == TermStatus.unknown) {
                unknownCount++;
              }
            }
            i += termLength;
            foundMultiCharTerm = true;
            break;
          }
        }
      }

      if (foundMultiCharTerm) continue;

      // Single character
      final normalizedChar = _textParser.normalizeWord(char);
      if (!seenWords.contains(normalizedChar)) {
        seenWords.add(normalizedChar);
        final term = termsMap[normalizedChar];
        if (term == null || term.status == TermStatus.unknown) {
          unknownCount++;
        }
      }
      i++;
    }

    return unknownCount;
  }

  bool _isPunctuation(String char) {
    return RegExp(r'[\p{P}\p{S}]', unicode: true).hasMatch(char);
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
      builder: (context) => CollectionDialog(
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
      builder: (context) => AddTextDialog(
        languageId: widget.language.id!,
        collectionId: _currentCollection?.id,
      ),
    );

    if (result != null) {
      await DatabaseService.instance.createText(result);
      _loadData();
    }
  }

  Future<void> _importFromTextFile() async {
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
        parentCollectionId: _currentCollection?.id,
      );

      // Close loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      // Show success dialog
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
                ...importResult.warnings.take(_TextsScreenConstants.maxWarningsShown).map((w) => Text('\u2022 $w')),
                if (importResult.warnings.length > _TextsScreenConstants.maxWarningsShown)
                  Text('... and ${importResult.warnings.length - _TextsScreenConstants.maxWarningsShown} more'),
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

  Future<void> _importFromUrl() async {
    final result = await showDialog<TextDocument>(
      context: context,
      builder: (context) => UrlImportDialog(
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

    if (confirm == true) {
      await DatabaseService.instance.deleteText(text.id!);
      _loadData();
    }
  }

  Future<void> _editText(TextDocument text) async {
    final result = await showDialog<TextDocument>(
      context: context,
      builder: (context) => TextEditDialog(text: text),
    );

    if (result != null) {
      await DatabaseService.instance.updateText(result);
      _loadData();
    }
  }

  Future<void> _deleteCollection(Collection collection) async {
    final l10n = AppLocalizations.of(context);
    final textCount = await DatabaseService.instance.getTextCountInCollection(
      collection.id!,
    );
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
            style: TextButton.styleFrom(foregroundColor: AppConstants.deleteColor),
            child: Text(l10n.delete),
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.textsTitle(widget.language.name)),
            if (_currentCollection != null)
              Text(
                _currentCollection!.name,
                style: const TextStyle(fontSize: AppConstants.fontSizeBody),
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
                ? l10n.switchToGridView
                : l10n.switchToListView,
            onPressed: _toggleViewMode,
          ),
          // Sort button
          PopupMenuButton<TextSortOption>(
            icon: const Icon(Icons.sort),
            tooltip: l10n.sort,
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
                    const SizedBox(width: AppConstants.spacingS),
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
                        size: _TextsScreenConstants.sortArrowIconSize,
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
                ? l10n.showCompletedTexts
                : l10n.hideCompletedTexts,
            onPressed: _toggleHideCompleted,
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: l10n.newCollection,
            onPressed: _addCollection,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_upload),
            tooltip: l10n.import,
            onSelected: (value) {
              switch (value) {
                case 'txt':
                  _importFromTextFile();
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
              PopupMenuItem(
                value: 'url',
                child: Row(
                  children: [
                    const Icon(Icons.link),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.importFromUrl),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'txt',
                child: Row(
                  children: [
                    const Icon(Icons.text_snippet),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.importTxt),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'epub',
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
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchTexts,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadiusM),
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
    final l10n = AppLocalizations.of(context);
    final sortedTexts = _getSortedAndFilteredTexts(_texts);
    final totalTexts = _texts.length;
    final shownTexts = sortedTexts.length;
    final hiddenCount = totalTexts - shownTexts;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingL, vertical: AppConstants.spacingS),
      child: Row(
        children: [
          Icon(
            _sortOption.icon,
            size: _TextsScreenConstants.sortArrowIconSize,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: AppConstants.spacingXS),
          Text(
            '${_sortOption.label} ${_sortAscending ? '\u2191' : '\u2193'}',
            style: TextStyle(
              fontSize: AppConstants.fontSizeCaption,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          if (_hideCompleted && hiddenCount > 0) ...[
            const SizedBox(width: AppConstants.spacingM),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spacingS,
                vertical: _TextsScreenConstants.badgeVerticalPadding,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppConstants.borderRadiusL),
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

  Widget _buildContentList() {
    final l10n = AppLocalizations.of(context);
    final sortedTexts = _getSortedAndFilteredTexts(_texts);

    if (_collections.isEmpty && sortedTexts.isEmpty) {
      if (_hideCompleted && _texts.isNotEmpty) {
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
                onPressed: _toggleHideCompleted,
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
        // Collections first (not affected by text sorting/filtering)
        ..._collections.map(
          (collection) => Card(
            margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingL, vertical: AppConstants.spacingXS),
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
                        Text(l10n.delete),
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
          final totalLabel = widget.language.splitByCharacter
              ? l10n.charactersCount(text.characterCount)
              : l10n.wordsCount(text.wordCount);
          final unknownLabel = widget.language.splitByCharacter
              ? l10n.unknownCharacters(unknownCount)
              : l10n.unknownWords(unknownCount);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: AppConstants.spacingL, vertical: AppConstants.spacingXS),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: text.status == TextStatus.finished
                    ? AppConstants.successColor.withValues(alpha: _TextsScreenConstants.finishedBackgroundAlpha)
                    : null,
                child: Icon(
                  text.status == TextStatus.finished
                      ? Icons.check
                      : Icons.article,
                  color: text.status == TextStatus.finished
                      ? AppConstants.successColor
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
                      color: unknownCount > 0 ? AppConstants.warningColor : AppConstants.successColor,
                      fontSize: AppConstants.fontSizeCaption,
                      fontWeight: unknownCount == 0 ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
              trailing: PopupMenuButton(
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'cover',
                    child: Row(
                      children: [
                        const Icon(Icons.image),
                        const SizedBox(width: AppConstants.spacingS),
                        Text(l10n.setCover),
                      ],
                    ),
                  ),
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
                        Text(l10n.delete),
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
    final l10n = AppLocalizations.of(context);
    final sortedTexts = _getSortedAndFilteredTexts(_texts);

    if (_collections.isEmpty && sortedTexts.isEmpty) {
      if (_hideCompleted && _texts.isNotEmpty) {
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
                onPressed: _toggleHideCompleted,
                icon: const Icon(Icons.visibility),
                label: Text(l10n.showCompletedTexts),
              ),
            ],
          ),
        );
      }
      return Center(child: Text(l10n.noCollectionsOrTexts));
    }

    // Combine collections and texts into a single list for grid
    final items = <_GridItem>[
      ..._collections.map((c) => _GridItem(collection: c)),
      ...sortedTexts.map((t) => _GridItem(text: t)),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _TextsScreenConstants.gridMaxCrossAxisExtent,
        childAspectRatio: _TextsScreenConstants.gridChildAspectRatio,
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
            onTap: () => _openCollection(collection),
            onLongPress: () => _showCollectionOptions(collection),
          );
        } else {
          final text = item.text!;
          final unknownCount = _unknownCounts[text.id] ?? 0;
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
                _editCollection(collection);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppConstants.deleteColor),
              title: Text(l10n.delete, style: const TextStyle(color: AppConstants.deleteColor)),
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
                _setCoverImage(text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.edit),
              onTap: () {
                Navigator.pop(context);
                _editText(text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppConstants.deleteColor),
              title: Text(l10n.delete, style: const TextStyle(color: AppConstants.deleteColor)),
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
    final result = await FilePicker.platform.pickFiles(type: FileType.image);

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
      builder: (context) => CollectionDialog(
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

