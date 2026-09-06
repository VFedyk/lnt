import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../../utils/constants.dart';
import '../../../utils/dialog_helpers.dart';
import '../../../utils/helpers.dart';
import '../../controllers/term_edit_controller.dart';
import '../shared/app_empty_state.dart';
import '../shared/highlighted_sentence.dart';

/// "Sentences" tab of the term edit screen. Lists every saved sentence
/// (`term_sentences`), with buffered add / edit / delete flushed on Save.
class TermSentencesView extends StatelessWidget {
  final TermEditController controller;
  final String termText;
  final int termStatus;

  /// Context sentence from the reader, offered as a one-tap suggestion.
  final String suggestion;

  const TermSentencesView({
    super.key,
    required this.controller,
    required this.termText,
    required this.termStatus,
    required this.suggestion,
  });

  Future<String?> _promptSentence(
    BuildContext context, {
    String initial = '',
  }) {
    final l10n = AppLocalizations.of(context);
    final field = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(initial.isEmpty ? l10n.addSentence : l10n.editSentence),
        content: TextField(
          controller: field,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: l10n.exampleSentence,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              final text = field.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(l10n.sentenceCannotBeEmpty)),
                );
                return;
              }
              Navigator.pop(ctx, text);
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (controller.sentencesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final items = controller.visibleSentences;
    final showSuggestion =
        suggestion.trim().isNotEmpty && !controller.hasSentence(suggestion);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.term.id == null)
          Padding(
            padding: const EdgeInsets.only(
              top: AppConstants.spacingS,
              bottom: AppConstants.spacingXS,
            ),
            child: Text(
              l10n.newTermSentencesHint,
              style: TextStyle(
                fontSize: AppConstants.fontSizeCaption,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (showSuggestion)
          Card(
            margin: const EdgeInsets.symmetric(vertical: AppConstants.spacingS),
            child: ListTile(
              leading: const Icon(Icons.add_comment_outlined),
              title: Text(
                suggestion.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: TextButton(
                onPressed: () => controller.addSentence(
                  suggestion,
                  sourceTextId: controller.sourceTextId,
                ),
                child: Text(l10n.useThisSentence),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingS),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () async {
                final text = await _promptSentence(context);
                if (text != null) controller.addSentence(text);
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.addSentence),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? AppEmptyState(
                  icon: Icons.format_quote_outlined,
                  title: l10n.noSentencesYet,
                  subtitle: l10n.noSentencesYetHint,
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppConstants.spacingL),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final s = items[i];
                    final subtitleParts = <String>[
                      if (s.sourceTitle != null)
                        l10n.sentenceFromText(s.sourceTitle!)
                      else
                        l10n.sentenceAddedManually,
                      if (s.createdAt != null)
                        DateHelper.formatDate(s.createdAt!),
                    ];
                    return Card(
                      child: ListTile(
                        title: HighlightedSentence(
                          sentence: s.text,
                          termText: termText,
                          status: termStatus,
                          textAlign: TextAlign.start,
                          maxLines: null,
                          italic: false,
                        ),
                        subtitle: Text(subtitleParts.join(' · ')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined),
                              tooltip: l10n.editSentence,
                              onPressed: () async {
                                final text = await _promptSentence(
                                  context,
                                  initial: s.text,
                                );
                                if (text == null) return;
                                if (s.id != null) {
                                  controller.editSentence(s.id!, text);
                                } else {
                                  controller.editPending(
                                    i - _persistedBefore(items, i),
                                    text,
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: l10n.delete,
                              onPressed: () async {
                                if (s.id != null) {
                                  final ok =
                                      await DialogHelpers.showDestructiveDialog(
                                    context,
                                    title: l10n.deleteSentenceConfirm,
                                    message: s.text,
                                    confirmText: l10n.delete,
                                  );
                                  if (ok != true) return;
                                  controller.removeSentence(s.id!);
                                } else {
                                  controller.removePending(
                                    i - _persistedBefore(items, i),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Count of persisted (id != null) rows at or before [index] — used to map a
  /// visible-list index to a `pendingAdded` index.
  int _persistedBefore(
    List<({String? id, String text, String? sourceTitle, DateTime? createdAt})>
        items,
    int index,
  ) {
    var count = 0;
    for (var i = 0; i <= index; i++) {
      if (items[i].id != null) count++;
    }
    return count;
  }
}
