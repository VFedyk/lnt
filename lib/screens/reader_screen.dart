import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/reader_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/text_document.dart';
import '../models/term.dart';
import '../models/dictionary.dart';
import '../service_locator.dart';
import '../services/dictionary_service.dart';
import '../widgets/term_dialog.dart';
import '../widgets/status_legend.dart';
import '../widgets/edit_text_dialog.dart';
import '../widgets/word_list_drawer.dart';
import '../widgets/paragraph_rich_text.dart';
import '../utils/constants.dart';

/// Layout, sizing, and timing constants for the reader screen
abstract class _ReaderScreenConstants {
  // Font sizes
  static const double fontSizeMin = 12.0;
  static const double fontSizeMax = 32.0;
  static const int fontSizeSliderDivisions = 20;

  // Icon sizes
  static const double editIconSize = 18.0;

  // Selection mode colors
  static const Color selectionBannerColor = Color(0xFFBBDEFB);
  static const Color selectionAccentColor = Colors.blue;
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
    try {
      await context.read<ReaderController>().loadTermsAndParse();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorLoadingTerms(e.toString()))),
        );
      }
    }
  }

  // --- Word interaction ---

  Future<void> _handleWordTap(
    String word,
    int position,
    int tokenIndex,
  ) async {
    final ctrl = context.read<ReaderController>();

    if (ctrl.isSelectionMode) {
      ctrl.toggleWordSelection(tokenIndex);
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

  Future<bool?> _showTranslationPopup(
    ReaderController ctrl,
    Term term,
  ) async {
    final l10n = AppLocalizations.of(context);
    // Use preloaded translations from controller
    List<Translation> translations = [];
    if (term.id != null) {
      translations = ctrl.translationsMap[term.id!] ?? [];
    }
    if (translations.isEmpty && term.translation.isNotEmpty) {
      translations = [
        Translation(termId: term.id ?? 0, meaning: term.translation),
      ];
    }

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
                ...translations.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppConstants.spacingXS,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (t.partOfSpeech != null) ...[
                          Text(
                            PartOfSpeech.localizedNameFor(
                              t.partOfSpeech!,
                              l10n,
                            ),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
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
                        if (t.baseTranslationId != null &&
                            ctrl.translationsById.containsKey(
                              t.baseTranslationId!,
                            )) ...[
                          const SizedBox(width: AppConstants.spacingS),
                          Builder(
                            builder: (context) {
                              final baseTranslation =
                                  ctrl
                                      .translationsById[t.baseTranslationId!]!;
                              final baseTerm =
                                  ctrl.termsById[baseTranslation.termId];
                              final baseText = baseTerm != null
                                  ? '${baseTerm.lowerText} (${baseTranslation.meaning})'
                                  : baseTranslation.meaning;
                              return Text(
                                '\u2190 $baseText',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(
                                  color: AppConstants.subtitleColor,
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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

  Future<bool?> _showForeignWordPopup(
    String lowerWord,
    ForeignTermInfo info,
  ) async {
    final l10n = AppLocalizations.of(context);
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
                  lowerWord,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppConstants.spacingXS),
                Text(
                  info.languageName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppConstants.subtitleColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (info.term != null &&
                    info.term!.romanization.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spacingXS),
                  Text(
                    info.term!.romanization,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppConstants.subtitleColor,
                    ),
                  ),
                ],
                if (info.translations.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spacingS),
                  ...info.translations.map(
                    (t) => Padding(
                      padding: const EdgeInsets.only(
                        bottom: AppConstants.spacingXS,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (t.partOfSpeech != null) ...[
                            Text(
                              PartOfSpeech.localizedNameFor(
                                t.partOfSpeech!,
                                l10n,
                              ),
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
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
                        ],
                      ),
                    ),
                  ),
                ] else if (info.term != null &&
                    info.term!.translation.isNotEmpty) ...[
                  const SizedBox(height: AppConstants.spacingS),
                  Text(
                    info.term!.translation,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
                const SizedBox(height: AppConstants.spacingL),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      size: _ReaderScreenConstants.editIconSize,
                    ),
                    label: Text(l10n.removeForeignMarking),
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
          onLookup: (ctx, dict) =>
              _dictService.lookupWord(ctx, word, dict.url),
          languageId: ctrl.language.id!,
          languageName: ctrl.language.name,
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
          onLookup: (ctx, dict) =>
              _dictService.lookupWord(ctx, word, dict.url),
          languageId: ctrl.language.id!,
          languageName: ctrl.language.name,
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

  Future<void> _assignForeignLanguage() async {
    final ctrl = context.read<ReaderController>();
    if (ctrl.selectedWordIndices.isEmpty) return;
    final l10n = AppLocalizations.of(context);

    final allLanguages = await db.getLanguages();
    final otherLanguages =
        allLanguages.where((lang) => lang.id != ctrl.language.id).toList();

    if (!mounted) return;

    if (otherLanguages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noOtherLanguages)));
      return;
    }

    final selectedLanguage = await showDialog<Language>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.assignForeignLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: otherLanguages
              .map(
                (lang) => ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(lang.name),
                  onTap: () => Navigator.pop(context, lang),
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

    if (selectedLanguage == null || !mounted) return;

    final selectedTokens = ctrl.selectedWordIndices.toList()..sort();
    final lowerWords = selectedTokens
        .map((i) => ctrl.wordTokens[i].text.toLowerCase())
        .toSet()
        .toList();

    final targetTermsMap = await db.getTermsMap(selectedLanguage.id!);
    final wordsWithTermIds = <String, int?>{};
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
    final selectedWords =
        selectedTokens.map((i) => ctrl.wordTokens[i].text).join(' ');

    final dictionaries = await _dictService.getActiveDictionaries(
      ctrl.language.id!,
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
    final firstToken = ctrl.wordTokens[selectedTokens.first];
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
              _dictService.lookupWord(ctx, selectedWords, dict.url),
          languageId: ctrl.language.id!,
          languageName: ctrl.language.name,
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
              _dictService.lookupWord(ctx, selectedWords, dict.url),
          languageId: ctrl.language.id!,
          languageName: ctrl.language.name,
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
      builder: (context) => AlertDialog(
        title: Text(l10n.fontSize),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.previewText,
                style: TextStyle(fontSize: ctrl.fontSize),
              ),
              Slider(
                value: ctrl.fontSize,
                min: _ReaderScreenConstants.fontSizeMin,
                max: _ReaderScreenConstants.fontSizeMax,
                divisions: _ReaderScreenConstants.fontSizeSliderDivisions,
                label: ctrl.fontSize.round().toString(),
                onChanged: (value) {
                  ctrl.setFontSize(value);
                  setDialogState(() {});
                },
              ),
              Text('${ctrl.fontSize.round()}pt'),
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
    final ctrl = context.read<ReaderController>();
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
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              try {
                await ctrl.performMarkAllKnown();
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.allWordsMarkedKnown)),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('${l10n.error}: $e')),
                );
              }
            },
            child: Text(l10n.markAll),
          ),
        ],
      ),
    );
  }

  Future<void> _markAsFinished() async {
    final ctrl = context.read<ReaderController>();
    final l10n = AppLocalizations.of(context);

    final newStatus = await ctrl.markAsFinished();

    if (mounted) {
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
          builder: (_) => ReaderScreen(
            text: nextText,
            language: ctrl.language,
          ),
        ),
      );
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ReaderController>();
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: ctrl.isLoading
          ? null
          : WordListDrawer(
              wordTokens: ctrl.wordTokens,
              onWordTap: _handleWordTap,
            ),
      appBar: AppBar(
        title: Text(ctrl.text.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (ctrl.isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.cancelSelection,
              onPressed: ctrl.cancelSelection,
            ),
          if (ctrl.isSelectionMode)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.saveAsTerm,
              onPressed: _saveSelectionAsTerm,
            ),
          if (ctrl.isSelectionMode)
            IconButton(
              icon: const Icon(Icons.language),
              tooltip: l10n.assignForeignLanguage,
              onPressed: _assignForeignLanguage,
            ),
          if (ctrl.isSelectionMode)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: l10n.lookupInDictionary,
              onPressed: _lookupSelectedWords,
            ),
          if (!ctrl.isSelectionMode)
            IconButton(
              icon: Icon(
                ctrl.showLegend ? Icons.visibility_off : Icons.visibility,
              ),
              tooltip: l10n.toggleLegend,
              onPressed: ctrl.toggleLegend,
            ),
          if (!ctrl.isSelectionMode)
            IconButton(
              icon: Icon(
                ctrl.text.status == TextStatus.finished
                    ? Icons.check_circle
                    : Icons.check_circle_outline,
                color: ctrl.text.status == TextStatus.finished
                    ? AppConstants.successColor
                    : null,
              ),
              tooltip: ctrl.text.status == TextStatus.finished
                  ? l10n.markedAsFinished
                  : l10n.markAsFinished,
              onPressed: _markAsFinished,
            ),
          if (!ctrl.isSelectionMode)
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
      body: ctrl.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (ctrl.showLegend)
                  StatusLegend(termCounts: ctrl.termCounts),
                if (ctrl.isSelectionMode)
                  Container(
                    padding: const EdgeInsets.all(AppConstants.spacingM),
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
                            l10n.wordsSelected(
                              ctrl.selectedWordIndices.length,
                            ),
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
                    textDirection: ctrl.language.rightToLeft
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppConstants.spacingL),
                      itemCount: ctrl.paragraphs.length,
                      itemBuilder: (context, index) {
                        final para = ctrl.paragraphs[index];
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
                          fontSize: ctrl.fontSize,
                          selectedWordIndices: ctrl.selectedWordIndices,
                          otherLanguageTerms: ctrl.otherLanguageTerms,
                          translationsMap: ctrl.translationsMap,
                          translationsById: ctrl.translationsById,
                          termsById: ctrl.termsById,
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
