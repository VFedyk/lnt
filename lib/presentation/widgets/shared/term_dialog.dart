export '../../controllers/term_dialog_controller.dart' show TermDialogResult;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../theme/term_status_ui.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../domain/entities/term.dart';
import '../../../domain/entities/dictionary.dart';
import '../../../domain/entities/language.dart';
import '../../../domain/entities/translation_result.dart';
import '../../../domain/value_objects/term_status.dart';
import '../../../domain/value_objects/part_of_speech.dart';
import '../../../domain/value_objects/translation_provider.dart';
import '../../../data/services/deepl_service.dart';
import '../../../data/services/libretranslate_service.dart';
import '../../../service_locator.dart';
import '../../../utils/constants.dart';
import '../../../utils/helpers.dart';
import 'base_term_search_dialog.dart';
import '../../controllers/term_dialog_controller.dart';

abstract class _TermDialogConstants {
  static const double closeIconSize = 18.0;
  static const int sentenceMaxLines = 3;
  static const double minIconHitTarget = 32.0;
}

class TermDialog extends StatefulWidget {
  final Term term;
  final String sentence;
  final List<Dictionary> dictionaries;
  final Function(BuildContext, Dictionary) onLookup;
  final String languageId;
  final String languageName;
  final String languageCode;
  final bool isSheet;

  const TermDialog({
    super.key,
    required this.term,
    required this.sentence,
    required this.dictionaries,
    required this.onLookup,
    required this.languageId,
    required this.languageName,
    required this.languageCode,
    this.isSheet = false,
  });

  static Future<TermDialogResult?> show(
    BuildContext context, {
    required Term term,
    required String sentence,
    required List<Dictionary> dictionaries,
    required Function(BuildContext, Dictionary) onLookup,
    required String languageId,
    required String languageName,
    required String languageCode,
  }) {
    final isSheet = !PlatformHelper.isDesktop;
    if (!isSheet) {
      return showDialog<TermDialogResult>(
        context: context,
        builder: (_) => TermDialog(
          term: term,
          sentence: sentence,
          dictionaries: dictionaries,
          onLookup: onLookup,
          languageId: languageId,
          languageName: languageName,
          languageCode: languageCode,
          isSheet: false,
        ),
      );
    }
    return showModalBottomSheet<TermDialogResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TermDialog(
        term: term,
        sentence: sentence,
        dictionaries: dictionaries,
        onLookup: onLookup,
        languageId: languageId,
        languageName: languageName,
        languageCode: languageCode,
        isSheet: true,
      ),
    );
  }

  @override
  State<TermDialog> createState() => _TermDialogState();
}

