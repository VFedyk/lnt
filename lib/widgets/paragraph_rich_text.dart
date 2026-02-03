import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/term.dart';
import '../models/word_token.dart';

class ParagraphRichText extends StatelessWidget {
  final List<WordToken> tokens;
  final double fontSize;
  final Set<int> selectedWordIndices;
  final Map<String, ({Term term, String languageName})> otherLanguageTerms;
  final Map<int, List<Translation>> translationsMap;
  final void Function(String word, int position, int globalIndex) onWordTap;
  final void Function(int globalIndex) onWordLongPress;

  static const double _lineHeight = 1.6;
  static const double _wordPaddingH = 3.0;
  static const double _wordPaddingV = 2.0;
  static const double _wordMarginH = 1.0;
  static const double _wordBorderRadius = 4.0;
  static const double _borderWidthNormal = 1.0;
  static const double _borderWidthSelected = 2.0;
  static const double _backgroundAlpha = 0.3;
  static const double _borderAlpha = 0.5;
  static const Duration _tooltipWait = Duration(milliseconds: 300);

  static const Color _selectionBg = Color(0xFF90CAF9);
  static const Color _selectionBorder = Color(0xFF1E88E5);
  static const Color _selectedText = Colors.black87;
  static const Color _otherLanguageColor = Color(0xFFCE93D8);
  static const Color _transparent = Colors.transparent;

  static final _leadingPunctuation = RegExp(r'^[\p{P}\p{S}]+', unicode: true);

  const ParagraphRichText({
    super.key,
    required this.tokens,
    required this.fontSize,
    required this.selectedWordIndices,
    required this.otherLanguageTerms,
    required this.translationsMap,
    required this.onWordTap,
    required this.onWordLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spans = <InlineSpan>[];
    final textStyle = TextStyle(fontSize: fontSize, height: _lineHeight);

    int skipChars = 0;

    for (int ti = 0; ti < tokens.length; ti++) {
      final token = tokens[ti];
      final globalIndex = token.globalIndex;

      if (!token.isWord) {
        var text = token.text;
        if (skipChars > 0) {
          text = text.substring(skipChars);
          skipChars = 0;
        }
        text = text.replaceAll('\n', '');
        if (text.isNotEmpty) {
          spans.add(TextSpan(text: text, style: textStyle));
        }
        continue;
      }

      // Look ahead: extract leading punctuation from the next non-word token
      String trailingPunct = '';
      if (ti + 1 < tokens.length && !tokens[ti + 1].isWord) {
        final nextText = tokens[ti + 1].text;
        final m = _leadingPunctuation.firstMatch(nextText);
        if (m != null) {
          trailingPunct = m.group(0)!;
          skipChars = trailingPunct.length;
        }
      }

      final term = token.term;
      final isSelected = selectedWordIndices.contains(globalIndex);
      final isIgnored = term?.status == TermStatus.ignored;
      final isWellKnown = term?.status == TermStatus.wellKnown;
      final lowerWord = token.text.toLowerCase();
      final isOtherLanguage =
          term == null && otherLanguageTerms.containsKey(lowerWord);

      Color backgroundColor;
      if (isSelected) {
        backgroundColor = _selectionBg;
      } else if (isIgnored || isWellKnown || isOtherLanguage) {
        backgroundColor = _transparent;
      } else if (term != null) {
        backgroundColor = term.statusColor.withValues(alpha: _backgroundAlpha);
      } else {
        backgroundColor = TermStatus.colorFor(TermStatus.unknown)
            .withValues(alpha: _backgroundAlpha);
      }

      Color borderColor;
      if (isSelected) {
        borderColor = _selectionBorder;
      } else if (isIgnored || isWellKnown || isOtherLanguage) {
        borderColor = _transparent;
      } else if (term != null) {
        borderColor = term.statusColor.withValues(alpha: _borderAlpha);
      } else {
        borderColor = TermStatus.colorFor(TermStatus.unknown)
            .withValues(alpha: _borderAlpha);
      }

      Color? textColor;
      if (isSelected) {
        textColor = _selectedText;
      } else if (isOtherLanguage) {
        textColor = _otherLanguageColor;
      }

      String? tooltipMessage;
      if (term != null) {
        // Get translations from map, fall back to legacy field
        final translations = term.id != null ? translationsMap[term.id!] : null;
        String translationText;
        if (translations != null && translations.isNotEmpty) {
          translationText = translations.map((t) {
            if (t.partOfSpeech != null) {
              return '${t.meaning} (${PartOfSpeech.localizedNameFor(t.partOfSpeech!, l10n)})';
            }
            return t.meaning;
          }).join('\n');
        } else {
          translationText = term.translation;
        }
        if (translationText.isNotEmpty) {
          tooltipMessage = translationText;
          if (term.romanization.isNotEmpty) {
            tooltipMessage = '${term.romanization}\n$tooltipMessage';
          }
        }
      } else if (isOtherLanguage) {
        final otherInfo = otherLanguageTerms[lowerWord]!;
        final otherTerm = otherInfo.term;
        final parts = <String>[];
        if (otherTerm.romanization.isNotEmpty) {
          parts.add(otherTerm.romanization);
        }
        if (otherTerm.translation.isNotEmpty) {
          parts.add(otherTerm.translation);
        }
        if (otherInfo.languageName.isNotEmpty) {
          parts.add('(${otherInfo.languageName})');
        }
        if (parts.isNotEmpty) {
          tooltipMessage = parts.join('\n');
        }
      }

      Widget wordContainer = GestureDetector(
        onTap: () => onWordTap(token.text, token.position, globalIndex),
        onLongPress: () => onWordLongPress(globalIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: _wordPaddingH,
            vertical: _wordPaddingV,
          ),
          margin: const EdgeInsets.symmetric(horizontal: _wordMarginH),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(_wordBorderRadius),
            border: Border.all(
              color: borderColor,
              width: isSelected ? _borderWidthSelected : _borderWidthNormal,
            ),
          ),
          child: Text(
            token.text,
            style: TextStyle(
              fontSize: fontSize,
              height: _lineHeight,
              color: textColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );

      if (tooltipMessage != null) {
        wordContainer = Tooltip(
          message: tooltipMessage,
          waitDuration: _tooltipWait,
          child: wordContainer,
        );
      }

      final Widget spanChild;
      if (trailingPunct.isNotEmpty) {
        spanChild = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            wordContainer,
            Text(trailingPunct, style: textStyle),
          ],
        );
      } else {
        spanChild = wordContainer;
      }

      spans.add(
        WidgetSpan(alignment: PlaceholderAlignment.middle, child: spanChild),
      );
    }

    return Text.rich(TextSpan(children: spans));
  }
}
