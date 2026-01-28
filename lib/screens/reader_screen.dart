import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/term.dart';
import '../models/dictionary.dart';
import '../services/database_service.dart';
import '../services/dictionary_service.dart';
import '../services/text_parser_service.dart';
import '../widgets/term_dialog.dart';
import '../widgets/status_legend.dart';

/// Layout, sizing, and timing constants for the reader screen
abstract class _ReaderScreenConstants {
  // Font sizes
  static const double defaultFontSize = 18.0;
  static const double fontSizeMin = 12.0;
  static const double fontSizeMax = 32.0;
  static const int fontSizeSliderDivisions = 20;

  // Icon sizes
  static const double editIconSize = 18.0;
  static const double statusCircleRadius = 8.0;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;

  // Word token layout
  static const double wordPaddingHorizontal = 3.0;
  static const double wordPaddingVertical = 2.0;
  static const double wordMarginHorizontal = 1.0;
  static const double wordBorderRadius = 4.0;
  static const double wordBorderWidthNormal = 1.0;
  static const double wordBorderWidthSelected = 2.0;

  // Text layout
  static const double textLineHeight = 1.6;
  static const int editDialogMaxLines = 10;

  // Timing
  static const Duration tooltipWaitDuration = Duration(milliseconds: 300);

  // Opacity values
  static const double backgroundAlpha = 0.3;
  static const double borderAlpha = 0.5;
  static const int chipBackgroundAlpha = 50;
  static const int chipBorderAlpha = 100;

  // Divider
  static const double dividerHeight = 1.0;

  // Selection mode colors
  static const Color selectionBackgroundColor = Color(0xFF90CAF9); // Colors.blue.shade200
  static const Color selectionBorderColor = Color(0xFF1E88E5); // Colors.blue.shade600
  static const Color selectionBannerColor = Color(0xFFBBDEFB); // Colors.blue.shade100
  static const Color selectionAccentColor = Colors.blue;
  static const Color selectedTextColor = Colors.black87;

  // Status colors
  static const Color successColor = Colors.green;
  static const Color transparentColor = Colors.transparent;

  // Text colors
  static const Color subtitleColor = Color(0xFF757575); // Colors.grey.shade600

  // Other language words (words that exist in another language's dictionary)
  static const Color otherLanguageColor = Color(0xFFCE93D8); // Colors.purple.shade200
}

/// Data passed to isolate for parsing
class _ParseInput {
  final String content;
  final bool splitByCharacter;
  final String characterSubstitutions;
  final String regexpWordCharacters;
  final Map<String, Map<String, dynamic>> termsMapData; // Serialized terms

  _ParseInput({
    required this.content,
    required this.splitByCharacter,
    required this.characterSubstitutions,
    required this.regexpWordCharacters,
    required this.termsMapData,
  });
}

/// Result from isolate parsing
class _ParsedToken {
  final String text;
  final bool isWord;
  final int position;
  final String? termLowerText; // Reference to term by lowerText

  _ParsedToken({
    required this.text,
    required this.isWord,
    required this.position,
    this.termLowerText,
  });
}

