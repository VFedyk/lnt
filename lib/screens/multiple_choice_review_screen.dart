import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/review_card.dart';
import '../models/term.dart';
import '../service_locator.dart';
import '../utils/app_theme.dart';
import '../utils/constants.dart';
import '../widgets/shared/app_empty_state.dart';
import '../widgets/shared/review_progress_indicator.dart';

enum MultipleChoiceDirection { sourceToTarget, targetToSource }

abstract class _Constants {
  static const double cardElevation = 4.0;
  static const double cardBorderRadius = 16.0;
  static const double promptFontSize = 28.0;
  static const double optionFontSize = 16.0;
  static const double romanizationFontSize = 16.0;
  static const double statusDotSize = 12.0;
  static const double completionIconSize = 80.0;
  static const double optionIconSize = 20.0;
}

class MultipleChoiceReviewScreen extends StatefulWidget {
  final Language language;
  final MultipleChoiceDirection direction;

  const MultipleChoiceReviewScreen({
    super.key,
    required this.language,
    required this.direction,
  });

  @override
  State<MultipleChoiceReviewScreen> createState() =>
      _MultipleChoiceReviewScreenState();
}

class _MultipleChoiceReviewScreenState
    extends State<MultipleChoiceReviewScreen> {
  List<_ReviewItem> _dueItems = [];
  List<_TermEntry> _distractorPool = [];
  int _currentIndex = 0;
  int _reviewedCount = 0;
  bool _isLoading = true;
  bool _isSeeding = false;
  bool _hasReviewed = false;

  // Per-card state
  List<String> _options = [];
  int _correctOptionIndex = -1;
  int? _selectedOptionIndex;

  final _random = Random();
  final _focusNode = FocusNode();

  static final _keyToIndex = {
    LogicalKeyboardKey.digit1: 0,
    LogicalKeyboardKey.digit2: 1,
    LogicalKeyboardKey.digit3: 2,
    LogicalKeyboardKey.digit4: 3,
    LogicalKeyboardKey.keyA: 0,
    LogicalKeyboardKey.keyS: 1,
    LogicalKeyboardKey.keyD: 2,
    LogicalKeyboardKey.keyF: 3,
  };

  @override
  void initState() {
    super.initState();
    _loadDueCards();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    if (_hasReviewed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        dataChanges.reviewCards.notify();
        dataChanges.terms.notify();
      });
    }
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (_selectedOptionIndex != null) {
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter) {
        _nextCard();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final index = _keyToIndex[key];
    if (index != null && index < _options.length) {
      _selectOption(index);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadDueCards() async {
    setState(() {
      _isLoading = true;
      _currentIndex = 0;
      _reviewedCount = 0;
      _selectedOptionIndex = null;
    });

    await _ensureCardsSeeded();

    final dueCards = await db.reviewCards.getDueCards(widget.language.id!);
    final termIds = dueCards.map((rc) => rc.termId).toList();
    final termsMap = await db.terms.getByIds(termIds);
    final translationsMap = await db.translations.getByTermIds(termIds);

    // Load all terms for the distractor pool
    final allTerms = await db.terms.getAll(languageId: widget.language.id!);
    final allTermIds =
        allTerms.where((t) => t.id != null).map((t) => t.id!).toList();
    final allTranslationsMap =
        await db.translations.getByTermIds(allTermIds);

    final dueItems = <_ReviewItem>[];
    for (final rc in dueCards) {
      final term = termsMap[rc.termId];
      if (term == null) continue;

      var translations = translationsMap[term.id] ?? [];
      if (translations.isEmpty && term.translation.isNotEmpty) {
        translations = [
          Translation(termId: term.id ?? 0, meaning: term.translation),
        ];
      }

      if (translations.isNotEmpty) {
        dueItems.add(
          _ReviewItem(reviewCard: rc, term: term, translations: translations),
        );
      }
    }

    final pool = <_TermEntry>[];
    for (final term in allTerms) {
      if (term.id == null) continue;
      var translations = allTranslationsMap[term.id] ?? [];
      if (translations.isEmpty && term.translation.isNotEmpty) {
        translations = [
          Translation(termId: term.id!, meaning: term.translation),
        ];
      }
      if (translations.isNotEmpty) {
        pool.add(_TermEntry(term: term, translations: translations));
      }
    }

    if (mounted) {
      setState(() {
        _dueItems = dueItems;
        _distractorPool = pool;
        _isLoading = false;
      });
      if (dueItems.isNotEmpty) {
        _generateOptions();
      }
    }
  }

  Future<void> _ensureCardsSeeded() async {
    setState(() => _isSeeding = true);

    final allTerms = await db.terms.getAll(languageId: widget.language.id!);
    final eligibleIds = allTerms
        .where(
          (t) =>
              t.id != null &&
              t.status != TermStatus.ignored &&
              t.status != TermStatus.wellKnown,
        )
        .map((t) => t.id!)
        .toList();

    if (eligibleIds.isNotEmpty) {
      await db.reviewCards.ensureCardsExist(eligibleIds);
    }

    if (mounted) setState(() => _isSeeding = false);
  }

  void _generateOptions() {
    if (_currentIndex >= _dueItems.length) return;

    final item = _dueItems[_currentIndex];
    final correct = _getCorrectAnswer(item);
    final currentTermId = item.term.id;

    final candidates = _distractorPool
        .where((e) => e.term.id != currentTermId)
        .where((e) {
          final answer =
              widget.direction == MultipleChoiceDirection.sourceToTarget
                  ? e.translations.first.meaning
                  : e.term.text;
          return answer.trim().toLowerCase() != correct.trim().toLowerCase();
        })
        .toList()
      ..shuffle(_random);

    final distractors = candidates.take(3).map((e) {
      return widget.direction == MultipleChoiceDirection.sourceToTarget
          ? e.translations.first.meaning
          : e.term.text;
    }).toList();

    final options = [correct, ...distractors]..shuffle(_random);
    final correctIdx = options.indexOf(correct);

    setState(() {
      _options = options;
      _correctOptionIndex = correctIdx;
      _selectedOptionIndex = null;
    });
  }

  String _getPromptText(_ReviewItem item) {
    if (widget.direction == MultipleChoiceDirection.sourceToTarget) {
      return item.term.text;
    }
    return item.translations.first.meaning;
  }

  String _getCorrectAnswer(_ReviewItem item) {
    if (widget.direction == MultipleChoiceDirection.sourceToTarget) {
      return item.translations.first.meaning;
    }
    return item.term.text;
  }

  void _selectOption(int index) {
    if (_selectedOptionIndex != null) return;

    final isCorrect = index == _correctOptionIndex;
    final rating = isCorrect ? fsrs.Rating.easy : fsrs.Rating.hard;
    _hasReviewed = true;
    reviewService.reviewTerm(
      _dueItems[_currentIndex].reviewCard,
      rating,
      notify: false,
    );

    setState(() => _selectedOptionIndex = index);
  }

  void _nextCard() {
    setState(() {
      _reviewedCount++;
      _currentIndex++;
      _selectedOptionIndex = null;
    });
    if (_currentIndex < _dueItems.length) {
      _generateOptions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final dirLabel =
        widget.direction == MultipleChoiceDirection.sourceToTarget
            ? l10n.typingSourceToTarget
            : l10n.typingTargetToSource;

    Widget body;
    if (_isLoading || _isSeeding) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_dueItems.isEmpty) {
      body = _buildEmptyState(l10n);
    } else if (_currentIndex >= _dueItems.length) {
      body = _buildCompletionState(l10n);
    } else {
      body = _buildReviewCard(l10n);
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${l10n.multipleChoiceReview} — $dirLabel'),
        ),
        body: body,
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return AppEmptyState(
      icon: Icons.check_circle_outline,
      iconSize: _Constants.completionIconSize,
      iconColor: TermStatus.colorFor(TermStatus.known),
      title: l10n.noCardsDue,
      action: ElevatedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
        label: Text(l10n.done),
      ),
    );
  }

  Widget _buildCompletionState(AppLocalizations l10n) {
    return ReviewCompletionState(
      reviewedCount: _reviewedCount,
      onDone: () => Navigator.pop(context),
      completionMessage: l10n.reviewComplete,
      reviewedCountMessage: l10n.reviewedCount(_reviewedCount),
      doneLabel: l10n.done,
    );
  }

  Widget _buildReviewCard(AppLocalizations l10n) {
    final item = _dueItems[_currentIndex];
    final prompt = _getPromptText(item);
    final answered = _selectedOptionIndex != null;

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        children: [
          ReviewProgressIndicator(
            currentIndex: _currentIndex,
            totalCount: _dueItems.length,
            termStatus: item.term.status,
            statusDotSize: _Constants.statusDotSize,
          ),
          Expanded(
            child: Card(
              elevation: _Constants.cardElevation,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(_Constants.cardBorderRadius),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingXL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppConstants.spacingL),
                    Text(
                      prompt,
                      style: const TextStyle(
                        fontSize: _Constants.promptFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.direction ==
                            MultipleChoiceDirection.sourceToTarget &&
                        widget.language.languageCode.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.volume_up),
                        tooltip: l10n.pronounce,
                        onPressed: () => ttsService.speak(
                          item.term.lowerText,
                          widget.language.languageCode,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (widget.direction ==
                            MultipleChoiceDirection.sourceToTarget &&
                        item.term.romanization.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spacingS),
                      Text(
                        item.term.romanization,
                        style: TextStyle(
                          fontSize: _Constants.romanizationFontSize,
                          color: AppConstants.subtitleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppConstants.spacingXL),
                    _buildOptionsGrid(answered),
                    const SizedBox(height: AppConstants.spacingL),
                  ],
                ),
              ),
            ),
          ),
          if (answered) ...[
            const SizedBox(height: AppConstants.spacingM),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextCard,
                child: Text(l10n.done),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const _keyLabels = ['1', '2', '3', '4'];

  Widget _buildOptionsGrid(bool answered) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildOption(0, answered)),
            const SizedBox(width: AppConstants.spacingS),
            Expanded(child: _buildOption(1, answered)),
          ],
        ),
        const SizedBox(height: AppConstants.spacingS),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildOption(2, answered)),
            const SizedBox(width: AppConstants.spacingS),
            Expanded(child: _buildOption(3, answered)),
          ],
        ),
      ],
    );
  }

  Widget _buildOption(int index, bool answered) {
    if (index >= _options.length) return const SizedBox.shrink();

    final isCorrect = index == _correctOptionIndex;
    final isSelected = _selectedOptionIndex == index;

    Color? bgColor;
    Color borderColor = Theme.of(context).colorScheme.outline;
    Color? textColor;
    IconData? statusIcon;

    if (answered) {
      if (isCorrect) {
        bgColor = context.appColors.success.withValues(alpha: 0.15);
        borderColor = context.appColors.success;
        textColor = context.appColors.success;
        statusIcon = Icons.check_circle;
      } else if (isSelected) {
        bgColor = Theme.of(context).colorScheme.error.withValues(alpha: 0.15);
        borderColor = Theme.of(context).colorScheme.error;
        textColor = Theme.of(context).colorScheme.error;
        statusIcon = Icons.cancel;
      }
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: answered ? () {} : () => _selectOption(index),
        style: OutlinedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor:
              textColor ?? Theme.of(context).colorScheme.onSurface,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.spacingM,
            horizontal: AppConstants.spacingS,
          ),
          alignment: Alignment.centerLeft,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              _keyLabels[index],
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: (textColor ?? Theme.of(context).colorScheme.onSurface)
                    .withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            if (statusIcon != null) ...[
              Icon(statusIcon, color: textColor, size: _Constants.optionIconSize),
              const SizedBox(width: 4),
            ],
            Expanded(
              child: Text(
                _options[index],
                style: TextStyle(
                  fontSize: _Constants.optionFontSize,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewItem {
  final ReviewCardRecord reviewCard;
  final Term term;
  final List<Translation> translations;

  const _ReviewItem({
    required this.reviewCard,
    required this.term,
    required this.translations,
  });
}

class _TermEntry {
  final Term term;
  final List<Translation> translations;

  const _TermEntry({required this.term, required this.translations});
}
