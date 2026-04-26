import 'package:flutter/foundation.dart';
import '../domain/entities/language.dart';
import '../domain/entities/text_document.dart';
import '../domain/entities/term.dart';
import '../domain/entities/word_token.dart';
import '../service_locator.dart';
import '../services/ai_explanation_service.dart';
import '../services/dictionary_service.dart';
import '../services/text_parser_service.dart';
import '../services/isolate_parser.dart';
import 'base_controller.dart';
import '../domain/value_objects/term_status.dart';

/// Info about a foreign-language term found in the text.
class ForeignTermInfo {
  final Term? term;
  final List<Translation> translations;
  final String languageName;
  final String languageId;

  const ForeignTermInfo({
    this.term,
    this.translations = const [],
    required this.languageName,
    required this.languageId,
  });
}

class ReaderController extends BaseController {
  final Language language;
  final TextParserService _textParser;
  final DictionaryService dictService;
  final AiExplanationService aiExplanationService;

  TextDocument text;
  Map<String, Term> termsMap = {};
  Map<String, Term> termsById = {};
  Map<String, List<Translation>> translationsMap = {};
  Map<String, Translation> translationsById = {};
  Map<String, ForeignTermInfo> otherLanguageTerms = {};
  List<WordToken> wordTokens = [];
  List<List<WordToken>> paragraphs = [];
  bool isLoading = true;
  bool showLegend = false;
  double fontSize = 18.0;
  final Set<int> selectedWordIndices = {};
  bool isSelectionMode = false;
  Map<int, int> termCounts = {};
  List<TextDocument>? _collectionTexts;
  int _collectionIndex = -1;
  int? _dragSelectOriginIndex;

  ReaderController({
    required this.text,
    required this.language,
    TextParserService? textParser,
    DictionaryService? dictionaryService,
    AiExplanationService? aiService,
  })  : _textParser = textParser ??
            (sl.isRegistered<TextParserService>()
                ? sl<TextParserService>()
                : TextParserService()),
        dictService = dictionaryService ?? DictionaryService(),
        aiExplanationService = aiService ?? AiExplanationService(settings: settings);

  bool get isEpubCollection => text.sourceUri.startsWith('epub://');
  bool get hasPrevInCollection => _collectionIndex > 0;
  bool get hasNextInCollection =>
      _collectionTexts != null &&
      _collectionIndex < _collectionTexts!.length - 1;
  List<TextDocument> get collectionTexts => _collectionTexts ?? [];
  int get collectionIndex => _collectionIndex;

  // ── Data loading ──

  Future<void> loadTermsAndParse() async {
    isLoading = true;
    safeNotify();

    termsMap = await db.terms.getMapByLanguage(language.id!);
    termsById = {
      for (final term in termsMap.values)
        if (term.id != null) term.id!: term,
    };

    final termIds = termsMap.values
        .where((t) => t.id != null)
        .map((t) => t.id!)
        .toList();
    translationsMap = await db.translations.getByTermIds(termIds);
    translationsById = {
      for (final translations in translationsMap.values)
        for (final t in translations)
          if (t.id != null) t.id!: t,
    };

    await _parseTextAsync();
    if (isDisposed) return;
    await _loadForeignWords();
    _updateTextTermCounts();

    isLoading = false;
    safeNotify();
    await loadCollectionTexts();
    _updateLastRead();
  }

  Future<void> _parseTextAsync() async {
    if (language.splitByCharacter && language.useWordSegmentation) {
      _parseTextWithConfiguredParser();
      return;
    }

    final termsMapData = <String, Map<String, dynamic>>{};
    for (final entry in termsMap.entries) {
      termsMapData[entry.key] = {
        'text': entry.value.text,
        'status': entry.value.status,
      };
    }

    final input = ParseInput(
      content: text.content,
      splitByCharacter: language.splitByCharacter,
      characterSubstitutions: language.characterSubstitutions,
      regexpWordCharacters: language.regexpWordCharacters,
      termsMapData: termsMapData,
    );

    final parsedTokens = await compute(parseInIsolate, input);
    if (isDisposed) return;

    wordTokens = parsedTokens.map((pt) {
      return WordToken(
        text: pt.text,
        isWord: pt.isWord,
        position: pt.position,
        term: pt.termLowerText != null ? termsMap[pt.termLowerText] : null,
      );
    }).toList();

    _groupIntoParagraphs();
  }

