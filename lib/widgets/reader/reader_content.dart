import 'package:flutter/material.dart';

import '../../controllers/reader_controller.dart';
import '../../models/term.dart';
import '../../models/word_token.dart';
import '../../utils/constants.dart';
import '../paragraph_rich_text.dart';
import '../status_legend.dart';

class ReaderContent extends StatelessWidget {
  final bool showLegend;
  final Map<int, int> termCounts;
  final bool rightToLeft;
  final ScrollController scrollController;
  final List<List<WordToken>> paragraphs;
  final double fontSize;
  final Set<int> selectedWordIndices;
  final Map<String, ForeignTermInfo> otherLanguageTerms;
  final Map<int, List<Translation>> translationsMap;
  final Map<int, Translation> translationsById;
  final Map<int, Term> termsById;
  final void Function(String word, int position, int globalIndex) onWordTap;
  final void Function(int globalIndex) onWordLongPress;
  final void Function(String word, int position, int globalIndex, Offset globalPosition)? onWordRightClick;
  final void Function(int globalIndex)? onWordDragStart;
  final void Function(int globalIndex)? onWordDragEnter;

  const ReaderContent({
    super.key,
    required this.showLegend,
    required this.termCounts,
    required this.rightToLeft,
    required this.scrollController,
    required this.paragraphs,
    required this.fontSize,
    required this.selectedWordIndices,
    required this.otherLanguageTerms,
    required this.translationsMap,
    required this.translationsById,
    required this.termsById,
    required this.onWordTap,
    required this.onWordLongPress,
    this.onWordRightClick,
    this.onWordDragStart,
    this.onWordDragEnter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showLegend) StatusLegend(termCounts: termCounts),
        Expanded(
          child: Directionality(
            textDirection: rightToLeft ? TextDirection.rtl : TextDirection.ltr,
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(AppConstants.spacingL),
              itemCount: paragraphs.length,
              itemBuilder: (context, index) {
                final para = paragraphs[index];
                if (para.length == 1 &&
                    !para[0].isWord &&
                    para[0].text.trim().isEmpty) {
                  return SizedBox(
                    height: para[0].text.contains('\n\n')
                        ? AppConstants.spacingL
                        : AppConstants.spacingS,
                  );
                }
                return ParagraphRichText(
                  tokens: para,
                  fontSize: fontSize,
                  selectedWordIndices: selectedWordIndices,
                  otherLanguageTerms: otherLanguageTerms,
                  translationsMap: translationsMap,
                  translationsById: translationsById,
                  termsById: termsById,
                  onWordTap: onWordTap,
                  onWordLongPress: onWordLongPress,
                  onWordRightClick: onWordRightClick,
                  onWordDragStart: onWordDragStart,
                  onWordDragEnter: onWordDragEnter,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
