import 'package:material_ui/material_ui.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../../utils/constants.dart';

class ReaderAiExplanationDialog extends StatelessWidget {
  final String title;
  final String selectedText;
  final String contextSentence;
  final String explanation;
  final String closeLabel;

  const ReaderAiExplanationDialog({
    super.key,
    required this.title,
    required this.selectedText,
    required this.contextSentence,
    required this.explanation,
    required this.closeLabel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppConstants.dialogWidth,
          maxHeight: 520,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                selectedText,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppConstants.spacingXS),
              Text(
                contextSentence,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: AppConstants.spacingL),
              MarkdownBody(
                data: explanation,
                selectable: true,
                styleSheet: _markdownStyleSheet(Theme.of(context)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(closeLabel),
        ),
      ],
    );
  }

  /// `flutter_markdown_plus` resolves its default style sheet through
  /// `package:flutter/material.dart`'s `Theme`, which is not the theme the app
  /// installs via `package:material_ui` — so it falls back to a light default
  /// (black text in dark mode). Build the sheet from the app's own theme.
  static MarkdownStyleSheet _markdownStyleSheet(ThemeData theme) {
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final body = (text.bodyMedium ?? const TextStyle(fontSize: 14))
        .copyWith(color: colors.onSurface);
    TextStyle? heading(TextStyle? s) => s?.copyWith(color: colors.onSurface);

    return MarkdownStyleSheet(
      a: TextStyle(color: colors.primary),
      p: body,
      pPadding: EdgeInsets.zero,
      code: body.copyWith(
        backgroundColor: colors.surfaceContainerHighest,
        fontFamily: 'monospace',
        fontSize: (body.fontSize ?? 14) * 0.85,
      ),
      h1: heading(text.headlineSmall),
      h1Padding: EdgeInsets.zero,
      h2: heading(text.titleLarge),
      h2Padding: EdgeInsets.zero,
      h3: heading(text.titleMedium),
      h3Padding: EdgeInsets.zero,
      h4: heading(text.bodyLarge),
      h4Padding: EdgeInsets.zero,
      h5: heading(text.bodyLarge),
      h5Padding: EdgeInsets.zero,
      h6: heading(text.bodyLarge),
      h6Padding: EdgeInsets.zero,
      em: const TextStyle(fontStyle: FontStyle.italic),
      strong: const TextStyle(fontWeight: FontWeight.bold),
      del: const TextStyle(decoration: TextDecoration.lineThrough),
      blockquote: body,
      img: body,
      checkbox: body.copyWith(color: colors.primary),
      blockSpacing: 8.0,
      listIndent: 24.0,
      listBullet: body,
      listBulletPadding: const EdgeInsets.only(right: 4),
      tableHead: const TextStyle(fontWeight: FontWeight.w600),
      tableBody: body,
      tableHeadAlign: TextAlign.center,
      tablePadding: const EdgeInsets.only(bottom: 4.0),
      tableBorder: TableBorder.all(color: colors.outlineVariant),
      tableColumnWidth: const FlexColumnWidth(),
      tableCellsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      tableCellsDecoration: const BoxDecoration(),
      blockquotePadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      blockquoteDecoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(3),
        border: Border(left: BorderSide(color: colors.primary, width: 3)),
      ),
      codeblockPadding: const EdgeInsets.all(8.0),
      codeblockDecoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(2.0),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(width: 1.0, color: colors.outlineVariant),
        ),
      ),
    );
  }
}
