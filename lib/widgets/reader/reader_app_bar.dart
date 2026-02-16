import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../utils/constants.dart';

enum ReaderMoreAction { edit, fontSize, markAllKnown, openDrawer }
enum ReaderSelectionAiAction { meaning, grammar }

class ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isSelectionMode;
  final bool showLegend;
  final bool isFinished;
  final Color? finishedColor;
  final AppLocalizations l10n;
  final VoidCallback onCancelSelection;
  final VoidCallback onSaveSelectionAsTerm;
  final VoidCallback onAssignForeignLanguage;
  final VoidCallback onLookupSelectedWords;
  final ValueChanged<ReaderSelectionAiAction> onSelectionAiSelected;
  final VoidCallback onToggleLegend;
  final VoidCallback onToggleFinished;
  final ValueChanged<ReaderMoreAction> onMoreSelected;

  const ReaderAppBar({
    super.key,
    required this.title,
    required this.isSelectionMode,
    required this.showLegend,
    required this.isFinished,
    required this.finishedColor,
    required this.l10n,
    required this.onCancelSelection,
    required this.onSaveSelectionAsTerm,
    required this.onAssignForeignLanguage,
    required this.onLookupSelectedWords,
    required this.onSelectionAiSelected,
    required this.onToggleLegend,
    required this.onToggleFinished,
    required this.onMoreSelected,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title, overflow: TextOverflow.ellipsis),
      actions: [
        if (isSelectionMode)
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.cancelSelection,
            onPressed: onCancelSelection,
          ),
        if (isSelectionMode)
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.saveAsTerm,
            onPressed: onSaveSelectionAsTerm,
          ),
        if (isSelectionMode)
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: l10n.assignForeignLanguage,
            onPressed: onAssignForeignLanguage,
          ),
        if (isSelectionMode)
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.lookupInDictionary,
            onPressed: onLookupSelectedWords,
          ),
        if (isSelectionMode)
          PopupMenuButton<ReaderSelectionAiAction>(
            icon: const Icon(Icons.auto_awesome),
            tooltip: l10n.aiActions,
            onSelected: onSelectionAiSelected,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ReaderSelectionAiAction.meaning,
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.explainMeaningInContext),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ReaderSelectionAiAction.grammar,
                child: Row(
                  children: [
                    const Icon(Icons.rule),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.explainGrammarInContext),
                  ],
                ),
              ),
            ],
          ),
        if (!isSelectionMode)
          IconButton(
            icon: Icon(showLegend ? Icons.visibility_off : Icons.visibility),
            tooltip: l10n.toggleLegend,
            onPressed: onToggleLegend,
          ),
        if (!isSelectionMode)
          IconButton(
            icon: Icon(
              isFinished ? Icons.check_circle : Icons.check_circle_outline,
              color: isFinished ? finishedColor : null,
            ),
            tooltip: isFinished ? l10n.markedAsFinished : l10n.markAsFinished,
            onPressed: onToggleFinished,
          ),
        if (!isSelectionMode)
          PopupMenuButton<ReaderMoreAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: onMoreSelected,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: ReaderMoreAction.edit,
                child: Row(
                  children: [
                    const Icon(Icons.edit),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.editText),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ReaderMoreAction.fontSize,
                child: Row(
                  children: [
                    const Icon(Icons.text_fields),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.fontSize),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ReaderMoreAction.markAllKnown,
                child: Row(
                  children: [
                    const Icon(Icons.done_all),
                    const SizedBox(width: AppConstants.spacingS),
                    Text(l10n.markAllKnown),
                  ],
                ),
              ),
              PopupMenuItem(
                value: ReaderMoreAction.openDrawer,
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
    );
  }
}
