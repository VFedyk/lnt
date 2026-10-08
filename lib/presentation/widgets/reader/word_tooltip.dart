import 'package:flutter/material.dart';

import '../../../domain/entities/term.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../controllers/reader_controller.dart';
import '../../theme/term_status_ui.dart';

/// What the reader tooltip shows for one word. Empty fields are omitted.
class WordTooltipData {
  final String romanization;
  final String ipa;
  final List<String> translationLines;

  /// Foreign words only; '' otherwise.
  final String languageName;
  final int sentenceCount;

  const WordTooltipData({
    this.romanization = '',
    this.ipa = '',
    this.translationLines = const [],
    this.languageName = '',
    this.sentenceCount = 0,
  });

  bool get isEmpty =>
      romanization.isEmpty &&
      ipa.isEmpty &&
      translationLines.isEmpty &&
      languageName.isEmpty &&
      sentenceCount == 0;

  factory WordTooltipData.forTerm({
    required Term term,
    List<Translation>? translations,
    required Map<String, Translation> translationsById,
    required Map<String, Term> termsById,
    required int sentenceCount,
    required AppLocalizations l10n,
  }) {
    final lines = <String>[];
    if (translations != null && translations.isNotEmpty) {
      for (final t in translations) {
        final parts = <String>[t.meaning];
        if (t.partOfSpeech != null) {
          parts.add('(${PartOfSpeechUI.localizedNameFor(t.partOfSpeech!, l10n)})');
        }
        if (t.baseTranslationId != null) {
          final baseTranslation = translationsById[t.baseTranslationId!];
          if (baseTranslation != null) {
            final baseTerm = termsById[baseTranslation.termId];
            if (baseTerm != null) {
              parts.add('← ${baseTerm.lowerText} (${baseTranslation.meaning})');
            }
          }
        }
        final line = parts.join(' ');
        if (line.trim().isNotEmpty) lines.add(line);
      }
    } else if (term.translation.isNotEmpty) {
      lines.add(term.translation);
    }
    return WordTooltipData(
      romanization: term.romanization,
      ipa: term.ipa,
      translationLines: lines,
      sentenceCount: sentenceCount,
    );
  }

  factory WordTooltipData.forForeign(
    ForeignTermInfo info,
    AppLocalizations l10n,
  ) {
    final term = info.term;
    final lines = <String>[];
    if (info.translations.isNotEmpty) {
      for (final t in info.translations) {
        final line = t.partOfSpeech != null
            ? '${t.meaning} (${PartOfSpeechUI.localizedNameFor(t.partOfSpeech!, l10n)})'
            : t.meaning;
        if (line.trim().isNotEmpty) lines.add(line);
      }
    } else if (term != null && term.translation.isNotEmpty) {
      lines.add(term.translation);
    }
    return WordTooltipData(
      romanization: term?.romanization ?? '',
      ipa: term?.ipa ?? '',
      translationLines: lines,
      languageName: info.languageName,
      sentenceCount: info.sentenceCount,
    );
  }
}

/// Builds the rich tooltip message. Returns null when [data] is empty.
///
/// No `color` is set on any span: [Tooltip] wraps `richMessage` in a
/// `DefaultTextStyle`, so everything inherits the tooltip's own colors.
InlineSpan? buildWordTooltipSpan(WordTooltipData data, AppLocalizations l10n) {
  if (data.isEmpty) return null;

  const italic = TextStyle(fontStyle: FontStyle.italic);
  final lines = <InlineSpan>[];
  if (data.romanization.isNotEmpty) {
    lines.add(TextSpan(text: data.romanization, style: italic));
  }
  if (data.ipa.isNotEmpty) {
    lines.add(TextSpan(text: data.ipa, style: italic));
  }
  for (final line in data.translationLines) {
    lines.add(TextSpan(text: line));
  }
  if (data.languageName.isNotEmpty) {
    lines.add(TextSpan(text: '(${data.languageName})'));
  }
  if (data.sentenceCount > 0) {
    lines.add(
      TextSpan(
        children: [
          const WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _DimmedIcon(),
          ),
          TextSpan(
            text: ' ${l10n.tooltipExampleCount(data.sentenceCount)}',
            style: italic,
          ),
        ],
      ),
    );
  }

  final children = <InlineSpan>[];
  for (var i = 0; i < lines.length; i++) {
    if (i > 0) children.add(const TextSpan(text: '\n'));
    children.add(lines[i]);
  }
  return TextSpan(children: children);
}

class _DimmedIcon extends StatelessWidget {
  const _DimmedIcon();

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style;
    return Icon(
      Icons.format_quote,
      size: style.fontSize,
      color: style.color?.withValues(alpha: 0.75),
    );
  }
}
