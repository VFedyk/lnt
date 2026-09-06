import 'package:flutter/material.dart';

import '../../data/services/deepl_service.dart';
import '../../data/services/libretranslate_service.dart';
import '../../domain/entities/dictionary.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/term.dart';
import '../../domain/entities/translation_result.dart';
import '../../domain/value_objects/translation_provider.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../service_locator.dart';
import '../../utils/constants.dart';
import '../../utils/dialog_helpers.dart';
import '../controllers/term_edit_controller.dart';
import '../widgets/shared/base_term_search_dialog.dart';
import '../widgets/term_edit/term_form_section.dart';
import '../widgets/term_edit/term_history_view.dart';
import '../widgets/term_edit/term_sentences_view.dart';
import '../widgets/term_edit/term_translation_list.dart';

export '../controllers/term_edit_controller.dart' show TermEditResult;

/// Full-screen term editor: Edit / Sentences / History tabs. Replaces the old
/// `TermDialog` bottom-sheet / AlertDialog on every platform.
class TermEditScreen extends StatefulWidget {
  final Term term;
  final String sentence;

  /// Id of the text [sentence] was taken from (reader entry points only), so a
  /// sentence stored from it keeps its provenance. Null elsewhere.
  final String? sourceTextId;

  final List<Dictionary> dictionaries;
  final Function(BuildContext, Dictionary) onLookup;
  final String languageId;
  final String languageName;
  final String languageCode;

  const TermEditScreen({
    super.key,
    required this.term,
    required this.sentence,
    this.sourceTextId,
    required this.dictionaries,
    required this.onLookup,
    required this.languageId,
    required this.languageName,
    required this.languageCode,
  });

  static Future<TermEditResult?> open(
    BuildContext context, {
    required Term term,
    required String sentence,
    String? sourceTextId,
    required List<Dictionary> dictionaries,
    required Function(BuildContext, Dictionary) onLookup,
    required String languageId,
    required String languageName,
    required String languageCode,
  }) {
    return Navigator.push<TermEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => TermEditScreen(
          term: term,
          sentence: sentence,
          sourceTextId: sourceTextId,
          dictionaries: dictionaries,
          onLookup: onLookup,
          languageId: languageId,
          languageName: languageName,
          languageCode: languageCode,
        ),
      ),
    );
  }

  @override
  State<TermEditScreen> createState() => _TermEditScreenState();
}

class _TermEditScreenState extends State<TermEditScreen> {
  late TermEditController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TermEditController(
      term: widget.term,
      sentence: widget.sentence,
      sourceTextId: widget.sourceTextId,
      languageId: widget.languageId,
      languageName: widget.languageName,
      languageCode: widget.languageCode,
    );
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  // ── Event handlers ──