class _TermDialogState extends State<TermDialog> {
  late TermDialogController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TermDialogController(
      term: widget.term,
      sentence: widget.sentence,
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

  // ---------------------------------------------------------------------------
  // Event handlers (need BuildContext for dialogs / SnackBars)
  // ---------------------------------------------------------------------------

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
          SnackBar(
            content: Text(AppLocalizations.of(context).aiTranslateFailed),
          ),
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
        const SnackBar(
          content: Text('No translations available for this term'),
        ),
      );
      return;
    }

    if (termTranslations.length == 1) {
      _controller.setBaseTranslation(index, selectedTerm, termTranslations.first);
      return;
    }

    final selected = await showDialog<Translation?>(
      context: context,
      builder: (ctx) => _TranslationPickerDialog(
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

  // ---------------------------------------------------------------------------
  // Build helpers
  // ---------------------------------------------------------------------------

  Widget _buildLanguageLabel(AppLocalizations l10n) {
    final currentLang = _controller.languages.cast<Language?>().firstWhere(
      (l) => l!.id == _controller.selectedLanguageId,
      orElse: () => null,
    );
    final flag = currentLang?.flagEmoji ?? '';
    final name = currentLang?.name ?? _controller.selectedLanguageName;

    final label = Padding(
      padding: const EdgeInsets.only(top: AppConstants.spacingXS),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (flag.isNotEmpty) ...[
            Text(flag),
            const SizedBox(width: AppConstants.spacingXS),
          ],
          Text(
            name,
            style: TextStyle(
              fontSize: AppConstants.fontSizeCaption,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_controller.languages.length > 1)
            Icon(
              Icons.arrow_drop_down,
              size: AppConstants.iconSizeS,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
        ],
      ),
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
        final isSupported =
            (_controller.hasDeepL && isDeepLSupported) ||
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

  Widget _buildTitleRow(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.term.lowerText,
                style: const TextStyle(fontSize: AppConstants.fontSizeTitle),
              ),
              if (widget.term.text != widget.term.lowerText)
                Text(
                  l10n.original(widget.term.text),
                  style: TextStyle(
                    fontSize: AppConstants.fontSizeCaption,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              _buildLanguageLabel(l10n),
            ],
          ),
        ),
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
                .map(
                  (dict) => PopupMenuItem(value: dict, child: Text(dict.name)),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildSecondaryFields(AppLocalizations l10n) {
    final hasContent =
        _controller.romanizationController.text.isNotEmpty ||
        _controller.sentenceController.text.isNotEmpty;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: hasContent || _controller.isSelectedLanguageChinese,
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        title: Text(
          l10n.more,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppConstants.fontSizeBody,
          ),
        ),
        children: [
          const SizedBox(height: AppConstants.spacingXS),
          TextField(
            controller: _controller.romanizationController,
            decoration: InputDecoration(
              labelText: l10n.romanizationPronunciation,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppConstants.spacingM),
          TextField(
            controller: _controller.sentenceController,
            decoration: InputDecoration(
              labelText: l10n.exampleSentence,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: _TermDialogConstants.sentenceMaxLines,
          ),
          const SizedBox(height: AppConstants.spacingS),
        ],
      ),
    );
  }

  Widget _buildFormBody(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TermFormSection(controller: _controller, originalTerm: widget.term),
        const SizedBox(height: AppConstants.spacingL),
        _TranslationListSection(
          controller: _controller,
          onTranslate: _handleTranslate,
          onAiTranslate: _handleAiTranslate,
          onSelectBaseTranslation: _handleSelectBaseTranslation,
        ),
        const SizedBox(height: AppConstants.spacingM),
        _buildSecondaryFields(l10n),
      ],
    );
  }

  List<Widget> _buildActionButtons(AppLocalizations l10n) {
    return [
      if (widget.term.id != null)
        TextButton(
          onPressed: () =>
              Navigator.pop(context, _controller.buildDeleteResult()),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.error,
          ),
          child: Text(l10n.delete),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.cancel),
      ),
      TextButton(
        onPressed: () =>
            Navigator.pop(context, _controller.buildSaveResult()),
        child: Text(l10n.save),
      ),
    ];
  }

  Widget _buildDialog(AppLocalizations l10n) {
    return AlertDialog(
      title: _buildTitleRow(l10n),
      content: SizedBox(
        width: AppConstants.dialogWidth,
        child: SingleChildScrollView(child: _buildFormBody(l10n)),
      ),
      actions: _buildActionButtons(l10n),
    );
  }

  Widget _buildSheet(AppLocalizations l10n) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final safePadBottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingL,
                0,
                AppConstants.spacingS,
                AppConstants.spacingS,
              ),
              child: _buildTitleRow(l10n),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: _buildFormBody(l10n),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppConstants.spacingS,
                AppConstants.spacingXS,
                AppConstants.spacingS,
                AppConstants.spacingXS + math.max(safePadBottom, 0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _buildActionButtons(l10n),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return widget.isSheet ? _buildSheet(l10n) : _buildDialog(l10n);
  }
}

// ---------------------------------------------------------------------------
// Section widgets
// ---------------------------------------------------------------------------

class _TermFormSection extends StatelessWidget {
  final TermDialogController controller;
  final Term originalTerm;

  const _TermFormSection({
    required this.controller,
    required this.originalTerm,
  });

