import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/term.dart';
import '../models/word_token.dart';

class WordListDrawer extends StatelessWidget {
  final List<WordToken> wordTokens;
  final void Function(String word, int position, int tokenIndex) onWordTap;

  static const double _spacing = 16.0;
  static const double _dividerHeight = 1.0;

  const WordListDrawer({
    super.key,
    required this.wordTokens,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Group unique words by status
    final wordsByStatus = <int, List<WordToken>>{};
    final seenWords = <String>{};

    for (final token in wordTokens) {
      if (!token.isWord) continue;
      final normalized = token.text.toLowerCase();
      if (seenWords.contains(normalized)) continue;
      seenWords.add(normalized);

      final status = token.term?.status ?? TermStatus.unknown;
      wordsByStatus.putIfAbsent(status, () => []).add(token);
    }

    // Sort words alphabetically within each group
    for (final list in wordsByStatus.values) {
      list.sort(
        (a, b) => a.text.toLowerCase().compareTo(b.text.toLowerCase()),
      );
    }

    final statusOrder = [
      TermStatus.unknown,
      TermStatus.learning2,
      TermStatus.learning3,
      TermStatus.learning4,
      TermStatus.known,
      TermStatus.wellKnown,
      TermStatus.ignored,
    ];

    final statusLabels = {
      TermStatus.unknown: l10n.statusUnknown,
      TermStatus.learning2: l10n.statusLearning2,
      TermStatus.learning3: l10n.statusLearning3,
      TermStatus.learning4: l10n.statusLearning4,
      TermStatus.known: l10n.statusKnown,
      TermStatus.wellKnown: l10n.statusWellKnown,
      TermStatus.ignored: l10n.statusIgnored,
    };

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(_spacing),
              child: Text(
                l10n.wordList,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: _dividerHeight),
            Expanded(
              child: ListView(
                children: [
                  for (final status in statusOrder)
                    if (wordsByStatus.containsKey(status) &&
                        wordsByStatus[status]!.isNotEmpty)
                      _StatusSection(
                        label: statusLabels[status]!,
                        tokens: wordsByStatus[status]!,
                        color: TermStatus.colorFor(status),
                        allTokens: wordTokens,
                        onWordTap: onWordTap,
                        isInitiallyExpanded:
                            statusLabels[status] == l10n.statusUnknown,
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusSection extends StatelessWidget {
  final String label;
  final List<WordToken> tokens;
  final Color color;
  final List<WordToken> allTokens;
  final void Function(String word, int position, int tokenIndex) onWordTap;
  final bool isInitiallyExpanded;

  static const double _spacing = 16.0;
  static const double _spacingS = 8.0;
  static const double _statusCircleRadius = 8.0;
  static const int _chipBackgroundAlpha = 50;
  static const int _chipBorderAlpha = 100;

  const _StatusSection({
    required this.label,
    required this.tokens,
    required this.color,
    required this.allTokens,
    required this.onWordTap,
    required this.isInitiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: isInitiallyExpanded,
      leading: CircleAvatar(
        backgroundColor: color,
        radius: _statusCircleRadius,
      ),
      title: Text('$label (${tokens.length})'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _spacing,
            vertical: _spacingS,
          ),
          child: Wrap(
            spacing: _spacingS,
            runSpacing: _spacingS,
            children: tokens.map((token) {
              return ActionChip(
                label: Text(token.text),
                backgroundColor: color.withAlpha(_chipBackgroundAlpha),
                side: BorderSide(
                  color: color.withAlpha(_chipBorderAlpha),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close drawer
                  onWordTap(
                    token.text,
                    token.position,
                    allTokens.indexOf(token),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