  void _parseTextWithConfiguredParser() {
    final content = text.content;
    final matches = _textParser.getWordMatches(content, language);
    final tokens = <WordToken>[];

    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) {
        tokens.add(
          WordToken(
            text: content.substring(lastEnd, match.start),
            isWord: false,
            position: lastEnd,
          ),
        );
      }

      final tokenText = content.substring(match.start, match.end);
      final lowerWord = _textParser.normalizeWord(match.word);
      tokens.add(
        WordToken(
          text: tokenText,
          isWord: true,
          position: match.start,
          term: termsMap[lowerWord],
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < content.length) {
      tokens.add(
        WordToken(
          text: content.substring(lastEnd),
          isWord: false,
          position: lastEnd,
        ),
      );
    }

    wordTokens = tokens;
    _groupIntoParagraphs();
  }

  Future<void> _loadForeignWords() async {
    final records = await db.textForeignWords.getByTextId(text.id!);

    if (records.isEmpty) {
      otherLanguageTerms = {};
      return;
    }

    final termIds = records
        .where((r) => r.termId != null)
        .map((r) => r.termId!)
        .toList();
    final languageIds = records.map((r) => r.languageId).toSet();

    final foreignTranslations = termIds.isNotEmpty
        ? await db.translations.getByTermIds(termIds)
        : <String, List<Translation>>{};

    final foreignTerms = <String, Term>{};
    for (final id in termIds) {
      final term = await db.terms.getById(id);
      if (term != null) foreignTerms[id] = term;
    }

    final languageNames = <String, String>{};
    for (final langId in languageIds) {
      final lang = await db.languages.getById(langId);
      languageNames[langId] = lang?.name ?? '';
    }

    final result = <String, ForeignTermInfo>{};
    for (final record in records) {
      final term = record.termId != null ? foreignTerms[record.termId!] : null;
      final translations = record.termId != null
          ? (foreignTranslations[record.termId!] ?? <Translation>[])
          : <Translation>[];
      result[record.lowerText] = ForeignTermInfo(
        term: term,
        translations: translations,
        languageName: languageNames[record.languageId] ?? '',
        languageId: record.languageId,
      );
    }

    otherLanguageTerms = result;
    _rebindWordTokens();
  }

  void _rebindWordTokens() {
    wordTokens = wordTokens.map((token) {
      if (!token.isWord) return token;

      final lowerWord = _textParser.normalizeWord(token.text);
      if (otherLanguageTerms.containsKey(lowerWord)) {
        if (token.term == null) return token;
        return WordToken(
          text: token.text,
          isWord: true,
          term: null,
          position: token.position,
        );
      }

      final mappedTerm = termsMap[lowerWord];
      if (token.term?.id == mappedTerm?.id) return token;
      return WordToken(
        text: token.text,
        isWord: true,
        term: mappedTerm,
        position: token.position,
      );
    }).toList();
    _groupIntoParagraphs();
  }

  void _groupIntoParagraphs() {
    wordTokens = [
      for (int i = 0; i < wordTokens.length; i++)
        wordTokens[i].copyWithIndex(i),
    ];

    paragraphs = [];
    List<WordToken> currentParagraph = [];

    for (final token in wordTokens) {
      if (!token.isWord && token.text.contains('\n')) {
        final nlIndex = token.text.indexOf('\n');
        final before = token.text.substring(0, nlIndex);
        final nlPart = token.text.substring(nlIndex);

        if (before.isNotEmpty) {
          currentParagraph.add(
            WordToken(
              text: before,
              isWord: false,
              globalIndex: token.globalIndex,
            ),
          );
        }

        if (currentParagraph.isNotEmpty) {
          paragraphs.add(currentParagraph);
          currentParagraph = [];
        }

        final lastNl = nlPart.lastIndexOf('\n');
        final pureNl = nlPart.substring(0, lastNl + 1);
        final after = nlPart.substring(lastNl + 1);

        currentParagraph.add(
          WordToken(
            text: pureNl,
            isWord: false,
            globalIndex: token.globalIndex,
          ),
        );
        paragraphs.add(currentParagraph);
        currentParagraph = [];

        if (after.isNotEmpty) {
          currentParagraph.add(
            WordToken(
              text: after,
              isWord: false,
              globalIndex: token.globalIndex,
            ),
          );
        }
      } else {
        currentParagraph.add(token);
      }
    }

    if (currentParagraph.isNotEmpty) {
      paragraphs.add(currentParagraph);
    }
  }

