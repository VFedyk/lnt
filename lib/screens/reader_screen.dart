import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/term.dart';
import '../models/dictionary.dart';
import '../models/word_token.dart';
import '../services/database_service.dart';
import '../services/dictionary_service.dart';
import '../services/text_parser_service.dart';
import '../services/isolate_parser.dart';
import '../widgets/term_dialog.dart';
import '../widgets/status_legend.dart';
import '../widgets/edit_text_dialog.dart';
import '../widgets/word_list_drawer.dart';
import '../widgets/paragraph_rich_text.dart';
import '../utils/constants.dart';

/// Layout, sizing, and timing constants for the reader screen
abstract class _ReaderScreenConstants {
  // Font sizes
  static const double defaultFontSize = 18.0;
  static const double fontSizeMin = 12.0;
  static const double fontSizeMax = 32.0;
  static const int fontSizeSliderDivisions = 20;

  // Icon sizes
  static const double editIconSize = 18.0;

  // Selection mode colors
  static const Color selectionBannerColor = Color(0xFFBBDEFB);
  static const Color selectionAccentColor = Colors.blue;
}

class ReaderScreen extends StatefulWidget {
  final TextDocument text;
  final Language language;

  const ReaderScreen({super.key, required this.text, required this.language});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _scrollController = ScrollController();
  final _textParser = TextParserService();
  final _dictService = DictionaryService();

  late TextDocument _text;
  Map<String, Term> _termsMap = {};
  Map<int, Term> _termsById = {};
  Map<int, List<Translation>> _translationsMap = {};
  Map<int, Translation> _translationsById = {};
  Map<String, ({Term term, String languageName})> _otherLanguageTerms = {};
  List<WordToken> _wordTokens = [];
  List<List<WordToken>> _paragraphs = [];
  bool _isLoading = true;
  bool _showLegend = false;
  double _fontSize = _ReaderScreenConstants.defaultFontSize;

  // Multi-word selection state
  final Set<int> _selectedWordIndices = {};
  bool _isSelectionMode = false;

  // Term counts by status
  Map<int, int> _termCounts = {};

