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
  List<_WordToken> _wordTokens = [];
  bool _isLoading = true;
  bool _showLegend = false;
  double _fontSize = 18.0;

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
    _loadTermsAndParse();
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

      // Parse text into words
      _parseText();

      // Calculate term counts for this specific text
      _updateTextTermCounts();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.errorLoadingTerms(e.toString()))));
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

      final term = _termsMap[normalized];
      final status = term?.status ?? 1; // Default to Unknown (1) if no term
      counts[status] = (counts[status] ?? 0) + 1;
    }

    _termCounts = counts;
  }

  /// Update a single term in place without reloading everything
  void _updateTermInPlace(Term term) {
    final lowerText = term.lowerText;

    // Update the terms map
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

    // Recalculate term counts
    _updateTextTermCounts();

    setState(() {});
  }

  void _parseText() {
    // For character-based languages, use different parsing
    if (widget.language.splitByCharacter) {
      _parseTextByCharacter();
      return;
    }

    // Standard word-based parsing for languages with spaces
    final words = _textParser.splitIntoWords(_text.content, widget.language);
    final tokens = <_WordToken>[];
    int wordIndex = 0;
    int position = 0;
    String remainingText = _text.content;

    // Get multi-word terms sorted by length (longest first)
    final multiWordTerms =
        _termsMap.entries.where((e) => e.key.contains(' ')).toList()
          ..sort((a, b) => b.key.length.compareTo(a.key.length));

    while (wordIndex < words.length) {
      final word = words[wordIndex];

      // Find word position in remaining text
      final currentWordIndex = remainingText.indexOf(word);
      if (currentWordIndex == -1) {
        wordIndex++;
        continue;
      }

      // Add any text before the word (whitespace, punctuation)
      if (currentWordIndex > 0) {
        tokens.add(
          _WordToken(
            text: remainingText.substring(0, currentWordIndex),
            isWord: false,
          ),
        );
      }

      // Check if this word starts a multi-word term
      bool isPartOfMultiWord = false;
      for (final multiWordEntry in multiWordTerms) {
        final multiWordText = multiWordEntry.value.text;
        final checkText = remainingText.substring(currentWordIndex);

        if (checkText.toLowerCase().startsWith(multiWordText.toLowerCase())) {
          // Found a multi-word term match
          tokens.add(
            _WordToken(
              text: multiWordText,
              isWord: true,
              term: multiWordEntry.value,
              position: position + currentWordIndex,
            ),
          );

          // Skip all words that are part of this multi-word term
          final wordsInPhrase = multiWordText.split(RegExp(r'\s+'));
          wordIndex += wordsInPhrase.length;

          remainingText = remainingText.substring(
            currentWordIndex + multiWordText.length,
          );
          position += currentWordIndex + multiWordText.length;
          isPartOfMultiWord = true;
          break;
        }
      }

      if (isPartOfMultiWord) continue;

      // Add single word token
      final lowerWord = _textParser.normalizeWord(word);
      final term = _termsMap[lowerWord];

      tokens.add(
        _WordToken(
          text: word,
          isWord: true,
          term: term,
          position: position + currentWordIndex,
        ),
      );

      remainingText = remainingText.substring(currentWordIndex + word.length);
      position += currentWordIndex + word.length;
      wordIndex++;
    }

    // Add any remaining text
    if (remainingText.isNotEmpty) {
      tokens.add(_WordToken(text: remainingText, isWord: false));
    }

    _wordTokens = tokens;
  }

  void _parseTextByCharacter() {
    final tokens = <_WordToken>[];
    int position = 0;
    final content = _text.content;

    // Get multi-character terms sorted by length (longest first)
    final multiCharTerms =
        _termsMap.entries
            .where((e) => e.key.length > 1) // Only multi-character terms
            .toList()
          ..sort((a, b) => b.key.length.compareTo(a.key.length));

    int i = 0;
    while (i < content.length) {
      final char = content[i];

      // Skip whitespace and punctuation as non-word tokens
      if (char.trim().isEmpty || _isPunctuation(char)) {
        tokens.add(_WordToken(text: char, isWord: false));
        position++;
        i++;
        continue;
      }

      // Check if this position starts a multi-character term
      bool foundMultiCharTerm = false;
      for (final termEntry in multiCharTerms) {
        final termText = termEntry.value.text;
        final termLength = termText.length;

        final endIndex = i + termLength;
        if (endIndex <= content.length) {
          final substring = content.substring(i, endIndex);
          final normalizedSubstring = _textParser.normalizeWord(substring);

          // Direct comparison with the term's lower text
          if (normalizedSubstring == termEntry.key) {
            // Found a multi-character term
            tokens.add(
              _WordToken(
                text: substring,
                isWord: true,
                term: termEntry.value,
                position: position,
              ),
            );
            i += termLength;
            position += termLength;
            foundMultiCharTerm = true;
            break;
          }
        }
      }

      if (foundMultiCharTerm) continue;

      // Add single character token
      final lowerChar = _textParser.normalizeWord(char);
      final term = _termsMap[lowerChar];

      tokens.add(
        _WordToken(text: char, isWord: true, term: term, position: position),
      );

      position++;
      i++;
    }

    _wordTokens = tokens;
  }

  bool _isPunctuation(String char) {
    final punctuationPattern = RegExp(r'[\p{P}\p{S}]', unicode: true);
    return punctuationPattern.hasMatch(char);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noDictionariesConfigured)),
      );
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
                      const SizedBox(width: 8),
                      Text(l10n.editText),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'font_size',
                  child: Row(
                    children: [
                      const Icon(Icons.text_fields),
                      const SizedBox(width: 8),
                      Text(l10n.fontSize),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'mark_all_known',
                  child: Row(
                    children: [
                      const Icon(Icons.done_all),
                      const SizedBox(width: 8),
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
                            ? Colors.green
                            : null,
                      ),
                      const SizedBox(width: 8),
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
                    padding: const EdgeInsets.all(12),
                    color: Colors.blue.shade100,
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.wordsSelected(_selectedWordIndices.length),
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    child: Directionality(
                      textDirection: widget.language.rightToLeft
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: Wrap(children: _buildWordWidgets()),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<Widget> _buildWordWidgets() {
    final widgets = <Widget>[];

    for (int index = 0; index < _wordTokens.length; index++) {
      final token = _wordTokens[index];

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
                  style: TextStyle(fontSize: _fontSize, height: 1.6),
                ),
              );
            }
            // Add line break (except after last part)
            if (i < parts.length - 1) {
              widgets.add(const SizedBox(width: double.infinity, height: 8));
            }
          }
        } else {
          widgets.add(
            Text(
              token.text,
              style: TextStyle(fontSize: _fontSize, height: 1.6),
            ),
          );
        }
        continue;
      }

      final term = token.term;
      final isSelected = _selectedWordIndices.contains(index);
      final isIgnored = term?.status == TermStatus.ignored;
      final isWellKnown = term?.status == TermStatus.wellKnown;

      Color backgroundColor;
      if (isSelected) {
        backgroundColor = Colors.blue.shade200;
      } else if (isIgnored || isWellKnown) {
        // Ignored and well-known words have transparent background (blend with text)
        backgroundColor = Colors.transparent;
      } else if (term != null) {
        backgroundColor = term.statusColor.withOpacity(0.3);
      } else {
        backgroundColor = TermStatus.colorFor(
          TermStatus.unknown,
        ).withOpacity(0.3);
      }

      Color borderColor;
      if (isSelected) {
        borderColor = Colors.blue.shade600;
      } else if (isIgnored || isWellKnown) {
        // Ignored and well-known words have transparent border for consistent height
        borderColor = Colors.transparent;
      } else if (term != null) {
        borderColor = term.statusColor.withOpacity(0.5);
      } else {
        borderColor = TermStatus.colorFor(TermStatus.unknown).withOpacity(0.5);
      }

      // Text color - use theme default for readability
      Color? textColor;
      if (isSelected) {
        textColor = Colors.black87;
      }
      // All other cases use null (theme default) for better readability

      widgets.add(
        GestureDetector(
          onTap: () => _handleWordTap(token.text, token.position, index),
          onLongPress: () => _handleWordLongPress(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            ),
            child: Text(
              token.text,
              style: TextStyle(
                fontSize: _fontSize,
                height: 1.6,
                color: textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
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
                min: 12,
                max: 32,
                divisions: 20,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.allWordsMarkedKnown)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${AppLocalizations.of(context).error}: $e')));
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
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.wordList,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
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
      leading: CircleAvatar(backgroundColor: color, radius: 8),
      title: Text('$label (${tokens.length})'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tokens.map((token) {
              return ActionChip(
                label: Text(token.text),
                backgroundColor: color.withAlpha(50),
                side: BorderSide(color: color.withAlpha(100)),
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

  _WordToken({
    required this.text,
    required this.isWord,
    this.term,
    this.position = 0,
  });
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: InputDecoration(
                  labelText: l10n.textContent,
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
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