  // ── Term queries ──

  bool hasTranslations(Term term) {
    if (term.translation.isNotEmpty) return true;
    if (term.id == null) return false;
    final translations = translationsMap[term.id!];
    return translations != null && translations.isNotEmpty;
  }

  String normalizeWord(String word) => _textParser.normalizeWord(word);

  String getSentenceForPosition(int position) {
    return _textParser.getSentenceAtPosition(text.content, position, language);
  }

  void _updateTextTermCounts() {
    final counts = <int, int>{};
    final seenWords = <String>{};

    for (final token in wordTokens) {
      if (!token.isWord) continue;

      final normalized = token.text.toLowerCase();
      if (seenWords.contains(normalized)) continue;
      seenWords.add(normalized);

      if (otherLanguageTerms.containsKey(normalized)) continue;

      final term = termsMap[normalized];
      final status = term?.status ?? TermStatus.unknown;
      counts[status] = (counts[status] ?? 0) + 1;
    }

    termCounts = counts;
  }

  Future<void> _updateLastRead() async {
    final updatedText = text.copyWith(
      lastRead: DateTime.now(),
      status: text.status == TextStatus.pending
          ? TextStatus.inProgress
          : text.status,
    );
    await db.texts.update(updatedText);
    text = updatedText;
  }

  // ── Term update in-place ──

  Future<void> updateTermInPlace(Term term) async {
    final lowerText = term.lowerText;

    if (term.languageId != language.id) {
      final lang = await db.languages.getById(term.languageId);
      final termTranslations = term.id != null
          ? (await db.translations.getByTermIds([term.id!]))[term.id!] ?? []
          : <Translation>[];
      otherLanguageTerms[lowerText] = ForeignTermInfo(
        term: term,
        translations: termTranslations,
        languageName: lang?.name ?? '',
        languageId: term.languageId,
      );
      termsMap.remove(lowerText);

      await db.textForeignWords.saveWords(text.id!, term.languageId, {
        lowerText: term.id,
      });

      wordTokens = wordTokens.map((token) {
        if (token.isWord && token.text.toLowerCase() == lowerText) {
          return WordToken(
            text: token.text,
            isWord: true,
            term: null,
            position: token.position,
          );
        }
        return token;
      }).toList();
    } else {
      termsMap[lowerText] = term;

      wordTokens = wordTokens.map((token) {
        if (token.isWord && token.text.toLowerCase() == lowerText) {
          return WordToken(
            text: token.text,
            isWord: true,
            term: term,
            position: token.position,
          );
        }
        return token;
      }).toList();
    }

    _groupIntoParagraphs();
    _updateTextTermCounts();
    safeNotify();
  }

  // ── Term CRUD (called after dialog completes) ──

  Future<void> handleTermSaved(
    Term term,
    List<Translation> translations, {
    required bool isNew,
  }) async {
    if (isNew) {
      final termId = await db.terms.create(term);
      final termWithId = term.copyWith(id: termId);
      await db.translations.replaceForTerm(termId, translations);
      final newTranslations = await db.translations.getByTermId(termId);
      translationsMap[termId] = newTranslations;
      for (final t in newTranslations) {
        if (t.id != null) translationsById[t.id!] = t;
      }
      termsById[termId] = termWithId;
      await updateTermInPlace(termWithId);
      if (termWithId.languageId == language.id &&
          otherLanguageTerms.containsKey(termWithId.lowerText)) {
        await db.textForeignWords.deleteWord(text.id!, termWithId.lowerText);
        otherLanguageTerms.remove(termWithId.lowerText);
      }
    } else {
      await db.terms.update(term);
      await db.translations.replaceForTerm(term.id!, translations);
      final newTranslations = await db.translations.getByTermId(term.id!);
      translationsMap[term.id!] = newTranslations;
      for (final t in newTranslations) {
        if (t.id != null) translationsById[t.id!] = t;
      }
      await updateTermInPlace(term);
      if (term.languageId == language.id &&
          otherLanguageTerms.containsKey(term.lowerText)) {
        await db.textForeignWords.deleteWord(text.id!, term.lowerText);
        otherLanguageTerms.remove(term.lowerText);
      }
    }
  }