/// Top-level function for isolate parsing - O(n) algorithm
List<_ParsedToken> _parseInIsolate(_ParseInput input) {
  final totalStopwatch = Stopwatch()..start();
  final stepWatch = Stopwatch();

  final parser = TextParserService();
  final tokens = <_ParsedToken>[];
  final content = input.content;

  // Build term keys set for O(1) lookup
  stepWatch.start();
  final termKeys = input.termsMapData.keys.toSet();
  print('[PARSE] Build termKeys set: ${stepWatch.elapsedMilliseconds}ms (${termKeys.length} terms)');
  stepWatch.reset();

  // Create language for word matching
  final tempLang = Language(
    name: '',
    splitByCharacter: input.splitByCharacter,
    characterSubstitutions: input.characterSubstitutions,
    regexpWordCharacters: input.regexpWordCharacters,
  );

  // Get word matches with positions - O(n)
  stepWatch.start();
  final wordMatches = parser.getWordMatches(content, tempLang);
  print('[PARSE] getWordMatches: ${stepWatch.elapsedMilliseconds}ms (${wordMatches.length} words)');
  stepWatch.reset();

  // Get multi-word terms for phrase matching
  stepWatch.start();
  final multiWordTerms = <String, String>{}; // lowerText -> originalText
  for (final entry in input.termsMapData.entries) {
    if (entry.key.contains(' ') || (input.splitByCharacter && entry.key.length > 1)) {
      multiWordTerms[entry.key] = entry.value['text'] as String;
    }
  }
  final sortedMultiWordKeys = multiWordTerms.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  print('[PARSE] Build multi-word terms: ${stepWatch.elapsedMilliseconds}ms (${sortedMultiWordKeys.length} terms)');
  stepWatch.reset();

  // Main parsing loop - O(n)
  stepWatch.start();
  int lastEnd = 0;
  int matchIndex = 0;

  while (matchIndex < wordMatches.length) {
    final match = wordMatches[matchIndex];

    // Add non-word text before this word
    if (match.start > lastEnd) {
      tokens.add(_ParsedToken(
        text: content.substring(lastEnd, match.start),
        isWord: false,
        position: lastEnd,
      ));
    }

    // Check if this word starts a multi-word term
    bool foundMultiWord = false;
    for (final termKey in sortedMultiWordKeys) {
      final termText = multiWordTerms[termKey]!;
      final endPos = match.start + termText.length;

      if (endPos <= content.length) {
        final substring = content.substring(match.start, endPos);
        if (substring.toLowerCase() == termText.toLowerCase()) {
          tokens.add(_ParsedToken(
            text: substring,
            isWord: true,
            position: match.start,
            termLowerText: termKey,
          ));

          // Skip all word matches that are within this multi-word term
          lastEnd = endPos;
          while (matchIndex < wordMatches.length && wordMatches[matchIndex].start < endPos) {
            matchIndex++;
          }
          foundMultiWord = true;
          break;
        }
      }
    }

    if (foundMultiWord) continue;

    // Add single word token
    final lowerWord = parser.normalizeWord(match.word);
    tokens.add(_ParsedToken(
      text: match.word,
      isWord: true,
      position: match.start,
      termLowerText: termKeys.contains(lowerWord) ? lowerWord : null,
    ));

    lastEnd = match.end;
    matchIndex++;
  }

  // Add any remaining text after last word
  if (lastEnd < content.length) {
    tokens.add(_ParsedToken(
      text: content.substring(lastEnd),
      isWord: false,
      position: lastEnd,
    ));
  }

  print('[PARSE] Main loop: ${stepWatch.elapsedMilliseconds}ms (${tokens.length} tokens)');
  stepWatch.reset();

  totalStopwatch.stop();
  print('[PARSE] TOTAL: ${totalStopwatch.elapsedMilliseconds}ms');

  return tokens;
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
  Map<String, ({Term term, String languageName})> _otherLanguageTerms = {}; // Terms from other languages
  List<_WordToken> _wordTokens = [];
  List<List<_WordToken>> _paragraphs =
      []; // Tokens grouped by paragraph for lazy rendering
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

  @override
  void initState() {
    super.initState();
    _text = widget.text;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Start parsing only after route animation completes and screen is visible
    final route = ModalRoute.of(context);
    if (route != null && _isLoading && _wordTokens.isEmpty) {
      void onAnimationComplete(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          route.animation?.removeStatusListener(onAnimationComplete);
          if (mounted) _loadTermsAndParse();
        }
      }

      if (route.animation?.isCompleted ?? true) {
        // Animation already complete (e.g., no animation or instant)
        Future.microtask(() {
          if (mounted) _loadTermsAndParse();
        });
      } else {
        route.animation?.addStatusListener(onAnimationComplete);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTermsAndParse() async {
    setState(() => _isLoading = true);

    try {
      // Update last_read timestamp and status to in_progress if pending
      final updatedText = _text.copyWith(
        lastRead: DateTime.now(),
        status: _text.status == TextStatus.pending
            ? TextStatus.inProgress
            : _text.status,
      );
      await DatabaseService.instance.updateText(updatedText);
      _text = updatedText;

      // Load all terms for this language
      _termsMap = await DatabaseService.instance.getTermsMap(
        widget.language.id!,
      );

      // Parse text into words (async to prevent UI blocking)
      await _parseTextAsync();

      // Find words that exist in other languages (for distinct styling)
      await _loadOtherLanguageWords();

      // Calculate term counts for this specific text
      _updateTextTermCounts();

      setState(() => _isLoading = false);
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

  void _updateTextTermCounts() {
    final counts = <int, int>{};
    final seenWords = <String>{};

    for (final token in _wordTokens) {
      if (!token.isWord) continue;

      final normalized = token.text.toLowerCase();
      if (seenWords.contains(normalized)) continue;
      seenWords.add(normalized);

      // Skip words that belong to other languages
      if (_otherLanguageTerms.containsKey(normalized)) continue;

      final term = _termsMap[normalized];
      final status = term?.status ?? TermStatus.unknown;
      counts[status] = (counts[status] ?? 0) + 1;
    }

    _termCounts = counts;
  }

  /// Update a single term in place without reloading everything
  Future<void> _updateTermInPlace(Term term) async {
    final lowerText = term.lowerText;

    // Check if term was saved to a different language
    if (term.languageId != widget.language.id) {
      // Term belongs to another language - fetch language name and mark
      final lang = await DatabaseService.instance.getLanguage(term.languageId);
      _otherLanguageTerms[lowerText] = (term: term, languageName: lang?.name ?? '');
      _termsMap.remove(lowerText);

      // Update tokens to have no term (for current language)
      _wordTokens = _wordTokens.map((token) {
        if (token.isWord && token.text.toLowerCase() == lowerText) {
          return _WordToken(
            text: token.text,
            isWord: true,
            term: null,
            position: token.position,
          );
        }
        return token;
      }).toList();
    } else {
      // Term is for current language - update normally
      _termsMap[lowerText] = term;

      // Update all tokens that match this term
      _wordTokens = _wordTokens.map((token) {
        if (token.isWord && token.text.toLowerCase() == lowerText) {
          return _WordToken(
            text: token.text,
            isWord: true,
            term: term,
            position: token.position,
          );
        }
        return token;
      }).toList();
    }

    // Rebuild paragraphs with updated tokens
    _groupIntoParagraphs();

    // Recalculate term counts
    _updateTextTermCounts();

    setState(() {});
  }

  Future<void> _parseTextAsync() async {
    // Serialize terms map for isolate
    final termsMapData = <String, Map<String, dynamic>>{};
    for (final entry in _termsMap.entries) {
      termsMapData[entry.key] = {
        'text': entry.value.text,
        'status': entry.value.status,
      };
    }

    // Run parsing in isolate
    final input = _ParseInput(
      content: _text.content,
      splitByCharacter: widget.language.splitByCharacter,
      characterSubstitutions: widget.language.characterSubstitutions,
      regexpWordCharacters: widget.language.regexpWordCharacters,
      termsMapData: termsMapData,
    );

    final parsedTokens = await compute(_parseInIsolate, input);

    if (!mounted) return;

    // Convert parsed tokens back to _WordToken with Term references
    _wordTokens = parsedTokens.map((pt) {
      return _WordToken(
        text: pt.text,
        isWord: pt.isWord,
        position: pt.position,
        term: pt.termLowerText != null ? _termsMap[pt.termLowerText] : null,
      );
    }).toList();

    _groupIntoParagraphs();
  }

  Future<void> _loadOtherLanguageWords() async {
    // Collect all unique words from the text that don't have terms in current language
    final wordsToCheck = <String>{};
    for (final token in _wordTokens) {
      if (token.isWord) {
        final lowerWord = token.text.toLowerCase();
        // Only check words that aren't already in current language's terms
        if (!_termsMap.containsKey(lowerWord)) {
          wordsToCheck.add(lowerWord);
        }
      }
    }

    if (wordsToCheck.isEmpty) {
      _otherLanguageTerms = {};
      return;
    }

    // Query database for terms that exist in other languages
    _otherLanguageTerms = await DatabaseService.instance.getTermsInOtherLanguages(
      widget.language.id!,
      wordsToCheck,
    );
  }

  void _groupIntoParagraphs() {
    // First assign global indices to all tokens
    _wordTokens = [
      for (int i = 0; i < _wordTokens.length; i++)
        _wordTokens[i].copyWithIndex(i),
    ];

    // Group tokens by paragraph (split on double newlines or single newlines)
    _paragraphs = [];
    List<_WordToken> currentParagraph = [];

    for (final token in _wordTokens) {
      if (!token.isWord && token.text.contains('\n\n')) {
        // Double newline - end current paragraph
        if (currentParagraph.isNotEmpty) {
          _paragraphs.add(currentParagraph);
          currentParagraph = [];
        }
        // Add the newline as its own "paragraph" for spacing
        currentParagraph.add(token);
        _paragraphs.add(currentParagraph);
        currentParagraph = [];
      } else if (!token.isWord && token.text.contains('\n')) {
        // Single newline - also split for better chunking
        currentParagraph.add(token);
        _paragraphs.add(currentParagraph);
        currentParagraph = [];
      } else {
        currentParagraph.add(token);
      }
    }

    if (currentParagraph.isNotEmpty) {
      _paragraphs.add(currentParagraph);
    }
  }

  Future<void> _handleWordTap(String word, int position, int tokenIndex) async {
    // If in selection mode, toggle word selection
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

    // Normal mode - edit/create term
    final lowerWord = _textParser.normalizeWord(word);
    final existingTerm = _termsMap[lowerWord];

    // If term exists and has translation, show quick popup
    if (existingTerm != null && existingTerm.translation.isNotEmpty) {
      final shouldEdit = await _showTranslationPopup(existingTerm);
      if (shouldEdit == true) {
        await _openTermDialog(word, position, existingTerm);
      }
      return;
    }

    // No translation - open term dialog directly
    await _openTermDialog(word, position, existingTerm);
  }

  Future<bool?> _showTranslationPopup(Term term) async {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(_ReaderScreenConstants.spacingL),
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
                const SizedBox(height: _ReaderScreenConstants.spacingXS),
                Text(
                  term.romanization,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: _ReaderScreenConstants.subtitleColor,
                      ),
                ),
              ],
              const SizedBox(height: _ReaderScreenConstants.spacingS),
              Text(
                term.translation,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: _ReaderScreenConstants.spacingL),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.edit, size: _ReaderScreenConstants.editIconSize),
                  label: Text(l10n.edit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTermDialog(String word, int position, Term? existingTerm) async {
    final lowerWord = _textParser.normalizeWord(word);

    // Get sentence context
    final sentence = _textParser.getSentenceAtPosition(
      _text.content,
      position,
      widget.language,
    );

    // Get available dictionaries
    final dictionaries = await _dictService.getActiveDictionaries(
      widget.language.id!,
    );

    Term? result;
    if (existingTerm != null) {
      // Show term edit dialog
      result = await showDialog<Term?>(
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

      if (result != null) {
        await DatabaseService.instance.updateTerm(result);
        _updateTermInPlace(result);
      }
    } else {
      // Create new term
      final newTerm = Term(
        languageId: widget.language.id!,
        text: word,
        lowerText: lowerWord,
        status: TermStatus.unknown,
        sentence: sentence,
      );

      result = await showDialog<Term?>(
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

      if (result != null) {
        await DatabaseService.instance.createTerm(result);
        _updateTermInPlace(result);
      }
    }
  }

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

    // Get selected word tokens in order
    final selectedTokens = _selectedWordIndices.toList()..sort();
    final selectedWords = selectedTokens
        .map((i) => _wordTokens[i].text)
        .join(' ');

    // Get available dictionaries
    final dictionaries = await _dictService.getActiveDictionaries(
      widget.language.id!,
    );

    final l10n = AppLocalizations.of(context);
    if (dictionaries.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noDictionariesConfigured)));
      return;
    }

    // Show dictionary selection dialog
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

    if (selectedDict != null) {
      await _dictService.lookupWord(context, selectedWords, selectedDict.url);
      _cancelSelection();
    }
  }

  Future<void> _saveSelectionAsTerm() async {
    if (_selectedWordIndices.isEmpty) return;

    // Get selected word tokens in order
    final selectedTokens = _selectedWordIndices.toList()..sort();
    final selectedWords = selectedTokens
        .map((i) => _wordTokens[i].text)
        .join(
          widget.language.splitByCharacter ? '' : ' ',
        ); // No space for character-based languages

    final lowerWords = _textParser.normalizeWord(selectedWords);
    final existingTerm = _termsMap[lowerWords];

    // Get sentence context from first selected word
    final firstToken = _wordTokens[selectedTokens.first];
    final sentence = _textParser.getSentenceAtPosition(
      _text.content,
      firstToken.position,
      widget.language,
    );

    // Get available dictionaries
    final dictionaries = await _dictService.getActiveDictionaries(
      widget.language.id!,
    );

    Term? result;
    if (existingTerm != null) {
      // Edit existing term
      result = await showDialog<Term?>(
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

      if (result != null) {
        await DatabaseService.instance.updateTerm(result);
      }
    } else {
      // Create new term
      final newTerm = Term(
        languageId: widget.language.id!,
        text: selectedWords,
        lowerText: lowerWords,
        status: TermStatus.unknown,
        sentence: sentence,
      );

      result = await showDialog<Term?>(
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

      if (result != null) {
        await DatabaseService.instance.createTerm(result);
      }
    }

    // Always cancel selection and reload, even if dialog was cancelled
    _cancelSelection();
    if (result != null) {
      await _loadTermsAndParse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildWordListDrawer(),
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
              icon: const Icon(Icons.list_alt),
              tooltip: l10n.wordList,
              onPressed: () {
                _scaffoldKey.currentState?.openEndDrawer();
              },
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
                  case 'mark_finished':
                    _markAsFinished();
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit),
                      const SizedBox(width: _ReaderScreenConstants.spacingS),
                      Text(l10n.editText),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'font_size',
                  child: Row(
                    children: [
                      const Icon(Icons.text_fields),
                      const SizedBox(width: _ReaderScreenConstants.spacingS),
                      Text(l10n.fontSize),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'mark_all_known',
                  child: Row(
                    children: [
                      const Icon(Icons.done_all),
                      const SizedBox(width: _ReaderScreenConstants.spacingS),
                      Text(l10n.markAllKnown),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'mark_finished',
                  child: Row(
                    children: [
                      Icon(
                        _text.status == TextStatus.finished
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: _text.status == TextStatus.finished
                            ? _ReaderScreenConstants.successColor
                            : null,
                      ),
                      const SizedBox(width: _ReaderScreenConstants.spacingS),
                      Text(
                        _text.status == TextStatus.finished
                            ? l10n.markedAsFinished
                            : l10n.markAsFinished,
                      ),
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
                    padding: const EdgeInsets.all(_ReaderScreenConstants.spacingM),
                    color: _ReaderScreenConstants.selectionBannerColor,
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: _ReaderScreenConstants.selectionAccentColor),
                        const SizedBox(width: _ReaderScreenConstants.spacingS),
                        Expanded(
                          child: Text(
                            l10n.wordsSelected(_selectedWordIndices.length),
                            style: const TextStyle(color: _ReaderScreenConstants.selectionAccentColor),
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
                      padding: const EdgeInsets.all(_ReaderScreenConstants.spacingL),
                      itemCount: _paragraphs.length,
                      itemBuilder: (context, index) {
                        return Wrap(
                          children: _buildParagraphWidgets(_paragraphs[index]),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildParagraphWidgets(List<_WordToken> paragraphTokens) {
    final widgets = <Widget>[];

    for (final token in paragraphTokens) {
      final globalIndex = token.globalIndex;

      if (!token.isWord) {
        // Handle newlines specially to create proper line breaks in Wrap
        if (token.text.contains('\n')) {
          final parts = token.text.split('\n');
          for (int i = 0; i < parts.length; i++) {
            // Add the text part (may be empty)
            if (parts[i].isNotEmpty) {
              widgets.add(
                Text(
                  parts[i],
                  style: TextStyle(fontSize: _fontSize, height: _ReaderScreenConstants.textLineHeight),
                ),
              );
            }
            // Add line break (except after last part)
            if (i < parts.length - 1) {
              widgets.add(const SizedBox(width: double.infinity, height: _ReaderScreenConstants.spacingS));
            }
          }
        } else {
          widgets.add(
            Text(
              token.text,
              style: TextStyle(fontSize: _fontSize, height: _ReaderScreenConstants.textLineHeight),
            ),
          );
        }
        continue;
      }

      final term = token.term;
      final isSelected = _selectedWordIndices.contains(globalIndex);
      final isIgnored = term?.status == TermStatus.ignored;
      final isWellKnown = term?.status == TermStatus.wellKnown;
      final lowerWord = token.text.toLowerCase();
      final isOtherLanguage = term == null && _otherLanguageTerms.containsKey(lowerWord);

      Color backgroundColor;
      if (isSelected) {
        backgroundColor = _ReaderScreenConstants.selectionBackgroundColor;
      } else if (isIgnored || isWellKnown) {
        // Ignored and well-known words have transparent background (blend with text)
        backgroundColor = _ReaderScreenConstants.transparentColor;
      } else if (isOtherLanguage) {
        // Words from other languages have distinct purple tint
        backgroundColor = _ReaderScreenConstants.otherLanguageColor.withValues(alpha: _ReaderScreenConstants.backgroundAlpha);
      } else if (term != null) {
        backgroundColor = term.statusColor.withValues(alpha: _ReaderScreenConstants.backgroundAlpha);
      } else {
        backgroundColor = TermStatus.colorFor(
          TermStatus.unknown,
        ).withValues(alpha: _ReaderScreenConstants.backgroundAlpha);
      }

      Color borderColor;
      if (isSelected) {
        borderColor = _ReaderScreenConstants.selectionBorderColor;
      } else if (isIgnored || isWellKnown) {
        // Ignored and well-known words have transparent border for consistent height
        borderColor = _ReaderScreenConstants.transparentColor;
      } else if (isOtherLanguage) {
        // Words from other languages have distinct purple border
        borderColor = _ReaderScreenConstants.otherLanguageColor.withValues(alpha: _ReaderScreenConstants.borderAlpha);
      } else if (term != null) {
        borderColor = term.statusColor.withValues(alpha: _ReaderScreenConstants.borderAlpha);
      } else {
        borderColor = TermStatus.colorFor(
          TermStatus.unknown,
        ).withValues(alpha: _ReaderScreenConstants.borderAlpha);
      }

      // Text color - use theme default for readability
      Color? textColor;
      if (isSelected) {
        textColor = _ReaderScreenConstants.selectedTextColor;
      }
      // All other cases use null (theme default) for better readability

      // Build tooltip message if term has translation
      String? tooltipMessage;
      if (term != null && term.translation.isNotEmpty) {
        tooltipMessage = term.translation;
        if (term.romanization.isNotEmpty) {
          tooltipMessage = '${term.romanization}\n$tooltipMessage';
        }
      } else if (isOtherLanguage) {
        final otherInfo = _otherLanguageTerms[lowerWord]!;
        final otherTerm = otherInfo.term;
        final parts = <String>[];
        if (otherTerm.romanization.isNotEmpty) {
          parts.add(otherTerm.romanization);
        }
        if (otherTerm.translation.isNotEmpty) {
          parts.add(otherTerm.translation);
        }
        if (otherInfo.languageName.isNotEmpty) {
          parts.add('(${otherInfo.languageName})');
        }
        if (parts.isNotEmpty) {
          tooltipMessage = parts.join('\n');
        }
      }

      final wordWidget = GestureDetector(
        onTap: () => _handleWordTap(token.text, token.position, globalIndex),
        onLongPress: () => _handleWordLongPress(globalIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _ReaderScreenConstants.wordPaddingHorizontal,
            vertical: _ReaderScreenConstants.wordPaddingVertical,
          ),
          margin: const EdgeInsets.symmetric(horizontal: _ReaderScreenConstants.wordMarginHorizontal),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(_ReaderScreenConstants.wordBorderRadius),
            border: Border.all(
              color: borderColor,
              width: isSelected
                  ? _ReaderScreenConstants.wordBorderWidthSelected
                  : _ReaderScreenConstants.wordBorderWidthNormal,
            ),
          ),
          child: Text(
            token.text,
            style: TextStyle(
              fontSize: _fontSize,
              height: _ReaderScreenConstants.textLineHeight,
              color: textColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );

      widgets.add(
        tooltipMessage != null
            ? Tooltip(
                message: tooltipMessage,
                waitDuration: _ReaderScreenConstants.tooltipWaitDuration,
                child: wordWidget,
              )
            : wordWidget,
      );
    }

    return widgets;
  }

  Future<void> _editText() async {
    final result = await showDialog<TextDocument>(
      context: context,
      builder: (context) => _EditTextDialog(text: _text),
    );

    if (result != null) {
      final contentChanged = result.content != _text.content;
      await DatabaseService.instance.updateText(result);
      setState(() {
        _text = result;
      });
      // Re-parse if content changed
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

    // If marked as finished and text is in a collection, check for next text
    if (newStatus == TextStatus.finished && _text.collectionId != null) {
      await _promptForNextText();
    }
  }

  Future<void> _promptForNextText() async {
    final textsInCollection = await DatabaseService.instance
        .getTextsInCollection(_text.collectionId!);

    final currentIndex = textsInCollection.indexWhere((t) => t.id == _text.id);

    // Check if there's a next text
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

  Widget _buildWordListDrawer() {
    final l10n = AppLocalizations.of(context);
    // Group unique words by status
    final wordsByStatus = <int, List<_WordToken>>{};
    final seenWords = <String>{};

    for (final token in _wordTokens) {
      if (!token.isWord) continue;
      final normalized = token.text.toLowerCase();
      if (seenWords.contains(normalized)) continue;
      seenWords.add(normalized);

      final status = token.term?.status ?? TermStatus.unknown;
      wordsByStatus.putIfAbsent(status, () => []).add(token);
    }

    // Sort words alphabetically within each group
    for (final list in wordsByStatus.values) {
      list.sort((a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()));
    }

    // Define status order and labels
    final statusOrder = [
      TermStatus.unknown,
      TermStatus.learning2,
      TermStatus.learning3,
      TermStatus.learning4,
      TermStatus.known,
      TermStatus.wellKnown,
      TermStatus.ignored,
    ];

    final statusLabels = {
      TermStatus.unknown: l10n.statusUnknown,
      TermStatus.learning2: l10n.statusLearning2,
      TermStatus.learning3: l10n.statusLearning3,
      TermStatus.learning4: l10n.statusLearning4,
      TermStatus.known: l10n.statusKnown,
      TermStatus.wellKnown: l10n.statusWellKnown,
      TermStatus.ignored: l10n.statusIgnored,
    };

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(_ReaderScreenConstants.spacingL),
              child: Text(
                l10n.wordList,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: _ReaderScreenConstants.dividerHeight),
            Expanded(
              child: ListView(
                children: [
                  for (final status in statusOrder)
                    if (wordsByStatus.containsKey(status) &&
                        wordsByStatus[status]!.isNotEmpty)
                      _buildStatusSection(
                        statusLabels[status]!,
                        wordsByStatus[status]!,
                        TermStatus.colorFor(status),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection(
    String label,
    List<_WordToken> tokens,
    Color color,
  ) {
    final l10n = AppLocalizations.of(context);
    return ExpansionTile(
      initiallyExpanded: label == l10n.statusUnknown,
      leading: CircleAvatar(backgroundColor: color, radius: _ReaderScreenConstants.statusCircleRadius),
      title: Text('$label (${tokens.length})'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _ReaderScreenConstants.spacingL, vertical: _ReaderScreenConstants.spacingS),
          child: Wrap(
            spacing: _ReaderScreenConstants.spacingS,
            runSpacing: _ReaderScreenConstants.spacingS,
            children: tokens.map((token) {
              return ActionChip(
                label: Text(token.text),
                backgroundColor: color.withAlpha(_ReaderScreenConstants.chipBackgroundAlpha),
                side: BorderSide(color: color.withAlpha(_ReaderScreenConstants.chipBorderAlpha)),
                onPressed: () {
                  Navigator.pop(context); // Close drawer
                  _handleWordTap(
                    token.text,
                    token.position,
                    _wordTokens.indexOf(token),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _WordToken {
  final String text;
  final bool isWord;
  final Term? term;
  final int position;
  final int globalIndex; // Index in _wordTokens for selection tracking

  _WordToken({
    required this.text,
    required this.isWord,
    this.term,
    this.position = 0,
    this.globalIndex = -1,
  });

  _WordToken copyWithIndex(int index) => _WordToken(
    text: text,
    isWord: isWord,
    term: term,
    position: position,
    globalIndex: index,
  );
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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.text.title);
    _contentController = TextEditingController(text: widget.text.content);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editText),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(labelText: l10n.title),
                validator: (v) => v?.isEmpty == true ? l10n.required : null,
              ),
              const SizedBox(height: _ReaderScreenConstants.spacingL),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: l10n.textContent,
                  alignLabelWithHint: true,
                ),
                maxLines: _ReaderScreenConstants.editDialogMaxLines,
                validator: (v) => v?.isEmpty == true ? l10n.required : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final updatedText = widget.text.copyWith(
                title: _titleController.text,
                content: _contentController.text,
              );
              Navigator.pop(context, updatedText);
            }
          },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