  // Sidebar
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    _text = widget.text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_loadScheduled) {
        _loadScheduled = true;
        _waitForAnimationAndLoad();
      }
    });
  }

  void _waitForAnimationAndLoad() {
    final route = ModalRoute.of(context);
    final animation = route?.animation;

    if (animation == null || animation.isCompleted) {
      _loadTermsAndParse();
    } else {
      void onComplete(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          animation.removeStatusListener(onComplete);
          if (mounted) _loadTermsAndParse();
        }
      }

      animation.addStatusListener(onComplete);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // --- Data loading & parsing ---

  Future<void> _loadTermsAndParse() async {
    if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      _termsMap = await DatabaseService.instance.getTermsMap(
        widget.language.id!,
      );
      // Build termsById map for looking up base terms
      _termsById = {
        for (final term in _termsMap.values)
          if (term.id != null) term.id!: term,
      };
      // Preload translations for all terms
      final termIds = _termsMap.values.where((t) => t.id != null).map((t) => t.id!).toList();
      _translationsMap = await DatabaseService.instance.translations.getByTermIds(termIds);
      // Build translationsById map for looking up base translations
      _translationsById = {
        for (final translations in _translationsMap.values)
          for (final t in translations)
            if (t.id != null) t.id!: t,
      };

      await _parseTextAsync();
      await _loadOtherLanguageWords();
      _updateTextTermCounts();

      setState(() => _isLoading = false);
      _updateLastRead();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorLoadingTerms(e.toString()))),
        );
      }
    }
  }

  Future<void> _updateLastRead() async {
    final updatedText = _text.copyWith(
      lastRead: DateTime.now(),
      status: _text.status == TextStatus.pending
          ? TextStatus.inProgress
          : _text.status,
    );
    await DatabaseService.instance.updateText(updatedText);
    _text = updatedText;
  }

  bool _hasTranslations(Term term) {
    if (term.translation.isNotEmpty) return true;
    if (term.id == null) return false;
    final translations = _translationsMap[term.id!];
    return translations != null && translations.isNotEmpty;
  }

  void _updateTextTermCounts() {
    final counts = <int, int>{};
    final seenWords = <String>{};

    for (final token in _wordTokens) {
      if (!token.isWord) continue;

      final normalized = token.text.toLowerCase();
      if (seenWords.contains(normalized)) continue;
      seenWords.add(normalized);

      if (_otherLanguageTerms.containsKey(normalized)) continue;

      final term = _termsMap[normalized];
      final status = term?.status ?? TermStatus.unknown;
      counts[status] = (counts[status] ?? 0) + 1;
    }

    _termCounts = counts;
  }

  Future<void> _updateTermInPlace(Term term) async {
    final lowerText = term.lowerText;

    if (term.languageId != widget.language.id) {
      final lang = await DatabaseService.instance.getLanguage(term.languageId);
      _otherLanguageTerms[lowerText] = (
        term: term,
        languageName: lang?.name ?? '',
      );
      _termsMap.remove(lowerText);

      _wordTokens = _wordTokens.map((token) {
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
      _termsMap[lowerText] = term;

      _wordTokens = _wordTokens.map((token) {
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
    setState(() {});
  }

  Future<void> _parseTextAsync() async {
    final termsMapData = <String, Map<String, dynamic>>{};
    for (final entry in _termsMap.entries) {
      termsMapData[entry.key] = {
        'text': entry.value.text,
        'status': entry.value.status,
      };
    }

    final input = ParseInput(
      content: _text.content,
      splitByCharacter: widget.language.splitByCharacter,
      characterSubstitutions: widget.language.characterSubstitutions,
      regexpWordCharacters: widget.language.regexpWordCharacters,
      termsMapData: termsMapData,
    );

    final parsedTokens = await compute(parseInIsolate, input);

    if (!mounted) return;

    _wordTokens = parsedTokens.map((pt) {
      return WordToken(
        text: pt.text,
        isWord: pt.isWord,
        position: pt.position,
        term: pt.termLowerText != null ? _termsMap[pt.termLowerText] : null,
      );
    }).toList();

    _groupIntoParagraphs();
  }

  Future<void> _loadOtherLanguageWords() async {
    final wordsToCheck = <String>{};
    for (final token in _wordTokens) {
      if (token.isWord) {
        final lowerWord = token.text.toLowerCase();
        if (!_termsMap.containsKey(lowerWord)) {
          wordsToCheck.add(lowerWord);
        }
      }
    }

    if (wordsToCheck.isEmpty) {
      _otherLanguageTerms = {};
      return;
    }

    _otherLanguageTerms = await DatabaseService.instance
        .getTermsInOtherLanguages(widget.language.id!, wordsToCheck);
  }

  void _groupIntoParagraphs() {
    _wordTokens = [
      for (int i = 0; i < _wordTokens.length; i++)
        _wordTokens[i].copyWithIndex(i),
    ];

    _paragraphs = [];
    List<WordToken> currentParagraph = [];

    for (final token in _wordTokens) {
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
          _paragraphs.add(currentParagraph);
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
        _paragraphs.add(currentParagraph);
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
      _paragraphs.add(currentParagraph);
    }
  }

  // --- Word interaction ---

  Future<void> _handleWordTap(String word, int position, int tokenIndex) async {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedWordIndices.contains(tokenIndex)) {
          _selectedWordIndices.remove(tokenIndex);
          if (_selectedWordIndices.isEmpty) {
            _isSelectionMode = false;
          }
        } else {
          _selectedWordIndices.add(tokenIndex);
        }
      });
      return;
    }

    final lowerWord = _textParser.normalizeWord(word);
    final existingTerm = _termsMap[lowerWord];

    if (existingTerm != null && _hasTranslations(existingTerm)) {
      final shouldEdit = await _showTranslationPopup(existingTerm);
      if (shouldEdit == true) {
        await _openTermDialog(word, position, existingTerm);
      }
      return;
    }

    await _openTermDialog(word, position, existingTerm);
  }

  Future<bool?> _showTranslationPopup(Term term) async {
    final l10n = AppLocalizations.of(context);
    // Load translations for this term
    List<Translation> translations = [];
    if (term.id != null) {
      translations = await DatabaseService.instance.translations.getByTermId(term.id!);
    }
    // If no translations in new table, use legacy translation field
    if (translations.isEmpty && term.translation.isNotEmpty) {
      translations = [Translation(termId: term.id ?? 0, meaning: term.translation)];
    }
    if (!mounted) return null;

    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 736),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  term.text,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (term.romanization.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spacingXS),
                  Text(
                    term.romanization,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppConstants.subtitleColor,
                    ),
                  ),
                ],
                const SizedBox(height: AppConstants.spacingS),
                ...translations.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: AppConstants.spacingXS),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (t.partOfSpeech != null) ...[
                        Text(
                          PartOfSpeech.localizedNameFor(t.partOfSpeech!, l10n),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppConstants.subtitleColor,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                      ],
                      Expanded(
                        child: Text(
                          t.meaning,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      if (t.baseTranslationId != null && _translationsById.containsKey(t.baseTranslationId!)) ...[
                        const SizedBox(width: AppConstants.spacingS),
                        Builder(builder: (context) {
                          final baseTranslation = _translationsById[t.baseTranslationId!]!;
                          final baseTerm = _termsById[baseTranslation.termId];
                          final baseText = baseTerm != null
                              ? '${baseTerm.lowerText} (${baseTranslation.meaning})'
                              : baseTranslation.meaning;
                          return Text(
                            '← $baseText',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppConstants.subtitleColor,
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                )),
                const SizedBox(height: AppConstants.spacingL),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(
                      Icons.edit,
                      size: _ReaderScreenConstants.editIconSize,
                    ),
                    label: Text(l10n.edit),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openTermDialog(
    String word,
    int position,
    Term? existingTerm,
  ) async {
    final lowerWord = _textParser.normalizeWord(word);

    final sentence = _textParser.getSentenceAtPosition(
      _text.content,
      position,
      widget.language,
    );

    final dictionaries = await _dictService.getActiveDictionaries(
      widget.language.id!,
    );
    if (!mounted) return;

    TermDialogResult? dialogResult;
    if (existingTerm != null) {
      dialogResult = await showDialog<TermDialogResult?>(
        context: context,
        builder: (context) => TermDialog(
          term: existingTerm,
          sentence: sentence,
          dictionaries: dictionaries,
          onLookup: (ctx, dict) => _dictService.lookupWord(ctx, word, dict.url),
          languageId: widget.language.id!,
          languageName: widget.language.name,
        ),
      );

      if (dialogResult != null) {
        await DatabaseService.instance.updateTerm(dialogResult.term);
        await DatabaseService.instance.translations.replaceForTerm(
          dialogResult.term.id!,
          dialogResult.translations,
        );
        _updateTermInPlace(dialogResult.term);
      }
    } else {
      final newTerm = Term(
        languageId: widget.language.id!,
        text: word,
        lowerText: lowerWord,
        status: TermStatus.unknown,
        sentence: sentence,
      );

      dialogResult = await showDialog<TermDialogResult?>(
        context: context,
        builder: (context) => TermDialog(
          term: newTerm,
          sentence: sentence,
          dictionaries: dictionaries,
          onLookup: (ctx, dict) => _dictService.lookupWord(ctx, word, dict.url),
          languageId: widget.language.id!,
          languageName: widget.language.name,
        ),
      );

      if (dialogResult != null) {
        final termId = await DatabaseService.instance.createTerm(dialogResult.term);
        final termWithId = dialogResult.term.copyWith(id: termId);
        await DatabaseService.instance.translations.replaceForTerm(
          termId,
          dialogResult.translations,
        );
        _updateTermInPlace(termWithId);
      }
    }
  }

  // --- Selection mode ---

  Future<void> _handleWordLongPress(int tokenIndex) async {
    setState(() {
      _isSelectionMode = true;
      _selectedWordIndices.clear();
      _selectedWordIndices.add(tokenIndex);
    });
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedWordIndices.clear();
    });
  }

  Future<void> _lookupSelectedWords() async {
    if (_selectedWordIndices.isEmpty) return;

    final selectedTokens = _selectedWordIndices.toList()..sort();
    final selectedWords = selectedTokens
        .map((i) => _wordTokens[i].text)
        .join(' ');

    final dictionaries = await _dictService.getActiveDictionaries(
      widget.language.id!,
    );
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    if (dictionaries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noDictionariesConfigured)));
      return;
    }

    final selectedDict = await showDialog<Dictionary?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.lookupWord(selectedWords)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: dictionaries
              .map(
                (dict) => ListTile(
                  leading: const Icon(Icons.book),
                  title: Text(dict.name),
                  onTap: () => Navigator.pop(context, dict),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );

    if (selectedDict != null && mounted) {
      await _dictService.lookupWord(context, selectedWords, selectedDict.url);
      _cancelSelection();
    }
  }

  Future<void> _saveSelectionAsTerm() async {
    if (_selectedWordIndices.isEmpty) return;

    final selectedTokens = _selectedWordIndices.toList()..sort();
    final selectedWords = selectedTokens
        .map((i) => _wordTokens[i].text)
        .join(widget.language.splitByCharacter ? '' : ' ');

    final lowerWords = _textParser.normalizeWord(selectedWords);
    final existingTerm = _termsMap[lowerWords];

    final firstToken = _wordTokens[selectedTokens.first];
    final sentence = _textParser.getSentenceAtPosition(
      _text.content,
      firstToken.position,
      widget.language,
    );

    final dictionaries = await _dictService.getActiveDictionaries(
      widget.language.id!,
    );
    if (!mounted) return;

    TermDialogResult? dialogResult;
    if (existingTerm != null) {
      dialogResult = await showDialog<TermDialogResult?>(
        context: context,
        builder: (context) => TermDialog(
          term: existingTerm,
          sentence: sentence,
          dictionaries: dictionaries,
          onLookup: (ctx, dict) =>
              _dictService.lookupWord(ctx, selectedWords, dict.url),
          languageId: widget.language.id!,
          languageName: widget.language.name,
        ),
      );

      if (dialogResult != null) {
        await DatabaseService.instance.updateTerm(dialogResult.term);
        await DatabaseService.instance.translations.replaceForTerm(
          dialogResult.term.id!,
          dialogResult.translations,
        );
      }
    } else {
      final newTerm = Term(
        languageId: widget.language.id!,
        text: selectedWords,
        lowerText: lowerWords,
        status: TermStatus.unknown,
        sentence: sentence,
      );

      dialogResult = await showDialog<TermDialogResult?>(
        context: context,
        builder: (context) => TermDialog(
          term: newTerm,
          sentence: sentence,
          dictionaries: dictionaries,
          onLookup: (ctx, dict) =>
              _dictService.lookupWord(ctx, selectedWords, dict.url),
          languageId: widget.language.id!,
          languageName: widget.language.name,
        ),
      );

      if (dialogResult != null) {
        final termId = await DatabaseService.instance.createTerm(dialogResult.term);
        await DatabaseService.instance.translations.replaceForTerm(
          termId,
          dialogResult.translations,
        );
      }
    }

    _cancelSelection();
    if (dialogResult != null) {
      await _loadTermsAndParse();
    }
  }

  // --- Text actions ---

  Future<void> _editText() async {
    final result = await showDialog<TextDocument>(
      context: context,
      builder: (context) => EditTextDialog(text: _text),
    );

    if (result != null) {
      final contentChanged = result.content != _text.content;
      await DatabaseService.instance.updateText(result);
      setState(() {
        _text = result;
      });
      if (contentChanged) {
        await _loadTermsAndParse();
      }
    }
  }

  void _showFontSizeDialog() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.fontSize),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.previewText, style: TextStyle(fontSize: _fontSize)),
              Slider(
                value: _fontSize,
                min: _ReaderScreenConstants.fontSizeMin,
                max: _ReaderScreenConstants.fontSizeMax,
                divisions: _ReaderScreenConstants.fontSizeSliderDivisions,
                label: _fontSize.round().toString(),
                onChanged: (value) {
                  setDialogState(() => _fontSize = value);
                  setState(() {});
                },
              ),
              Text('${_fontSize.round()}pt'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.done),
          ),
        ],
      ),
    );
  }

  void _markAllWordsKnown() {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.markAllKnownQuestion),
        content: Text(l10n.markAllKnownConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performMarkAllKnown();
            },
            child: Text(l10n.markAll),
          ),
        ],
      ),
    );
  }

  Future<void> _performMarkAllKnown() async {
    try {
      final words = _textParser.splitIntoWords(_text.content, widget.language);

      for (final word in words) {
        final lowerWord = _textParser.normalizeWord(word);
        final existingTerm = _termsMap[lowerWord];

        if (existingTerm != null) {
          await DatabaseService.instance.updateTerm(
            existingTerm.copyWith(status: TermStatus.wellKnown),
          );
        } else {
          await DatabaseService.instance.createTerm(
            Term(
              languageId: widget.language.id!,
              text: word,
              lowerText: lowerWord,
              status: TermStatus.wellKnown,
            ),
          );
        }
      }

      await _loadTermsAndParse();

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.allWordsMarkedKnown)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')),
        );
      }
    }
  }

  Future<void> _markAsFinished() async {
    final newStatus = _text.status == TextStatus.finished
        ? TextStatus.inProgress
        : TextStatus.finished;

    final updatedText = _text.copyWith(status: newStatus);
    await DatabaseService.instance.updateText(updatedText);

    setState(() {
      _text = updatedText;
    });

    if (mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == TextStatus.finished
                ? l10n.textMarkedFinished
                : l10n.textMarkedInProgress,
          ),
        ),
      );
    }

    if (newStatus == TextStatus.finished && _text.collectionId != null) {
      await _promptForNextText();
    }
  }

  Future<void> _promptForNextText() async {
    final textsInCollection = await DatabaseService.instance
        .getTextsInCollection(_text.collectionId!);

    final currentIndex = textsInCollection.indexWhere((t) => t.id == _text.id);

    if (currentIndex >= 0 && currentIndex < textsInCollection.length - 1) {
      final nextText = textsInCollection[currentIndex + 1];

      if (!mounted) return;

      final l10n = AppLocalizations.of(context);
      final shouldProceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.continueReading),
          content: Text(l10n.continueReadingPrompt(nextText.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.no),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.yes),
            ),
          ],
        ),
      );

      if (shouldProceed == true && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ReaderScreen(text: nextText, language: widget.language),
          ),
        );
      }
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _isLoading
          ? null
          : WordListDrawer(wordTokens: _wordTokens, onWordTap: _handleWordTap),
      appBar: AppBar(
        title: Text(_text.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.cancelSelection,
              onPressed: _cancelSelection,
            ),
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.saveAsTerm,
              onPressed: _saveSelectionAsTerm,
            ),
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.lookupInDictionary,
              onPressed: _lookupSelectedWords,
            ),
          if (!_isSelectionMode)
            IconButton(
              icon: Icon(_showLegend ? Icons.visibility_off : Icons.visibility),
              tooltip: l10n.toggleLegend,
              onPressed: () {
                setState(() => _showLegend = !_showLegend);
              },
            ),
          if (!_isSelectionMode)
            IconButton(
              icon: Icon(
                _text.status == TextStatus.finished
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color: _text.status == TextStatus.finished
                    ? AppConstants.successColor
                    : null,
              ),
              tooltip: _text.status == TextStatus.finished
                  ? l10n.markedAsFinished
                  : l10n.markAsFinished,
              onPressed: _markAsFinished,
            ),
          if (!_isSelectionMode)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _editText();
                    break;
                  case 'font_size':
                    _showFontSizeDialog();
                    break;
                  case 'mark_all_known':
                    _markAllWordsKnown();
                    break;
                  case 'open_drawer':
                    _scaffoldKey.currentState?.openEndDrawer();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit),
                      const SizedBox(width: AppConstants.spacingS),
                      Text(l10n.editText),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'font_size',
                  child: Row(
                    children: [
                      const Icon(Icons.text_fields),
                      const SizedBox(width: AppConstants.spacingS),
                      Text(l10n.fontSize),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'mark_all_known',
                  child: Row(
                    children: [
                      const Icon(Icons.done_all),
                      const SizedBox(width: AppConstants.spacingS),
                      Text(l10n.markAllKnown),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'open_drawer',
                  child: Row(
                    children: [
                      const Icon(Icons.list_alt),
                      const SizedBox(width: AppConstants.spacingS),
                      Text(l10n.wordList),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_showLegend) StatusLegend(termCounts: _termCounts),
                if (_isSelectionMode)
                  Container(
                    padding: const EdgeInsets.all(
                      AppConstants.spacingM,
                    ),
                    color: _ReaderScreenConstants.selectionBannerColor,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: _ReaderScreenConstants.selectionAccentColor,
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Expanded(
                          child: Text(
                            l10n.wordsSelected(_selectedWordIndices.length),
                            style: const TextStyle(
                              color:
                                  _ReaderScreenConstants.selectionAccentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Directionality(
                    textDirection: widget.language.rightToLeft
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(
                        AppConstants.spacingL,
                      ),
                      itemCount: _paragraphs.length,
                      itemBuilder: (context, index) {
                        final para = _paragraphs[index];
                        if (para.length == 1 &&
                            !para[0].isWord &&
                            para[0].text.trim().isEmpty) {
                          return SizedBox(
                            height: para[0].text.contains('\n\n')
                                ? AppConstants.spacingL
                                : AppConstants.spacingS,
                          );
                        }
                        return ParagraphRichText(
                          tokens: para,
                          fontSize: _fontSize,
                          selectedWordIndices: _selectedWordIndices,
                          otherLanguageTerms: _otherLanguageTerms,
                          translationsMap: _translationsMap,
                          translationsById: _translationsById,
                          termsById: _termsById,
                          onWordTap: _handleWordTap,
                          onWordLongPress: _handleWordLongPress,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
