import '../../utils/dictionary_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/reader_controller.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/text_document.dart';
import '../../domain/entities/term.dart';
import '../../domain/entities/dictionary.dart';
import '../../service_locator.dart';
import '../../data/services/ai_explanation_service.dart';
import '../widgets/reader/ai_thinking_dialog.dart';
import '../widgets/reader/edit_text_dialog.dart';
import '../widgets/reader/reader_ai_explanation_dialog.dart';
import '../widgets/reader/reader_app_bar.dart';
import '../widgets/reader/reader_content.dart';
import '../widgets/reader/reader_context_menu.dart';
import '../widgets/reader/reader_continue_reading_dialog.dart';
import '../widgets/reader/reader_dictionary_picker_dialog.dart';
import '../widgets/reader/reader_font_size_dialog.dart';
import '../widgets/reader/reader_foreign_word_dialog.dart';
import '../widgets/reader/reader_language_picker_dialog.dart';
import '../widgets/reader/reader_mark_all_known_dialog.dart';
import '../widgets/reader/reader_translation_dialog.dart';
import '../widgets/shared/term_dialog.dart';
import '../widgets/reader/word_list_drawer.dart';
import '../theme/app_theme.dart';
import '../../utils/async_helpers.dart';
import '../../utils/snackbar_helpers.dart';
import '../../domain/value_objects/term_status.dart';

class ReaderScreen extends StatelessWidget {
  final TextDocument text;
  final Language language;

  const ReaderScreen({super.key, required this.text, required this.language});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReaderController(text: text, language: language),
      child: const _ReaderScreenBody(),
    );
  }
}

class _ReaderScreenBody extends StatefulWidget {
  const _ReaderScreenBody();

  @override
  State<_ReaderScreenBody> createState() => _ReaderScreenBodyState();
}

