import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../controllers/reader_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/term.dart';
import '../models/dictionary.dart';
import '../models/word_token.dart';
import '../service_locator.dart';
import '../services/ai_explanation_service.dart';
import '../services/dictionary_service.dart';
import '../widgets/reader/edit_text_dialog.dart';
import '../widgets/reader/ai_thinking_dialog.dart';
import '../widgets/reader/reader_ai_explanation_dialog.dart';
import '../widgets/reader/reader_app_bar.dart';
import '../widgets/reader/reader_content.dart';
import '../widgets/reader/reader_continue_reading_dialog.dart';
import '../widgets/reader/reader_dictionary_picker_dialog.dart';
import '../widgets/reader/reader_font_size_dialog.dart';
import '../widgets/reader/reader_foreign_word_dialog.dart';
import '../widgets/reader/reader_language_picker_dialog.dart';
import '../widgets/reader/reader_mark_all_known_dialog.dart';
import '../widgets/reader/reader_translation_dialog.dart';
import '../widgets/shared/term_dialog.dart';
import '../widgets/reader/word_list_drawer.dart';
import '../utils/app_theme.dart';
import '../utils/async_helpers.dart';
import '../utils/constants.dart';
import '../utils/snackbar_helpers.dart';

enum _ContextMenuAction {
  saveAsTerm,
  mineSentence,
  assignForeignLanguage,
  lookupInDictionary,
  aiMeaning,
  aiGrammar,
}

/// Layout, sizing, and timing constants for the reader screen
abstract class _ReaderScreenConstants {
  // Font sizes
  static const double fontSizeMin = 12.0;
  static const double fontSizeMax = 32.0;
  static const int fontSizeSliderDivisions = 20;

