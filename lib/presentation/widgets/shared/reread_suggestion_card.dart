import 'package:flutter/material.dart';

import '../../../domain/entities/language.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../service_locator.dart';
import '../../../services/logger_service.dart';
import '../../../utils/constants.dart';
import '../../screens/reader_screen.dart';

/// Shown on the review completion screen when the words just failed cluster in
/// a particular text. Renders nothing when there is no good candidate.
///
/// This is the loop closing: read → collect → review → *read again*.
class RereadSuggestionCard extends StatefulWidget {
  const RereadSuggestionCard({
    super.key,
    required this.language,
    required this.failedTermIds,
    this.excludeTextId,
  });

  final Language language;
  final Set<String> failedTermIds;

  /// The text this session was scoped to; never suggested back to the user.
  final String? excludeTextId;

  /// One failure is noise — below this a session says nothing.
  static const int minFailedTerms = 2;

  /// Keeps the SQL placeholder list small and picks the words that hurt most.
  static const int maxCandidates = 20;

  @override
  State<RereadSuggestionCard> createState() => _RereadSuggestionCardState();
}

class _RereadSuggestionCardState extends State<RereadSuggestionCard> {
  List<({String textId, String title, int hits})> _texts = const [];
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.failedTermIds.length < RereadSuggestionCard.minFailedTerms) {
      return;
    }
    final languageId = widget.language.id;
    if (languageId == null) return;

    try {
      final failed = widget.failedTermIds.toList();
      final lapses = await db.reviewLogs.getLapseCounts(failed);

      // Prefer words the user keeps missing; a fresh cluster with no history is
      // still worth surfacing, so fall back to every failure this session.
      var candidates = failed.where((id) => (lapses[id] ?? 0) >= 2).toList();
      if (candidates.length < RereadSuggestionCard.minFailedTerms) {
        candidates = failed;
      }
      candidates.sort((a, b) => (lapses[b] ?? 0).compareTo(lapses[a] ?? 0));
      candidates = candidates.take(RereadSuggestionCard.maxCandidates).toList();

      final texts = await db.textWords.textsContainingTerms(
        languageId,
        candidates,
        minHits: 2,
        limit: 3,
      );

      if (!mounted) return;
      setState(() {
        _texts =
            texts.where((t) => t.textId != widget.excludeTextId).toList();
      });
    } catch (e, stackTrace) {
      AppLogger.error('Reread suggestion lookup failed',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _openText(String textId) async {
    final text = await db.texts.getById(textId);
    if (!mounted || text == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ReaderScreen(text: text, language: widget.language),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_texts.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final top = _texts.first;
    final others = _texts.skip(1).toList();

    return Card(
      margin: const EdgeInsets.only(top: AppConstants.spacingL),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.rereadSuggestionTitle(top.hits),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: AppConstants.spacingXS),
                      Text(
                        l10n.rereadSuggestionBody(top.title),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ElevatedButton.icon(
                onPressed: () => _openText(top.textId),
                icon: const Icon(Icons.menu_book),
                label: Text(l10n.openText),
              ),
            ),
            if (others.isNotEmpty) ...[
              if (!_showAll)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => setState(() => _showAll = true),
                    child: Text(l10n.rereadOtherTexts),
                  ),
                )
              else
                ...others.map(
                  (t) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined),
                    title: Text(t.title, overflow: TextOverflow.ellipsis),
                    onTap: () => _openText(t.textId),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