  Widget _buildTermField(AppLocalizations l10n) {
    return TextField(
      controller: controller.termController,
      decoration: InputDecoration(
        labelText: l10n.term,
        border: const OutlineInputBorder(),
        suffixIcon: originalTerm.text != originalTerm.lowerText
            ? IconButton(
                icon: const Icon(Icons.history),
                tooltip: l10n.useOriginal(originalTerm.text),
                onPressed: () {
                  controller.termController.text = originalTerm.text;
                },
              )
            : null,
      ),
      onChanged: (_) => controller.maybeAutoFillRomanization(),
    );
  }

  Widget _buildStatusRow(AppLocalizations l10n) {
    return Row(
      children: [
        Text(l10n.status, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: AppConstants.spacingS),
        Chip(
          avatar: CircleAvatar(
            backgroundColor: TermStatusUI.colorFor(controller.status),
            radius: AppConstants.spacingS,
          ),
          label: Text(
            TermStatusUI.localizedNameFor(controller.status, l10n),
            style: const TextStyle(fontSize: AppConstants.fontSizeCaption),
          ),
        ),
        const Spacer(),
        if (controller.status == TermStatus.ignored)
          TextButton(
            onPressed: () => controller.updateStatus(TermStatus.unknown),
            child: Text(l10n.unignore),
          )
        else ...[
          if (controller.status != TermStatus.wellKnown)
            TextButton(
              onPressed: () => controller.updateStatus(TermStatus.wellKnown),
              child: Text(l10n.markWellKnown),
            ),
          TextButton(
            onPressed: () => controller.updateStatus(TermStatus.ignored),
            child: Text(l10n.ignore),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTermField(l10n),
        const SizedBox(height: AppConstants.spacingM),
        _buildStatusRow(l10n),
      ],
    );
  }
}

class _TranslationListSection extends StatelessWidget {
  final TermDialogController controller;
  final Future<void> Function(TranslationProvider) onTranslate;
  final Future<void> Function() onAiTranslate;
  final Future<void> Function(int) onSelectBaseTranslation;

  const _TranslationListSection({
    required this.controller,
    required this.onTranslate,
    required this.onAiTranslate,
    required this.onSelectBaseTranslation,
  });

  Widget _buildBaseTermSelector(
    BuildContext context,
    AppLocalizations l10n,
    int index,
    Translation translation,
  ) {
    final baseInfo = translation.baseTranslationId != null
        ? controller.baseTranslations[translation.baseTranslationId!]
        : null;

    if (baseInfo != null) {
      return Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.baseForm,
                  style: TextStyle(
                    fontSize: AppConstants.fontSizeCaption,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  baseInfo.term.lowerText,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  baseInfo.translation.meaning,
                  style: TextStyle(
                    fontSize: AppConstants.fontSizeCaption,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: _TermDialogConstants.minIconHitTarget,
            height: _TermDialogConstants.minIconHitTarget,
            child: IconButton(
              icon: Icon(
                Icons.close,
                size: _TermDialogConstants.closeIconSize,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              onPressed: () => controller.clearBaseTranslation(index),
            ),
          ),
        ],
      );
    }

    return InkWell(
      onTap: () { onSelectBaseTranslation(index); },
      child: Row(
        children: [
          Icon(
            Icons.add_link,
            size: AppConstants.iconSizeS,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppConstants.spacingXS),
          Text(l10n.baseForm, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildTranslationItem(
    BuildContext context,
    AppLocalizations l10n,
    int index,
    Translation translation,
  ) {
    return Container(
      key: ValueKey(controller.translationKeys[index]),
      margin: const EdgeInsets.only(bottom: AppConstants.spacingS),
      padding: const EdgeInsets.all(AppConstants.spacingS),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppConstants.borderRadiusS),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: translation.meaning,
                  decoration: InputDecoration(
                    labelText: l10n.meaning,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (value) {
                    controller.updateTranslation(
                      index,
                      controller.translations[index].copyWith(meaning: value),
                    );
                  },
                ),
              ),
              SizedBox(
                width: _TermDialogConstants.minIconHitTarget,
                height: _TermDialogConstants.minIconHitTarget,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    size: _TermDialogConstants.closeIconSize,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => controller.removeTranslation(index),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXS),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String?>(
                  value: translation.partOfSpeech,
                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: Text(
                    l10n.partOfSpeech,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        '—',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ),
                    ...PartOfSpeech.all.map(
                      (pos) => DropdownMenuItem(
                        value: pos,
                        child: Text(PartOfSpeechUI.localizedNameFor(pos, l10n)),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    controller.updateTranslation(
                      index,
                      controller.translations[index].copyWith(
                        partOfSpeech: value,
                        clearPartOfSpeech: value == null,
                      ),
                      rebuild: true,
                    );
                  },
                ),
              ),
              const SizedBox(width: AppConstants.spacingM),
              Expanded(
                child: _buildBaseTermSelector(context, l10n, index, translation),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.translations,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (controller.hasAnyTranslationProvider)
                  if (controller.isTranslating)
                    const SizedBox(
                      width: AppConstants.progressIndicatorSizeS,
                      height: AppConstants.progressIndicatorSizeS,
                      child: CircularProgressIndicator(
                        strokeWidth: AppConstants.progressStrokeWidth,
                      ),
                    )
                  else if (controller.hasMultipleTranslationProviders)
                    PopupMenuButton<TranslationProvider>(
                      icon: const Icon(
                        Icons.translate,
                        size: AppConstants.iconSizeS,
                      ),
                      tooltip: l10n.translate,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onSelected: (p) { onTranslate(p); },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: TranslationProvider.deepL,
                          child: Text(l10n.translateWithDeepL),
                        ),
                        PopupMenuItem(
                          value: TranslationProvider.libreTranslate,
                          child: Text(l10n.translateWithLibreTranslate),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: _TermDialogConstants.minIconHitTarget,
                      height: _TermDialogConstants.minIconHitTarget,
                      child: IconButton(
                        icon: const Icon(
                          Icons.translate,
                          size: AppConstants.iconSizeS,
                        ),
                        tooltip: controller.hasDeepL
                            ? l10n.translateWithDeepL
                            : l10n.translateWithLibreTranslate,
                        onPressed: () {
                          onTranslate(
                            controller.hasDeepL
                                ? TranslationProvider.deepL
                                : TranslationProvider.libreTranslate,
                          );
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ),
                if (controller.hasAnyTranslationProvider && controller.hasAi)
                  const SizedBox(width: AppConstants.spacingS),
                if (controller.hasAi)
                  if (controller.isAiTranslating)
                    const SizedBox(
                      width: AppConstants.progressIndicatorSizeS,
                      height: AppConstants.progressIndicatorSizeS,
                      child: CircularProgressIndicator(
                        strokeWidth: AppConstants.progressStrokeWidth,
                      ),
                    )
                  else
                    SizedBox(
                      width: _TermDialogConstants.minIconHitTarget,
                      height: _TermDialogConstants.minIconHitTarget,
                      child: IconButton(
                        icon: const Icon(
                          Icons.auto_awesome,
                          size: AppConstants.iconSizeS,
                        ),
                        tooltip: l10n.translateWithAi,
                        onPressed: () { onAiTranslate(); },
                        padding: EdgeInsets.zero,
                      ),
                    ),
                SizedBox(
                  width: _TermDialogConstants.minIconHitTarget,
                  height: _TermDialogConstants.minIconHitTarget,
                  child: IconButton(
                    icon: const Icon(Icons.add, size: AppConstants.iconSizeS),
                    tooltip: l10n.addTranslation,
                    onPressed: controller.addTranslation,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingS),
        if (controller.translations.isEmpty)
          Text(
            l10n.addTranslation,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          ...controller.translations.asMap().entries.map(
            (entry) => _buildTranslationItem(context, l10n, entry.key, entry.value),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Picker dialog for selecting one of multiple base-form translations
// ---------------------------------------------------------------------------

class _TranslationPickerDialog extends StatelessWidget {
  final Term term;
  final List<Translation> translations;

  const _TranslationPickerDialog({
    required this.term,
    required this.translations,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(term.lowerText),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: translations.map((t) {
            return ListTile(
              title: Text(t.meaning),
              subtitle: t.partOfSpeech != null
                  ? Text(PartOfSpeechUI.localizedNameFor(t.partOfSpeech!, l10n))
                  : null,
              onTap: () => Navigator.pop(context, t),
            );
          }).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
