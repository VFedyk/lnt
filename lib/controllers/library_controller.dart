import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import '../l10n/generated/app_localizations.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/collection.dart';
import '../models/term.dart';
import '../service_locator.dart';
import '../services/text_parser_service.dart';
import '../utils/cover_image_helper.dart';

/// Sorting options for texts
enum TextSortOption {
  name(Icons.sort_by_alpha),
  dateAdded(Icons.calendar_today),
  lastRead(Icons.history);

  final IconData icon;
  const TextSortOption(this.icon);

  String localizedLabel(AppLocalizations l10n) {
    switch (this) {
      case TextSortOption.name:
        return l10n.sortByName;
      case TextSortOption.dateAdded:
        return l10n.sortByDateAdded;
      case TextSortOption.lastRead:
        return l10n.sortByLastRead;
    }
  }
}

/// View mode for texts screen
enum TextViewMode { list, grid }

class LibraryController extends ChangeNotifier {
  final Language language;
  final _textParser = TextParserService();

  List<TextDocument> texts = [];
  List<Collection> collections = [];
  Collection? currentCollection;
  bool isLoading = true;

  // Sort/filter state
  TextSortOption sortOption = TextSortOption.lastRead;
  bool sortAscending = false;
  bool hideCompleted = false;
  TextViewMode viewMode = TextViewMode.list;

  // Static cache for unknown counts — persists across controller recreations.
  // Key: languageId -> (textId -> unknownCount)
  static final Map<int, Map<int, int>> unknownCountsCache = {};

  Map<int, int> get unknownCounts =>
      unknownCountsCache[language.id!] ??= {};

  bool _isDisposed = false;

  LibraryController({required this.language});

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // ── Preference keys ──

  static const _sortOptionKey = 'texts_sort_option';
  static const _sortAscendingKey = 'texts_sort_ascending';
  static const _hideCompletedKey = 'texts_hide_completed';
  static const _viewModeKey = 'texts_view_mode';