class _ReaderScreenBodyState extends State<_ReaderScreenBody> {
  final _scrollController = ScrollController();
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loadScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_loadScheduled) {
        _loadScheduled = true;
        _waitForAnimationAndLoad();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _waitForAnimationAndLoad() {
    final route = ModalRoute.of(context);
    final animation = route?.animation;

    if (animation == null || animation.isCompleted) {
      _loadData();
    } else {
      void onComplete(AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          animation.removeStatusListener(onComplete);
          if (mounted) _loadData();
        }
      }

      animation.addStatusListener(onComplete);
    }
  }

  Future<void> _loadData() async {
    final l10n = AppLocalizations.of(context);
    await AsyncHelpers.run(
      context,
      operation: () => context.read<ReaderController>().loadTermsAndParse(),
      errorMessageBuilder: (e) => l10n.errorLoadingTerms(e.toString()),
    );
  }

  // --- Word interaction ---

  Future<void> _handleWordTap(String word, int position, int tokenIndex) async {
    final ctrl = context.read<ReaderController>();

    if (ctrl.isSelectionMode) {
      final shiftPressed = HardwareKeyboard.instance.isShiftPressed;
      ctrl.toggleWordSelection(tokenIndex, shiftPressed: shiftPressed);
      return;
    }

    final lowerWord = ctrl.normalizeWord(word);

    final foreignInfo = ctrl.otherLanguageTerms[lowerWord];
    if (foreignInfo != null) {
      final shouldRemove = await _showForeignWordPopup(lowerWord, foreignInfo);
      if (shouldRemove == true) {
        await ctrl.removeForeignMarking(lowerWord);
      }
      return;
    }

    final existingTerm = ctrl.termsMap[lowerWord];

    if (existingTerm != null && ctrl.hasTranslations(existingTerm)) {
      final shouldEdit = await _showTranslationPopup(ctrl, existingTerm);
      if (shouldEdit == true) {
        await _openTermDialog(ctrl, word, position, existingTerm);
      }
      return;
    }

    await _openTermDialog(ctrl, word, position, existingTerm);
  }

  Future<bool?> _showTranslationPopup(ReaderController ctrl, Term term) async {
    final l10n = AppLocalizations.of(context);
    List<Translation> translations = [];
    if (term.id != null) {
      translations = ctrl.translationsMap[term.id!] ?? [];
    }
    if (translations.isEmpty && term.translation.isNotEmpty) {
      translations = [
        Translation(termId: term.id ?? '', meaning: term.translation),
      ];
    }

    return showDialog<bool>(
      context: context,
      builder: (context) => ReaderTranslationDialog(
        term: term,
        translations: translations,
        translationsById: ctrl.translationsById,
        termsById: ctrl.termsById,
        languageCode: ctrl.language.languageCode,
        l10n: l10n,
        onPronounce: () =>
            ttsService.speak(term.lowerText, ctrl.language.languageCode),
        onEdit: () => Navigator.pop(context, true),
      ),
    );
  }

  Future<bool?> _showForeignWordPopup(
    String lowerWord,
    ForeignTermInfo info,
  ) async {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => ReaderForeignWordDialog(
        lowerWord: lowerWord,
        info: info,
        l10n: l10n,
        onRemove: () => Navigator.pop(context, true),
        removeIconSize: ReaderScreenConstants.editIconSize,
      ),
    );
  }

  Future<void> _openTermDialog(
    ReaderController ctrl,
    String word,
    int position,
    Term? existingTerm,
  ) async {
    final lowerWord = ctrl.normalizeWord(word);
    final sentence = ctrl.getSentenceForPosition(position);

    final dictionaries = await ctrl.dictService.getActiveDictionaries(
      ctrl.language.id!,
    );
    if (!mounted) return;

    TermDialogResult? dialogResult;
    if (existingTerm != null) {
      dialogResult = await TermDialog.show(
        context,
        term: existingTerm,
        sentence: sentence,
        dictionaries: dictionaries,
        onLookup: (ctx, dict) => openDictionaryLookup(ctx, word, dict),
        languageId: ctrl.language.id!,
        languageName: ctrl.language.name,
        languageCode: ctrl.language.languageCode,
      );

      if (!mounted) return;
      if (dialogResult != null) {
        if (dialogResult.deleted) {
          await db.terms.delete(existingTerm.id!);
          await ctrl.loadTermsAndParse();
        } else {
          await ctrl.handleTermSaved(
            dialogResult.term,
            dialogResult.translations,
            isNew: false,
          );
        }
      }
    } else {
      final newTerm = Term(
        languageId: ctrl.language.id!,
        text: word,
        lowerText: lowerWord,
        status: TermStatus.unknown,
        sentence: sentence,
      );

      dialogResult = await TermDialog.show(
        context,
        term: newTerm,
        sentence: sentence,
        dictionaries: dictionaries,
        onLookup: (ctx, dict) => openDictionaryLookup(ctx, word, dict),
        languageId: ctrl.language.id!,
        languageName: ctrl.language.name,
        languageCode: ctrl.language.languageCode,
      );

      if (!mounted) return;
      if (dialogResult != null && !dialogResult.deleted) {
        await ctrl.handleTermSaved(
          dialogResult.term,
          dialogResult.translations,
          isNew: true,
        );
      }
    }
  }

  // --- Selection mode ---

  Future<void> _handleWordLongPress(int tokenIndex) async {
    context.read<ReaderController>().handleWordLongPress(tokenIndex);
  }

  // --- Context menu ---

  Future<void> _handleWordRightClick(
    String word,
    int position,
    int tokenIndex,
    Offset globalPosition,
  ) async {
    final ctrl = context.read<ReaderController>();
    final l10n = AppLocalizations.of(context);

    final lowerWord = ctrl.normalizeWord(word);
    final existingTerm = ctrl.termsMap[lowerWord];

    final action = await showReaderContextMenu(
      context: context,
      globalPosition: globalPosition,
      hasExistingTerm: existingTerm != null,
      l10n: l10n,
    );

    if (!mounted) return;

    final hasSelection =
        ctrl.isSelectionMode && ctrl.selectedWordIndices.isNotEmpty;

    switch (action) {
      case ReaderContextMenuAction.saveAsTerm:
        if (hasSelection) {
          await _saveSelectionAsTerm();
        } else {
          await _openTermDialog(ctrl, word, position, existingTerm);
        }
      case ReaderContextMenuAction.mineSentence:
        await _mineSentenceForWord(ctrl, existingTerm!, position);
      case ReaderContextMenuAction.assignForeignLanguage:
        final lowerWords =
            hasSelection ? ctrl.getSelectedLowerWords() : [lowerWord];
        await _assignForeignLanguageForWords(lowerWords);
      case ReaderContextMenuAction.lookupInDictionary:
        final words = hasSelection ? ctrl.getSelectedWordsText() : word;
        await _lookupWords(words);
      case ReaderContextMenuAction.aiMeaning ||
            ReaderContextMenuAction.aiGrammar ||
            ReaderContextMenuAction.aiWordForms:
        final aiType = switch (action!) {
          ReaderContextMenuAction.aiMeaning => AiExplanationType.meaning,
          ReaderContextMenuAction.aiGrammar => AiExplanationType.grammar,
          _ => AiExplanationType.wordForms,
        };
        final selectedText = hasSelection ? ctrl.getSelectedWordsText() : word;
        final sentence = hasSelection
            ? ctrl.getSelectionSentence()
            : ctrl.getSentenceForPosition(position);
        await _explainInContext(selectedText, sentence, aiType);
      case null:
        break;
    }
  }

  Future<void> _mineSentenceForWord(
    ReaderController ctrl,
    Term term,
    int position,
  ) async {
    final l10n = AppLocalizations.of(context);
    final sentence = ctrl.getSentenceForPosition(position);

    if (sentence.isEmpty) {
      SnackbarHelpers.showInfo(context, l10n.noSentenceFound);
      return;
    }

    await db.termSentences.create(
      term.id!,
      sentence,
      sourceTextId: ctrl.text.id,
    );

    if (mounted) {
      SnackbarHelpers.showSuccess(context, l10n.sentenceMined);
    }
  }

  Future<Language?> _pickForeignLanguage() async {
    final ctrl = context.read<ReaderController>();
    final l10n = AppLocalizations.of(context);

    final allLanguages = await db.languages.getAll();
    final otherLanguages =
        allLanguages.where((lang) => lang.id != ctrl.language.id).toList();

    if (!mounted) return null;

    if (otherLanguages.isEmpty) {
      SnackbarHelpers.showInfo(context, l10n.noOtherLanguages);
      return null;
    }

    return showDialog<Language>(
      context: context,
      builder: (context) =>
          ReaderLanguagePickerDialog(l10n: l10n, languages: otherLanguages),
    );
  }

  Future<void> _assignForeignLanguageForWords(List<String> lowerWords) async {
    if (lowerWords.isEmpty) return;

    final selectedLanguage = await _pickForeignLanguage();
    if (selectedLanguage == null || !mounted) return;

    final ctrl = context.read<ReaderController>();
    final targetTermsMap =
        await db.terms.getMapByLanguage(selectedLanguage.id!);
    final wordsWithTermIds = <String, String?>{
      for (final word in lowerWords) word: targetTermsMap[word]?.id,
    };

    await ctrl.assignForeignWords(selectedLanguage.id!, wordsWithTermIds);
  }

  Future<void> _lookupWords(String words) async {
    final ctrl = context.read<ReaderController>();
    final dictionaries =
        await ctrl.dictService.getActiveDictionaries(ctrl.language.id!);
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    if (dictionaries.isEmpty) {
      SnackbarHelpers.showInfo(context, l10n.noDictionariesConfigured);
      return;
    }

    final selectedDict = await showDialog<Dictionary?>(
      context: context,
      builder: (context) => ReaderDictionaryPickerDialog(
        l10n: l10n,
        selectedWords: words,
        dictionaries: dictionaries,
      ),
    );

    if (selectedDict != null && mounted) {
      await openDictionaryLookup(context, words, selectedDict);
      if (ctrl.isSelectionMode) ctrl.cancelSelection();
    }
  }

  Future<void> _explainInContext(
    String selectedText,
    String sentence,
    AiExplanationType type,
  ) async {
    final ctrl = context.read<ReaderController>();
    final l10n = AppLocalizations.of(context);

    if (!await ctrl.aiExplanationService.isConfigured()) {
      if (!mounted) return;
      SnackbarHelpers.showInfo(context, l10n.aiFeatureUnavailable);
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AiThinkingDialog(),
    );

    try {
      final explanation = await ctrl.aiExplanationService.explainInContext(
        type: type,
        selectedText: selectedText,
        contextSentence: sentence,
        languageName: ctrl.language.name,
      );

      if (!mounted) return;
      Navigator.pop(context);

      final title = switch (type) {
        AiExplanationType.meaning => l10n.explainMeaningInContext,
        AiExplanationType.grammar => l10n.explainGrammarInContext,
        AiExplanationType.wordForms => l10n.showWordForms,
      };

      await showDialog<void>(
        context: context,
        builder: (context) => ReaderAiExplanationDialog(
          title: title,
          selectedText: selectedText,
          contextSentence: sentence,
          explanation: explanation,
          closeLabel: l10n.close,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      final label = switch (type) {
        AiExplanationType.meaning => l10n.aiMeaningExplainFailed,
        AiExplanationType.grammar => l10n.aiGrammarExplainFailed,
        AiExplanationType.wordForms => l10n.aiWordFormsFailed,
      };
      final detail = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      SnackbarHelpers.showError(context, '$label: $detail');
    }
  }

  Future<void> _saveSelectionAsTerm() async {
    final ctrl = context.read<ReaderController>();
    if (ctrl.selectedWordIndices.isEmpty) return;

    final selectedWords = ctrl.getSelectedWordsText();
    final lowerWords = ctrl.normalizeWord(selectedWords);
    final existingTerm = ctrl.termsMap[lowerWords];

    final selectedTokens = ctrl.selectedWordIndices.toList()..sort();
    final firstToken = ctrl.getWordTokenByGlobalIndex(selectedTokens.first);
    if (firstToken == null) {
      ctrl.cancelSelection();
      return;
    }
    final sentence = ctrl.getSentenceForPosition(firstToken.position);

    final dictionaries =
        await ctrl.dictService.getActiveDictionaries(ctrl.language.id!);
    if (!mounted) return;

    TermDialogResult? dialogResult;
    if (existingTerm != null) {
      dialogResult = await TermDialog.show(
        context,
        term: existingTerm,
        sentence: sentence,
        dictionaries: dictionaries,
        onLookup: (ctx, dict) =>
            openDictionaryLookup(ctx, selectedWords, dict),
        languageId: ctrl.language.id!,
        languageName: ctrl.language.name,
        languageCode: ctrl.language.languageCode,
      );
    } else {
      final newTerm = Term(
        languageId: ctrl.language.id!,
        text: selectedWords,
        lowerText: lowerWords,
        status: TermStatus.unknown,
        sentence: sentence,
      );

      dialogResult = await TermDialog.show(
        context,
        term: newTerm,
        sentence: sentence,
        dictionaries: dictionaries,
        onLookup: (ctx, dict) =>
            openDictionaryLookup(ctx, selectedWords, dict),
        languageId: ctrl.language.id!,
        languageName: ctrl.language.name,
        languageCode: ctrl.language.languageCode,
      );
    }

    if (!mounted) return;
    if (dialogResult != null && dialogResult.deleted && existingTerm != null) {
      await db.terms.delete(existingTerm.id!);
      await ctrl.loadTermsAndParse();
      ctrl.cancelSelection();
    } else if (dialogResult != null && !dialogResult.deleted) {
      await ctrl.handleSelectionTermSaved(
        dialogResult.term,
        dialogResult.translations,
        isNew: existingTerm == null,
      );
    } else {
      ctrl.cancelSelection();
    }
  }

  // --- Text actions ---

  Future<void> _editText() async {
    final ctrl = context.read<ReaderController>();
    final result = await showDialog<TextDocument>(
      context: context,
      builder: (context) => EditTextDialog(text: ctrl.text),
    );

    if (result != null) {
      await ctrl.updateText(result);
    }
  }

  void _showFontSizeDialog() {
    final ctrl = context.read<ReaderController>();
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => ReaderFontSizeDialog(
        l10n: l10n,
        initialValue: ctrl.fontSize,
        min: ReaderScreenConstants.fontSizeMin,
        max: ReaderScreenConstants.fontSizeMax,
        divisions: ReaderScreenConstants.fontSizeSliderDivisions,
        onChanged: ctrl.setFontSize,
      ),
    );
  }

  void _markAllWordsKnown() {
    final ctrl = context.read<ReaderController>();
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => ReaderMarkAllKnownDialog(
        l10n: l10n,
        onConfirm: () async {
          Navigator.pop(dialogContext);
          await AsyncHelpers.run(
            context,
            operation: () => ctrl.performMarkAllKnown(),
            successMessage: l10n.allWordsMarkedKnown,
            errorMessageBuilder: (e) => '${l10n.error}: $e',
          );
        },
      ),
    );
  }

  Future<void> _markAsFinished() async {
    final ctrl = context.read<ReaderController>();
    final l10n = AppLocalizations.of(context);

    final newStatus = await ctrl.markAsFinished();

    if (mounted) {
      SnackbarHelpers.showSuccess(
        context,
        newStatus == TextStatus.finished
            ? l10n.textMarkedFinished
            : l10n.textMarkedInProgress,
      );
    }

    if (newStatus == TextStatus.finished) {
      await _promptForNextText(ctrl);
    }
  }

  Future<void> _promptForNextText(ReaderController ctrl) async {
    final nextText = await ctrl.getNextTextInCollection();
    if (nextText == null || !mounted) return;

    final l10n = AppLocalizations.of(context);
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          ReaderContinueReadingDialog(l10n: l10n, nextTitle: nextText.title),
    );

    if (shouldProceed == true && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ReaderScreen(text: nextText, language: ctrl.language),
        ),
      );
    }
  }

  void _navigateToText(TextDocument targetText, {bool reverse = false}) {
    final ctrl = context.read<ReaderController>();
    Widget buildPage(BuildContext ctx) =>
        ReaderScreen(text: targetText, language: ctrl.language);
    Navigator.pushReplacement(
      context,
      reverse
          ? PageRouteBuilder<void>(
              pageBuilder: (ctx, _, _) => buildPage(ctx),
              transitionDuration: const Duration(milliseconds: 300),
              reverseTransitionDuration: const Duration(milliseconds: 300),
              transitionsBuilder: (_, animation, secondaryAnimation, child) {
                final enterTween = Tween(
                  begin: const Offset(-1.0, 0.0),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeInOut));
                final exitTween = Tween(
                  begin: Offset.zero,
                  end: const Offset(1.0, 0.0),
                ).chain(CurveTween(curve: Curves.easeInOut));
                return SlideTransition(
                  position: enterTween.animate(animation),
                  child: SlideTransition(
                    position: exitTween.animate(secondaryAnimation),
                    child: child,
                  ),
                );
              },
            )
          : MaterialPageRoute(builder: buildPage),
    );
  }

  void _showContentsBottomSheet() {
    final ctrl = context.read<ReaderController>();
    final texts = ctrl.collectionTexts;
    final currentIndex = ctrl.collectionIndex;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetCtx) => ListView.builder(
        itemCount: texts.length,
        itemBuilder: (_, i) {
          final isCurrent = i == currentIndex;
          return ListTile(
            title: Text(
              texts[i].title,
              style: isCurrent
                  ? TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(sheetCtx).colorScheme.primary,
                    )
                  : null,
            ),
            trailing: isCurrent
                ? Icon(Icons.play_arrow,
                    color: Theme.of(sheetCtx).colorScheme.primary)
                : null,
            onTap: () {
              Navigator.pop(sheetCtx);
              if (!isCurrent) _navigateToText(texts[i]);
            },
          );
        },
      ),
    );
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ReaderController>();
    final l10n = AppLocalizations.of(context);

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.escape &&
            ctrl.isSelectionMode) {
          ctrl.cancelSelection();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: ctrl.isLoading
            ? null
            : WordListDrawer(
                wordTokens: ctrl.wordTokens,
                onWordTap: _handleWordTap,
              ),
        appBar: ReaderAppBar(
          title: ctrl.text.title,
          isSelectionMode: ctrl.isSelectionMode,
          showLegend: ctrl.showLegend,
          isFinished: ctrl.text.status == TextStatus.finished,
          finishedColor: context.appColors.success,
          l10n: l10n,
          onCancelSelection: ctrl.cancelSelection,
          onSaveSelectionAsTerm: _saveSelectionAsTerm,
          onAssignForeignLanguage: () =>
              _assignForeignLanguageForWords(ctrl.getSelectedLowerWords()),
          onLookupSelectedWords: () =>
              _lookupWords(ctrl.getSelectedWordsText()),
          onSelectionAiSelected: (action) {
            final aiType = switch (action) {
              ReaderSelectionAiAction.meaning => AiExplanationType.meaning,
              ReaderSelectionAiAction.grammar => AiExplanationType.grammar,
              ReaderSelectionAiAction.wordForms => AiExplanationType.wordForms,
            };
            _explainInContext(
              ctrl.getSelectedWordsText(),
              ctrl.getSelectionSentence(),
              aiType,
            );
          },
          onToggleLegend: ctrl.toggleLegend,
          onToggleFinished: _markAsFinished,
          isEpubCollection: ctrl.isEpubCollection,
          hasPrev: ctrl.hasPrevInCollection,
          hasNext: ctrl.hasNextInCollection,
          onPrevText: () {
            final prev = ctrl.getPrevTextInCollection();
            if (prev != null) _navigateToText(prev, reverse: true);
          },
          onNextText: () {
            final next = ctrl.getNextTextInCollectionCached();
            if (next != null) _navigateToText(next);
          },
          onShowContents: _showContentsBottomSheet,
          onMoreSelected: (action) {
            switch (action) {
              case ReaderMoreAction.edit:
                _editText();
              case ReaderMoreAction.fontSize:
                _showFontSizeDialog();
              case ReaderMoreAction.markAllKnown:
                _markAllWordsKnown();
              case ReaderMoreAction.openDrawer:
                _scaffoldKey.currentState?.openEndDrawer();
            }
          },
        ),
        body: ctrl.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Listener(
                behavior: HitTestBehavior.translucent,
                onPointerUp: (_) => ctrl.stopDragSelect(),
                onPointerCancel: (_) => ctrl.stopDragSelect(),
                child: ReaderContent(
                  showLegend: ctrl.showLegend,
                  termCounts: ctrl.termCounts,
                  rightToLeft: ctrl.language.rightToLeft,
                  scrollController: _scrollController,
                  paragraphs: ctrl.paragraphs,
                  fontSize: ctrl.fontSize,
                  selectedWordIndices: ctrl.selectedWordIndices,
                  otherLanguageTerms: ctrl.otherLanguageTerms,
                  translationsMap: ctrl.translationsMap,
                  translationsById: ctrl.translationsById,
                  termsById: ctrl.termsById,
                  onWordTap: _handleWordTap,
                  onWordLongPress: _handleWordLongPress,
                  onWordRightClick: _handleWordRightClick,
                  onWordDragStart: ctrl.startDragSelect,
                  onWordDragEnter: ctrl.dragSelectTo,
                ),
              ),
      ),
    );
  }
}
