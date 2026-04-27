import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
                  color: AppConstants.subtitleColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: AppConstants.spacingL),
              MarkdownBody(
                data: explanation,
                selectable: true,
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
}