  // ── Preferences ──

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final sortIndex =
        prefs.getInt(_sortOptionKey) ?? TextSortOption.lastRead.index;
    sortOption = TextSortOption
        .values[sortIndex.clamp(0, TextSortOption.values.length - 1)];
    sortAscending = prefs.getBool(_sortAscendingKey) ?? false;
    hideCompleted = prefs.getBool(_hideCompletedKey) ?? false;
    final viewModeIndex =
        prefs.getInt(_viewModeKey) ?? TextViewMode.list.index;
    viewMode = TextViewMode
        .values[viewModeIndex.clamp(0, TextViewMode.values.length - 1)];
    _safeNotify();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sortOptionKey, sortOption.index);
    await prefs.setBool(_sortAscendingKey, sortAscending);
    await prefs.setBool(_hideCompletedKey, hideCompleted);
    await prefs.setInt(_viewModeKey, viewMode.index);
  }

  // ── Sort / filter ──

  void toggleViewMode() {
    viewMode =
        viewMode == TextViewMode.list ? TextViewMode.grid : TextViewMode.list;
    _safeNotify();
    _savePreferences();
  }

  void setSortOption(TextSortOption option) {
    if (sortOption == option) {
      sortAscending = !sortAscending;
    } else {
      sortOption = option;
      sortAscending = option == TextSortOption.name;
    }
    _safeNotify();
    _savePreferences();
  }

  void toggleHideCompleted() {
    hideCompleted = !hideCompleted;
    _safeNotify();
    _savePreferences();
  }

  List<TextDocument> getSortedAndFilteredTexts(String searchQuery) {
    final query = searchQuery.toLowerCase();
    var filtered = query.isEmpty
        ? texts.toList()
        : texts.where((t) => t.title.toLowerCase().contains(query)).toList();

    if (hideCompleted) {
      filtered = filtered
          .where((t) => t.status != TextStatus.finished)
          .toList();
    }

    filtered.sort((a, b) {
      int comparison;
      switch (sortOption) {
        case TextSortOption.name:
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case TextSortOption.dateAdded:
          comparison = a.createdAt.compareTo(b.createdAt);
        case TextSortOption.lastRead:
          comparison = a.lastRead.compareTo(b.lastRead);
      }
      return sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  // ── Data loading ──

  Future<void> loadData() async {
    isLoading = true;
    _safeNotify();

    final allCollections = await db.getCollections(
      languageId: language.id!,
      parentId: currentCollection?.id,
    );

    final allTexts = await db.getTexts(languageId: language.id!);

    final filteredTexts = currentCollection == null
        ? allTexts.where((t) => t.collectionId == null).toList()
        : allTexts
            .where((t) => t.collectionId == currentCollection!.id)
            .toList();

    collections = allCollections;
    texts = filteredTexts;
    isLoading = false;
    _safeNotify();

    _calculateUnknownCountsAsync(filteredTexts);
  }

  // ── Unknown counts ──

  Future<void> _calculateUnknownCountsAsync(List<TextDocument> texts) async {
    final textsToCalculate =
        texts.where((t) => !unknownCounts.containsKey(t.id!)).toList();
    if (textsToCalculate.isEmpty) return;

    final termsMap = await db.getTermsMap(language.id!);

    for (final text in textsToCalculate) {
      if (_isDisposed) return;
      unknownCounts[text.id!] = _calculateUnknownCount(text, termsMap);
      await Future<void>.delayed(Duration.zero);
    }

    _safeNotify();
  }

  int _calculateUnknownCount(TextDocument text, Map<String, Term> termsMap) {
    if (language.splitByCharacter) {
      return _calculateUnknownCountByCharacter(text, termsMap);
    }

    final words = _textParser.splitIntoWords(text.content, language);
    int unknownCount = 0;

    final multiWordTerms =
        termsMap.entries.where((e) => e.key.contains(' ')).toList()
          ..sort((a, b) => b.key.length.compareTo(a.key.length));

    final seenWords = <String>{};
    int wordIndex = 0;

    while (wordIndex < words.length) {
      final normalized = words[wordIndex].toLowerCase();

      bool isPartOfMultiWord = false;
      for (final multiWordEntry in multiWordTerms) {
        final multiWordText = multiWordEntry.key;
        final multiWordParts = multiWordText.split(RegExp(r'\s+'));

        if (wordIndex + multiWordParts.length > words.length) continue;

        bool matches = true;
        for (int i = 0; i < multiWordParts.length; i++) {
          if (words[wordIndex + i].toLowerCase() != multiWordParts[i]) {
            matches = false;
            break;
          }
        }

        if (matches) {
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

    final multiCharTerms =
        termsMap.entries.where((e) => e.key.length > 1).toList()
          ..sort((a, b) => b.key.length.compareTo(a.key.length));

    final seenWords = <String>{};
    int i = 0;

    while (i < content.length) {
      final char = content[i];

      if (char.trim().isEmpty || _isPunctuation(char)) {
        i++;
        continue;
      }

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

  Future<void> recalculateUnknownCountForText(TextDocument text) async {
    final termsMap = await db.getTermsMap(language.id!);
    unknownCounts[text.id!] = _calculateUnknownCount(text, termsMap);
    _safeNotify();
  }

  // ── Collection navigation ──

  Future<void> openCollection(Collection collection) async {
    currentCollection = collection;
    await loadData();
  }

  Future<void> goBack() async {
    if (currentCollection != null) {
      if (currentCollection!.parentId != null) {
        currentCollection = await db.getCollection(
          currentCollection!.parentId!,
        );
      } else {
        currentCollection = null;
      }
      await loadData();
    }
  }

  // ── CRUD ──

  Future<void> createText(TextDocument text) async {
    await db.createText(text);
    await loadData();
  }

  Future<void> updateText(TextDocument text) async {
    await db.updateText(text);
    await loadData();
  }

  Future<void> deleteText(int textId) async {
    await db.deleteText(textId);
    await loadData();
  }

  Future<void> createCollection(Collection collection) async {
    await db.createCollection(collection);
    await loadData();
  }

  Future<void> updateCollection(Collection collection) async {
    await db.updateCollection(collection);
    await loadData();
  }

  Future<void> deleteCollection(int collectionId) async {
    await db.deleteCollection(collectionId);
    await loadData();
  }

  Future<int> getTextCountInCollection(int collectionId) async {
    return db.getTextCountInCollection(collectionId);
  }

  Future<void> setCoverImage(TextDocument text, String sourcePath) async {
    final sourceFile = File(sourcePath);
    final appDir = await getApplicationDocumentsDirectory();
    final coversDir = Directory(p.join(appDir.path, 'covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    final extension = p.extension(sourcePath);
    final newFileName = '${DateTime.now().millisecondsSinceEpoch}$extension';
    final newPath = p.join(coversDir.path, newFileName);

    await sourceFile.copy(newPath);

    final updatedText =
        text.copyWith(coverImage: CoverImageHelper.toRelative(newPath));
    await db.updateText(updatedText);
    await loadData();
  }
}
