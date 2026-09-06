import 'package:flutter/material.dart';

import '../../theme/term_status_ui.dart';

/// Renders [sentence] with the first case-insensitive occurrence of [termText]
/// bolded in the term's status colour. Falls back to plain text when the term
/// isn't found in the sentence.
///
/// Shared by the flashcard and cloze review screens and the term-edit
/// Sentences tab.
class HighlightedSentence extends StatelessWidget {
  final String sentence;
  final String termText;
  final int status;
  final double? fontSize;
  final TextAlign textAlign;
  final int? maxLines;
  final bool italic;

  const HighlightedSentence({
    super.key,
    required this.sentence,
    required this.termText,
    required this.status,
    this.fontSize,
    this.textAlign = TextAlign.center,
    this.maxLines = 3,
    this.italic = true,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );

    final lowerSentence = sentence.toLowerCase();
    final lowerTerm = termText.toLowerCase();
    final index = lowerTerm.isEmpty ? -1 : lowerSentence.indexOf(lowerTerm);

    if (index == -1) {
      return Text(
        sentence,
        style: baseStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      );
    }

    final before = sentence.substring(0, index);
    final match = sentence.substring(index, index + termText.length);
    final after = sentence.substring(index + termText.length);

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: TermStatusUI.colorFor(status),
              fontStyle: FontStyle.normal,
            ),
          ),
          TextSpan(text: after),
        ],
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }
}
