import 'package:flutter/material.dart';

import '../../../domain/entities/language.dart';
import '../../../services/text_parser_service.dart';
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

  /// When supplied, the term is located with the language's word pattern
  /// instead of a bare substring search, so `on` cannot match inside `London`.
  final Language? language;

  const HighlightedSentence({
    super.key,
    required this.sentence,
    required this.termText,
    required this.status,
    this.fontSize,
    this.textAlign = TextAlign.center,
    this.maxLines = 3,
    this.italic = true,
    this.language,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
    );

    final range = TextParserService.findOccurrence(
      sentence,
      termText.toLowerCase(),
      language: language,
    );

    if (range == null) {
      return Text(
        sentence,
        style: baseStyle,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
      );
    }

    final before = sentence.substring(0, range.start);
    final match = sentence.substring(range.start, range.end);
    final after = sentence.substring(range.end);

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
