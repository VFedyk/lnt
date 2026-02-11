import 'package:flutter/foundation.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/term.dart';
import '../models/word_token.dart';
import '../service_locator.dart';
import '../services/text_parser_service.dart';
import '../services/isolate_parser.dart';

/// Info about a foreign-language term found in the text.
class ForeignTermInfo {
  final Term? term;
  final List<Translation> translations;
  final String languageName;
  final int languageId;

  const ForeignTermInfo({
    this.term,
    this.translations = const [],
    required this.languageName,
    required this.languageId,
  });
}

class ReaderController extends ChangeNotifier {
  final Language language;
  final _textParser = TextParserService();

  TextDocument text;
  Map<String, Term> termsMap = {};
  Map<int, Term> termsById = {};
  Map<int, List<Translation>> translationsMap = {};
  Map<int, Translation> translationsById = {};
  Map<String, ForeignTermInfo> otherLanguageTerms = {};
  List<WordToken> wordTokens = [];
  List<List<WordToken>> paragraphs = [];
  bool isLoading = true;
  bool showLegend = false;
  double fontSize = 18.0;
  final Set<int> selectedWordIndices = {};
  bool isSelectionMode = false;
  Map<int, int> termCounts = {};

  bool _isDisposed = false;

  ReaderController({required this.text, required this.language});

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  // ── Data loading ──

  Future<void> loadTermsAndParse() async {
    isLoading = true;
    _safeNotify();

    termsMap = await db.terms.getMapByLanguage(language.id!);
    termsById = {
      for (final term in termsMap.values)
        if (term.id != null) term.id!: term,
    };

    final termIds =
        termsMap.values.where((t) => t.id != null).map((t) => t.id!).toList();
    translationsMap = await db.translations.getByTermIds(termIds);
    translationsById = {
      for (final translations in translationsMap.values)
        for (final t in translations)
          if (t.id != null) t.id!: t,
    };

    await _parseTextAsync();
    if (_isDisposed) return;
    await _loadForeignWords();
    _updateTextTermCounts();

    isLoading = false;
    _safeNotify();
    _updateLastRead();
  }

  Future<void> _parseTextAsync() async {
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
    if (_isDisposed) return;

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
        : <int, List<Translation>>{};

    final foreignTerms = <int, Term>{};
    for (final id in termIds) {
      final term = await db.terms.getById(id);
      if (term != null) foreignTerms[id] = term;
    }

    final languageNames = <int, String>{};
    for (final langId in languageIds) {
      final lang = await db.languages.getById(langId);
      languageNames[langId] = lang?.name ?? '';
    }

    final result = <String, ForeignTermInfo>{};
    for (final record in records) {
      final term =
          record.termId != null ? foreignTerms[record.termId!] : null;
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
  }

  void _groupIntoParagraphs() {
    wordTokens = [
      for (int i = 0; i < wordTokens.length; i++) wordTokens[i].copyWithIndex(i),
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
      status:
          text.status == TextStatus.pending ? TextStatus.inProgress : text.status,
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

      await db.textForeignWords.saveWords(
        text.id!,
        term.languageId,
        {lowerText: term.id},
      );

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
    _safeNotify();
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
      if (otherLanguageTerms.containsKey(termWithId.lowerText)) {
        await db.textForeignWords.deleteWord(text.id!, termWithId.lowerText);
        otherLanguageTerms.remove(termWithId.lowerText);
      }
      if (term.status != TermStatus.ignored &&
          term.status != TermStatus.wellKnown) {
        await db.reviewCards.getOrCreate(termId);
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
      if (otherLanguageTerms.containsKey(term.lowerText)) {
        await db.textForeignWords.deleteWord(text.id!, term.lowerText);
        otherLanguageTerms.remove(term.lowerText);
      }
      if (term.status == TermStatus.ignored ||
          term.status == TermStatus.wellKnown) {
        await db.reviewCards.deleteByTermId(term.id!);
      } else {
        await db.reviewCards.getOrCreate(term.id!);
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
      if (term.status != TermStatus.ignored &&
          term.status != TermStatus.wellKnown) {
        await db.reviewCards.getOrCreate(termId);
      }
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
    _safeNotify();
  }

  void toggleWordSelection(int tokenIndex) {
    if (selectedWordIndices.contains(tokenIndex)) {
      selectedWordIndices.remove(tokenIndex);
      if (selectedWordIndices.isEmpty) {
        isSelectionMode = false;
      }
    } else {
      selectedWordIndices.add(tokenIndex);
    }
    _safeNotify();
  }

  void cancelSelection() {
    isSelectionMode = false;
    selectedWordIndices.clear();
    _safeNotify();
  }

  String getSelectedWordsText() {
    final selectedTokens = selectedWordIndices.toList()..sort();
    return selectedTokens
        .map((i) => wordTokens[i].text)
        .join(language.splitByCharacter ? '' : ' ');
  }

  // ── Foreign language ──

  Future<void> removeForeignMarking(String lowerWord) async {
    await db.textForeignWords.deleteWord(text.id!, lowerWord);
    otherLanguageTerms.remove(lowerWord);
    _updateTextTermCounts();
    _safeNotify();
  }

  Future<void> assignForeignWords(
    int targetLanguageId,
    Map<String, int?> wordsWithTermIds,
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
    _safeNotify();
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
    _safeNotify();
    return newStatus;
  }

  Future<TextDocument?> getNextTextInCollection() async {
    if (text.collectionId == null) return null;
    final textsInCollection =
        await db.texts.getByCollection(text.collectionId!);
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
    _safeNotify();
  }

  void setFontSize(double size) {
    fontSize = size;
    _safeNotify();
  }
}
