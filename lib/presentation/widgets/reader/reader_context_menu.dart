import 'package:flutter/material.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';

enum ReaderContextMenuAction {
  saveAsTerm,
  mineSentence,
  assignForeignLanguage,
  lookupInDictionary,
  aiMeaning,
  aiGrammar,
  aiWordForms,
}

abstract class ReaderScreenConstants {
  static const double fontSizeMin = 12.0;
  static const double fontSizeMax = 32.0;
  static const int fontSizeSliderDivisions = 20;
  static const double editIconSize = 18.0;
}

Future<ReaderContextMenuAction?> showReaderContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required bool hasExistingTerm,
  required AppLocalizations l10n,
}) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;

  return showMenu<ReaderContextMenuAction>(
    context: context,
    position: RelativeRect.fromRect(
      globalPosition & Size.zero,
      Offset.zero & overlay.size,
    ),
    items: [
      PopupMenuItem(
        value: ReaderContextMenuAction.saveAsTerm,
        child: Row(children: [
          const Icon(Icons.add),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(child: Text(l10n.saveAsTerm)),
        ]),
      ),
      if (hasExistingTerm)
        PopupMenuItem(
          value: ReaderContextMenuAction.mineSentence,
          child: Row(children: [
            const Icon(Icons.push_pin_outlined),
            const SizedBox(width: AppConstants.spacingS),
            Expanded(child: Text(l10n.mineSentence)),
          ]),
        ),
      PopupMenuItem(
        value: ReaderContextMenuAction.assignForeignLanguage,
        child: Row(children: [
          const Icon(Icons.language),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(child: Text(l10n.assignForeignLanguage)),
        ]),
      ),
      PopupMenuItem(
        value: ReaderContextMenuAction.lookupInDictionary,
        child: Row(children: [
          const Icon(Icons.search),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(child: Text(l10n.lookupInDictionary)),
        ]),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: ReaderContextMenuAction.aiMeaning,
        child: Row(children: [
          const Icon(Icons.lightbulb_outline),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(child: Text(l10n.explainMeaningInContext)),
        ]),
      ),
      PopupMenuItem(
        value: ReaderContextMenuAction.aiGrammar,
        child: Row(children: [
          const Icon(Icons.rule),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(child: Text(l10n.explainGrammarInContext)),
        ]),
      ),
      PopupMenuItem(
        value: ReaderContextMenuAction.aiWordForms,
        child: Row(children: [
          const Icon(Icons.table_chart_outlined),
          const SizedBox(width: AppConstants.spacingS),
          Expanded(child: Text(l10n.showWordForms)),
        ]),
      ),
    ],
  );
}