  Future<void> handleSelectionTermSaved(
    Term term,
    List<Translation> translations, {
    required bool isNew,
  }) async {
    cancelSelection();
    if (isNew) {
      final termId = await db.terms.create(term);
      await db.translations.replaceForTerm(termId, translations);
    } else {
      await db.terms.update(term);
      await db.translations.replaceForTerm(term.id!, translations);
    }
    final lowerWords = _textParser.normalizeWord(term.text);
    if (otherLanguageTerms.containsKey(lowerWords)) {
      await db.textForeignWords.deleteWord(text.id!, lowerWords);
    }
    await loadTermsAndParse();
  }

  // ── Selection mode ──

  void handleWordLongPress(int tokenIndex) {
    isSelectionMode = true;
    selectedWordIndices.clear();
    selectedWordIndices.add(tokenIndex);
    safeNotify();
  }

  void toggleWordSelection(int tokenIndex, {bool shiftPressed = false}) {
    if (shiftPressed && selectedWordIndices.isNotEmpty) {
      // Shift+click: select range from last selected to clicked word
      _selectRange(tokenIndex);
    } else {
      // Normal click: toggle individual word
      if (selectedWordIndices.contains(tokenIndex)) {
        selectedWordIndices.remove(tokenIndex);
        if (selectedWordIndices.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedWordIndices.add(tokenIndex);
      }
    }
    safeNotify();
  }

  void _selectRange(int endIndex) {
    // Find the last selected word index (anchor point)
    final sortedIndices = selectedWordIndices.toList()..sort();
    final anchorIndex = sortedIndices.last;

    final start = anchorIndex < endIndex ? anchorIndex : endIndex;
    final end = anchorIndex < endIndex ? endIndex : anchorIndex;

    // Add all word indices in the range
    for (int i = 0; i < wordTokens.length; i++) {
      final token = wordTokens[i];
      if (token.isWord &&
          token.globalIndex >= start &&
          token.globalIndex <= end) {
        selectedWordIndices.add(token.globalIndex);
      }
    }
  }

  /// Replaces the current selection with exactly the words in [startIndex]..[endIndex].
  void selectRange(int startIndex, int endIndex) {
    isSelectionMode = true;
    selectedWordIndices.clear();
    final lo = startIndex < endIndex ? startIndex : endIndex;
    final hi = startIndex < endIndex ? endIndex : startIndex;
    for (final token in wordTokens) {
      if (token.isWord &&
          token.globalIndex >= lo &&
          token.globalIndex <= hi) {
        selectedWordIndices.add(token.globalIndex);
      }
    }
    safeNotify();
  }

  void cancelSelection() {
    isSelectionMode = false;
    selectedWordIndices.clear();
    safeNotify();
  }

  void startDragSelect(int index) {
    _dragSelectOriginIndex = index;
  }

  void dragSelectTo(int index) {
    final origin = _dragSelectOriginIndex;
    if (origin == null || index == origin) return;
    selectRange(origin, index);
  }

  void stopDragSelect() {
    _dragSelectOriginIndex = null;
  }

  WordToken? getWordTokenByGlobalIndex(int globalIndex) {
    for (final token in wordTokens) {
      if (token.globalIndex == globalIndex) return token;
    }
    return null;
  }

  String getSelectedWordsText() {
    final selectedTokens = selectedWordIndices.toList()..sort();
    return selectedTokens
        .map(getWordTokenByGlobalIndex)
        .whereType<WordToken>()
        .map((t) => t.text)
        .join(language.splitByCharacter ? '' : ' ');
  }

  List<String> getSelectedLowerWords() {
    final selectedTokens = selectedWordIndices.toList()..sort();
    return selectedTokens
        .map(getWordTokenByGlobalIndex)
        .whereType<WordToken>()
        .map((t) => normalizeWord(t.text))
        .toSet()
        .toList();
  }

  String getSelectionSentence() {
    if (selectedWordIndices.isEmpty) return '';
    final sorted = selectedWordIndices.toList()..sort();
    final firstToken = getWordTokenByGlobalIndex(sorted.first);
    if (firstToken == null) return '';
    return getSentenceForPosition(firstToken.position);
  }

  // ── Foreign language ──

  Future<void> removeForeignMarking(String lowerWord) async {
    await db.textForeignWords.deleteWord(text.id!, lowerWord);
    otherLanguageTerms.remove(lowerWord);
    _rebindWordTokens();
    _updateTextTermCounts();
    safeNotify();
  }

  Future<void> assignForeignWords(
    String targetLanguageId,
    Map<String, String?> wordsWithTermIds,
  ) async {
    await db.textForeignWords.saveWords(
      text.id!,
      targetLanguageId,
      wordsWithTermIds,
    );
    await _loadForeignWords();
    _updateTextTermCounts();
    cancelSelection();
  }

  // ── Text actions ──

  Future<void> updateText(TextDocument updatedText) async {
    final contentChanged = updatedText.content != text.content;
    await db.texts.update(updatedText);
    text = updatedText;
    safeNotify();
    if (contentChanged) {
      await loadTermsAndParse();
    }
  }

  Future<TextStatus> markAsFinished() async {
    final newStatus = text.status == TextStatus.finished
        ? TextStatus.inProgress
        : TextStatus.finished;
    final updatedText = text.copyWith(status: newStatus);
    await db.texts.update(updatedText);
    text = updatedText;
    safeNotify();
    return newStatus;
  }

  Future<void> loadCollectionTexts() async {
    if (!isEpubCollection || text.collectionId == null) return;
    if (_collectionTexts != null) return;
    final texts = await db.texts.getByCollection(text.collectionId!);
    _collectionTexts = texts;
    _collectionIndex = texts.indexWhere((t) => t.id == text.id);
    safeNotify();
  }

  TextDocument? getPrevTextInCollection() {
    if (_collectionTexts == null || _collectionIndex <= 0) return null;
    return _collectionTexts![_collectionIndex - 1];
  }

  TextDocument? getNextTextInCollectionCached() {
    if (_collectionTexts == null ||
        _collectionIndex < 0 ||
        _collectionIndex >= _collectionTexts!.length - 1) {
      return null;
    }
    return _collectionTexts![_collectionIndex + 1];
  }

  Future<TextDocument?> getNextTextInCollection() async {
    if (text.collectionId == null) return null;
    final textsInCollection = await db.texts.getByCollection(
      text.collectionId!,
    );
    final currentIndex = textsInCollection.indexWhere((t) => t.id == text.id);
    if (currentIndex >= 0 && currentIndex < textsInCollection.length - 1) {
      return textsInCollection[currentIndex + 1];
    }
    return null;
  }

  Future<void> performMarkAllKnown() async {
    final words = _textParser.splitIntoWords(text.content, language);
    for (final word in words) {
      final lowerWord = _textParser.normalizeWord(word);
      final existingTerm = termsMap[lowerWord];
      if (existingTerm != null) {
        await db.terms.update(
          existingTerm.copyWith(status: TermStatus.wellKnown),
        );
      } else {
        await db.terms.create(
          Term(
            languageId: language.id!,
            text: word,
            lowerText: lowerWord,
            status: TermStatus.wellKnown,
          ),
        );
      }
    }
    await loadTermsAndParse();
  }

  // ── UI state ──

  void toggleLegend() {
    showLegend = !showLegend;
    safeNotify();
  }

  void setFontSize(double size) {
    fontSize = size;
    safeNotify();
  }
}
