import 'package:flutter/material.dart';

import '../../../domain/entities/term.dart';
import '../../../domain/value_objects/part_of_speech.dart';
import '../../../domain/value_objects/translation_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';
import '../../controllers/term_edit_controller.dart';
import '../../theme/term_status_ui.dart' show PartOfSpeechUI;

abstract class _C {
  static const double closeIconSize = 18.0;
  static const double minIconHitTarget = 32.0;
  // Below this width the meaning / part-of-speech / base-form controls stack.
  static const double stackBelow = 480.0;
}

/// Translations list + provider/AI/add actions for the Edit tab.
class TermTranslationList extends StatelessWidget {
  final TermEditController controller;
  final Future<void> Function(TranslationProvider) onTranslate;
  final Future<void> Function() onAiTranslate;
  final Future<void> Function(int) onSelectBaseTranslation;

  const TermTranslationList({
    super.key,
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
            width: _C.minIconHitTarget,
            height: _C.minIconHitTarget,
            child: IconButton(
              icon: Icon(
                Icons.close,
                size: _C.closeIconSize,
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
      onTap: () {
        onSelectBaseTranslation(index);
      },
      child: Row(
        children: [
          Icon(
            Icons.add_link,
            size: AppConstants.iconSizeS,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppConstants.spacingXS),
          Text(l10n.baseForm,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildPosDropdown(
    BuildContext context,
    AppLocalizations l10n,
    int index,
    Translation translation,
  ) {
    return DropdownButton<String?>(
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
            style:
                TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                width: _C.minIconHitTarget,
                height: _C.minIconHitTarget,
                child: IconButton(
                  icon: Icon(
                    Icons.close,
                    size: _C.closeIconSize,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => controller.removeTranslation(index),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXS),
          LayoutBuilder(
            builder: (context, constraints) {
              final pos = _buildPosDropdown(context, l10n, index, translation);
              final base =
                  _buildBaseTermSelector(context, l10n, index, translation);
              if (constraints.maxWidth < _C.stackBelow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    pos,
                    const SizedBox(height: AppConstants.spacingXS),
                    base,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: pos),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(child: base),
                ],
              );
            },
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
                      onSelected: (p) {
                        onTranslate(p);
                      },
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
                      width: _C.minIconHitTarget,
                      height: _C.minIconHitTarget,
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
                      width: _C.minIconHitTarget,
                      height: _C.minIconHitTarget,
                      child: IconButton(
                        icon: const Icon(
                          Icons.auto_awesome,
                          size: AppConstants.iconSizeS,
                        ),
                        tooltip: l10n.translateWithAi,
                        onPressed: () {
                          onAiTranslate();
                        },
                        padding: EdgeInsets.zero,
                      ),
                    ),
                SizedBox(
                  width: _C.minIconHitTarget,
                  height: _C.minIconHitTarget,
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
                (entry) => _buildTranslationItem(
                    context, l10n, entry.key, entry.value),
              ),
      ],
    );
  }
}

/// Picker for selecting one of multiple base-form translations.
class TranslationPickerDialog extends StatelessWidget {
  final Term term;
  final List<Translation> translations;

  const TranslationPickerDialog({
    super.key,
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