  Future<void> _handleTranslate(TranslationProvider provider) async {
    final result = await _controller.translateAndAdd(provider);
    if (result != null && mounted) {
      final l10n = AppLocalizations.of(context);
      final message = result.error == TranslationError.unsupportedLanguage
          ? l10n.languageNotSupported(_controller.selectedLanguageName)
          : _translationErrorMessage(l10n, result.error!);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _handleAiTranslate() async {
    try {
      await _controller.aiTranslateWord();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).aiTranslateFailed)),
        );
      }
    }
  }

  Future<void> _handleSelectBaseTranslation(int index) async {
    final selectedTerm = await showDialog<Term?>(
      context: context,
      builder: (ctx) => BaseTermSearchDialog(
        languageId: _controller.selectedLanguageId,
        languageName: _controller.selectedLanguageName,
        languageCode: _controller.selectedLanguageCode,
        excludeTermId: widget.term.id,
        initialWord: _controller.termController.text,
      ),
    );
    if (selectedTerm == null || !mounted) return;

    final termTranslations =
        await _controller.loadTranslationsForTerm(selectedTerm);
    if (!mounted) return;

    if (termTranslations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No translations available for this term')),
      );
      return;
    }

    if (termTranslations.length == 1) {
      _controller.setBaseTranslation(index, selectedTerm, termTranslations.first);
      return;
    }

    final selected = await showDialog<Translation?>(
      context: context,
      builder: (ctx) => TranslationPickerDialog(
        term: selectedTerm,
        translations: termTranslations,
      ),
    );
    if (selected != null && mounted) {
      _controller.setBaseTranslation(index, selectedTerm, selected);
    }
  }

  String _translationErrorMessage(AppLocalizations l10n, TranslationError error) {
    return switch (error) {
      TranslationError.authFailed => l10n.translationAuthFailed,
      TranslationError.rateLimited => l10n.translationRateLimited,
      TranslationError.networkError => l10n.translationNetworkError,
      TranslationError.serverError => l10n.translationServerError,
      TranslationError.unsupportedLanguage =>
        l10n.languageNotSupported(_controller.selectedLanguageName),
    };
  }

  Future<bool> _confirmDiscard() async {
    if (!_controller.isDirty) return true;
    final l10n = AppLocalizations.of(context);
    final ok = await DialogHelpers.showConfirmationDialog(
      context,
      title: l10n.discardChanges,
      message: l10n.discardChangesBody,
      confirmText: l10n.discardChanges,
      isDestructive: true,
    );
    return ok == true;
  }

  // ── Build ──

  Widget _buildLanguageLabel(AppLocalizations l10n) {
    final currentLang = _controller.languages.cast<Language?>().firstWhere(
          (l) => l!.id == _controller.selectedLanguageId,
          orElse: () => null,
        );
    final flag = currentLang?.flagEmoji ?? '';
    final name = currentLang?.name ?? _controller.selectedLanguageName;

    final label = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (flag.isNotEmpty) ...[
          Text(flag),
          const SizedBox(width: AppConstants.spacingXS),
        ],
        Flexible(
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppConstants.fontSizeCaption,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (_controller.languages.length > 1)
          Icon(
            Icons.arrow_drop_down,
            size: AppConstants.iconSizeS,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      ],
    );

    if (_controller.languages.length <= 1) return label;

    return PopupMenuButton<Language>(
      onSelected: _controller.changeLanguage,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      position: PopupMenuPosition.under,
      child: label,
      itemBuilder: (context) => _controller.languages.map((lang) {
        final isDeepLSupported =
            DeepLService.deeplCode(lang.languageCode) != null;
        final isLTSupported =
            LibreTranslateService.libreCode(lang.languageCode) != null;
        final isSupported = (_controller.hasDeepL && isDeepLSupported) ||
            (_controller.hasLibreTranslate && isLTSupported);
        return PopupMenuItem(
          value: lang,
          child: Row(
            children: [
              if (lang.flagEmoji.isNotEmpty) ...[
                Text(lang.flagEmoji),
                const SizedBox(width: AppConstants.spacingS),
              ],
              Text(
                lang.name +
                    (_controller.hasAnyTranslationProvider && !isSupported
                        ? l10n.noDeepL
                        : ''),
                style: TextStyle(
                  color: _controller.hasAnyTranslationProvider && !isSupported
                      ? Colors.grey
                      : null,
                ),
              ),
              if (lang.id == _controller.selectedLanguageId) ...[
                const Spacer(),
                const Icon(Icons.check, size: 18),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n) {
    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.term.lowerText,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.term.text != widget.term.lowerText)
            Text(
              l10n.original(widget.term.text),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppConstants.fontSizeCaption,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          _buildLanguageLabel(l10n),
        ],
      ),
      actions: [
        if (widget.languageCode.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: l10n.pronounce,
            onPressed: () =>
                ttsService.speak(widget.term.lowerText, widget.languageCode),
          ),
        if (widget.dictionaries.isNotEmpty)
          PopupMenuButton<Dictionary>(
            icon: const Icon(Icons.search),
            tooltip: l10n.lookupInDictionary,
            onSelected: (dict) => widget.onLookup(context, dict),
            itemBuilder: (context) => widget.dictionaries
                .map((dict) =>
                    PopupMenuItem(value: dict, child: Text(dict.name)))
                .toList(),
          ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, _controller.buildSaveResult()),
          child: Text(l10n.save),
        ),
        if (widget.term.id != null)
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') {
                Navigator.pop(context, _controller.buildDeleteResult());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  l10n.delete,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
      ],
      bottom: TabBar(
        tabs: [
          Tab(text: l10n.edit),
          Tab(text: l10n.sentences),
          Tab(text: l10n.history),
        ],
      ),
    );
  }

  Widget _buildEditTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TermFormSection(controller: _controller, originalTerm: widget.term),
          const SizedBox(height: AppConstants.spacingL),
          TermTranslationList(
            controller: _controller,
            onTranslate: _handleTranslate,
            onAiTranslate: _handleAiTranslate,
            onSelectBaseTranslation: _handleSelectBaseTranslation,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard()) {
          navigator.pop();
        }
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: _buildAppBar(l10n),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppConstants.dialogWidth),
              child: TabBarView(
                children: [
                  _buildEditTab(l10n),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spacingL,
                    ),
                    child: TermSentencesView(
                      controller: _controller,
                      termText: widget.term.text,
                      termStatus: _controller.status,
                      suggestion: widget.sentence,
                    ),
                  ),
                  TermHistoryView(controller: _controller, term: widget.term),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