  // Icon sizes
  static const double editIconSize = 18.0;
}

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
  final _dictService = DictionaryService();
  final _aiExplanationService = AiExplanationService(settings: settings);
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loadScheduled = false;
  int? _dragSelectOriginIndex;

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

    // Check if this is a foreign-marked word
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
    // Use preloaded translations from controller.
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
        removeIconSize: _ReaderScreenConstants.editIconSize,
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

    final dictionaries = await _dictService.getActiveDictionaries(
      ctrl.language.id!,
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
          onLookup: (ctx, dict) => _dictService.lookupWord(ctx, word, dict),
          languageId: ctrl.language.id!,
          languageName: ctrl.language.name,
          languageCode: ctrl.language.languageCode,
        ),
      );

      if (dialogResult != null) {
        await ctrl.handleTermSaved(
          dialogResult.term,
          dialogResult.translations,
          isNew: false,
        );
      }
    } else {
      final newTerm = Term(
        languageId: ctrl.language.id!,
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
          onLookup: (ctx, dict) => _dictService.lookupWord(ctx, word, dict),
          languageId: ctrl.language.id!,
          languageName: ctrl.language.name,
          languageCode: ctrl.language.languageCode,
        ),
      );

      if (dialogResult != null) {
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

  void _onWordDragStart(int tokenIndex) {
    _dragSelectOriginIndex = tokenIndex;
  }

  void _onWordDragEnter(int tokenIndex) {
    final origin = _dragSelectOriginIndex;
    if (origin == null || tokenIndex == origin) return;
    context.read<ReaderController>().selectRange(origin, tokenIndex);
  }

  void _stopDragSelect() {
    _dragSelectOriginIndex = null;
  }

  Future<void> _handleWordRightClick(
    String word,
    int position,
    int tokenIndex,
    Offset globalPosition,
  ) async {
    final ctrl = context.read<ReaderController>();
    final l10n = AppLocalizations.of(context);
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    final lowerWord = ctrl.normalizeWord(word);
    final existingTerm = ctrl.termsMap[lowerWord];

    final action = await showMenu<_ContextMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          value: _ContextMenuAction.saveAsTerm,
          child: Row(
            children: [
              const Icon(Icons.add),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(child: Text(l10n.saveAsTerm)),
            ],
          ),
        ),
        if (existingTerm != null)
          PopupMenuItem(
            value: _ContextMenuAction.mineSentence,
            child: Row(
              children: [
                const Icon(Icons.push_pin_outlined),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(child: Text(l10n.mineSentence)),
              ],
            ),
          ),
        PopupMenuItem(
          value: _ContextMenuAction.assignForeignLanguage,
          child: Row(
            children: [
              const Icon(Icons.language),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(child: Text(l10n.assignForeignLanguage)),
            ],
          ),
        ),
        PopupMenuItem(
          value: _ContextMenuAction.lookupInDictionary,
          child: Row(
            children: [
              const Icon(Icons.search),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(child: Text(l10n.lookupInDictionary)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _ContextMenuAction.aiMeaning,
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(child: Text(l10n.explainMeaningInContext)),
            ],
          ),
        ),
        PopupMenuItem(
          value: _ContextMenuAction.aiGrammar,
          child: Row(
            children: [
              const Icon(Icons.rule),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(child: Text(l10n.explainGrammarInContext)),
            ],
          ),
        ),
      ],
    );

    if (!mounted) return;

    final hasSelection =
        ctrl.isSelectionMode && ctrl.selectedWordIndices.isNotEmpty;

    switch (action) {
      case _ContextMenuAction.saveAsTerm:
        if (hasSelection) {
          await _saveSelectionAsTerm();
        } else {
          await _openTermDialog(ctrl, word, position, existingTerm);
        }
      case _ContextMenuAction.mineSentence:
        await _mineSentenceForWord(ctrl, existingTerm!, position);
      case _ContextMenuAction.assignForeignLanguage:
        if (hasSelection) {
          await _assignForeignLanguage();
        } else {
          await _assignForeignLanguageForWord(lowerWord);
        }
      case _ContextMenuAction.lookupInDictionary:
        if (hasSelection) {
          await _lookupSelectedWords();
        } else {
          await _lookupWord(word);
        }
      case _ContextMenuAction.aiMeaning:
        if (hasSelection) {
          await _explainSelectionInContext(AiExplanationType.meaning);
        } else {
          await _explainWordInContext(
            word,
            position,
            AiExplanationType.meaning,
          );
        }
      case _ContextMenuAction.aiGrammar:
        if (hasSelection) {
          await _explainSelectionInContext(AiExplanationType.grammar);
        } else {
          await _explainWordInContext(
            word,
            position,
            AiExplanationType.grammar,
          );
        }
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

  Future<void> _assignForeignLanguageForWord(String lowerWord) async {
    final ctrl = context.read<ReaderController>();
    final l10n = AppLocalizations.of(context);

    final allLanguages = await db.languages.getAll();
    final otherLanguages = allLanguages
        .where((lang) => lang.id != ctrl.language.id)
        .toList();

    if (!mounted) return;

    if (otherLanguages.isEmpty) {
      SnackbarHelpers.showInfo(context, l10n.noOtherLanguages);
      return;
    }

    final selectedLanguage = await showDialog<Language>(
      context: context,
      builder: (context) =>
          ReaderLanguagePickerDialog(l10n: l10n, languages: otherLanguages),
    );

    if (selectedLanguage == null || !mounted) return;

    final targetTermsMap = await db.terms.getMapByLanguage(
      selectedLanguage.id!,
    );
    await ctrl.assignForeignWords(selectedLanguage.id!, {
      lowerWord: targetTermsMap[lowerWord]?.id,
    });
  }

  Future<void> _lookupWord(String word) async {
    final ctrl = context.read<ReaderController>();
    final dictionaries = await _dictService.getActiveDictionaries(
      ctrl.language.id!,
    );
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
        selectedWords: word,
        dictionaries: dictionaries,
      ),
    );

    if (selectedDict != null && mounted) {
      await _dictService.lookupWord(context, word, selectedDict);
    }
  }

  Future<void> _explainWordInContext(
    String word,
    int position,
    AiExplanationType type,
  ) async {
    final ctrl = context.read<ReaderController>();
    final l10n = AppLocalizations.of(context);

    if (!await _aiExplanationService.isConfigured()) {
      if (!mounted) return;
      SnackbarHelpers.showInfo(context, l10n.aiFeatureUnavailable);
      return;
    }

    final sentence = ctrl.getSentenceForPosition(position);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AiThinkingDialog(),
    );

    try {
      final explanation = await _aiExplanationService.explainInContext(
        type: type,
        selectedText: word,
        contextSentence: sentence,
        languageName: ctrl.language.name,
      );

      if (!mounted) return;
      Navigator.pop(context);

      final title = type == AiExplanationType.meaning
          ? l10n.explainMeaningInContext
          : l10n.explainGrammarInContext;

      await showDialog<void>(
        context: context,
        builder: (context) => ReaderAiExplanationDialog(
          title: title,
          selectedText: word,
          contextSentence: sentence,
          explanation: explanation,
          closeLabel: l10n.close,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      final label = type == AiExplanationType.meaning
          ? l10n.aiMeaningExplainFailed
          : l10n.aiGrammarExplainFailed;
      final detail = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      SnackbarHelpers.showError(context, '$label: $detail');
    }
  }

  Future<void> _assignForeignLanguage() async {
    final ctrl = context.read<ReaderController>();
    if (ctrl.selectedWordIndices.isEmpty) return;
    final l10n = AppLocalizations.of(context);

    final allLanguages = await db.languages.getAll();
    final otherLanguages = allLanguages
        .where((lang) => lang.id != ctrl.language.id)
        .toList();

    if (!mounted) return;

    if (otherLanguages.isEmpty) {
      SnackbarHelpers.showInfo(context, l10n.noOtherLanguages);
      return;
    }

    final selectedLanguage = await showDialog<Language>(
      context: context,
      builder: (context) =>
          ReaderLanguagePickerDialog(l10n: l10n, languages: otherLanguages),
    );

    if (selectedLanguage == null || !mounted) return;

    final selectedTokens = ctrl.selectedWordIndices.toList()..sort();
    final lowerWords = selectedTokens
        .map(ctrl.getWordTokenByGlobalIndex)
        .whereType<WordToken>()
        .map((t) => ctrl.normalizeWord(t.text))
        .toSet()
        .toList();

    final targetTermsMap = await db.terms.getMapByLanguage(
      selectedLanguage.id!,
    );
    final wordsWithTermIds = <String, String?>{};
    for (final word in lowerWords) {
      final term = targetTermsMap[word];
      wordsWithTermIds[word] = term?.id;
    }

    await ctrl.assignForeignWords(selectedLanguage.id!, wordsWithTermIds);
  }

  Future<void> _lookupSelectedWords() async {
    final ctrl = context.read<ReaderController>();
    if (ctrl.selectedWordIndices.isEmpty) return;

    final selectedTokens = ctrl.selectedWordIndices.toList()..sort();
    final selectedWords = selectedTokens
        .map(ctrl.getWordTokenByGlobalIndex)
        .whereType<WordToken>()
        .map((t) => t.text)
        .join(' ');

    final dictionaries = await _dictService.getActiveDictionaries(
      ctrl.language.id!,
    );
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
        selectedWords: selectedWords,
        dictionaries: dictionaries,
      ),
    );

    if (selectedDict != null && mounted) {
      await _dictService.lookupWord(context, selectedWords, selectedDict);
      ctrl.cancelSelection();
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

    final dictionaries = await _dictService.getActiveDictionaries(
      ctrl.language.id!,
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
              _dictService.lookupWord(ctx, selectedWords, dict),
          languageId: ctrl.language.id!,
          languageName: ctrl.language.name,
          languageCode: ctrl.language.languageCode,
        ),
      );
    } else {
      final newTerm = Term(
        languageId: ctrl.language.id!,
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
              _dictService.lookupWord(ctx, selectedWords, dict),
          languageId: ctrl.language.id!,
          languageName: ctrl.language.name,
          languageCode: ctrl.language.languageCode,
        ),
      );
    }

    if (dialogResult != null) {
      await ctrl.handleSelectionTermSaved(
        dialogResult.term,
        dialogResult.translations,
        isNew: existingTerm == null,
      );
    } else {
      ctrl.cancelSelection();
    }
  }

  Future<void> _explainSelectionInContext(AiExplanationType type) async {
    final ctrl = context.read<ReaderController>();
    if (ctrl.selectedWordIndices.isEmpty) return;
    final l10n = AppLocalizations.of(context);

    if (!await _aiExplanationService.isConfigured()) {
      if (!mounted) return;
      SnackbarHelpers.showInfo(context, l10n.aiFeatureUnavailable);
      return;
    }

    final selectedWords = ctrl.getSelectedWordsText();
    final selectedTokens = ctrl.selectedWordIndices.toList()..sort();
    final firstToken = ctrl.getWordTokenByGlobalIndex(selectedTokens.first);
    if (firstToken == null) {
      ctrl.cancelSelection();
      return;
    }
    final sentence = ctrl.getSentenceForPosition(firstToken.position);

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AiThinkingDialog(),
    );

    try {
      final explanation = await _aiExplanationService.explainInContext(
        type: type,
        selectedText: selectedWords,
        contextSentence: sentence,
        languageName: ctrl.language.name,
      );

      if (!mounted) return;
      Navigator.pop(context); // loading

      final title = type == AiExplanationType.meaning
          ? l10n.explainMeaningInContext
          : l10n.explainGrammarInContext;

      await showDialog<void>(
        context: context,
        builder: (context) => ReaderAiExplanationDialog(
          title: title,
          selectedText: selectedWords,
          contextSentence: sentence,
          explanation: explanation,
          closeLabel: l10n.close,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // loading
      final label = type == AiExplanationType.meaning
          ? l10n.aiMeaningExplainFailed
          : l10n.aiGrammarExplainFailed;
      final detail = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      SnackbarHelpers.showError(context, '$label: $detail');
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
        min: _ReaderScreenConstants.fontSizeMin,
        max: _ReaderScreenConstants.fontSizeMax,
        divisions: _ReaderScreenConstants.fontSizeSliderDivisions,
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
          onAssignForeignLanguage: _assignForeignLanguage,
          onLookupSelectedWords: _lookupSelectedWords,
          onSelectionAiSelected: (action) {
            switch (action) {
              case ReaderSelectionAiAction.meaning:
                _explainSelectionInContext(AiExplanationType.meaning);
              case ReaderSelectionAiAction.grammar:
                _explainSelectionInContext(AiExplanationType.grammar);
            }
          },
          onToggleLegend: ctrl.toggleLegend,
          onToggleFinished: _markAsFinished,
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
                onPointerUp: (_) => _stopDragSelect(),
                onPointerCancel: (_) => _stopDragSelect(),
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
                  onWordDragStart: _onWordDragStart,
                  onWordDragEnter: _onWordDragEnter,
                ),
              ),
      ),
    );
  }
}
