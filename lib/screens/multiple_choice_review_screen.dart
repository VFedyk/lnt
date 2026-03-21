import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../controllers/flashcard_review_controller.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/term.dart';
import '../service_locator.dart';
import '../utils/constants.dart';
import '../widgets/shared/app_empty_state.dart';
import '../widgets/shared/review_options_grid.dart';
import '../widgets/shared/review_progress_indicator.dart';

enum MultipleChoiceDirection { sourceToTarget, targetToSource }

abstract class _Constants {
  static const double promptFontSize = 28.0;
  static const double romanizationFontSize = 16.0;
  static const double statusDotSize = 12.0;
  static const double completionIconSize = 80.0;
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
  List<ReviewItem> _dueItems = [];
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

    final dueItems = <ReviewItem>[];
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
          ReviewItem(reviewCard: rc, term: term, translations: translations),
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
    await reviewService.seedCardsForLanguage(widget.language.id!);
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

  String _getPromptText(ReviewItem item) {
    if (widget.direction == MultipleChoiceDirection.sourceToTarget) {
      return item.term.text;
    }
    return item.translations.first.meaning;
  }

  String _getCorrectAnswer(ReviewItem item) {
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingM),
        child: Column(
          children: [
            ReviewProgressIndicator(
              currentIndex: _currentIndex,
              totalCount: _dueItems.length,
              termStatus: item.term.status,
              statusDotSize: _Constants.statusDotSize,
            ),

            // Center the entire question+answers unit as a group so the term
            // and options stay visually connected on large screens.
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppConstants.spacingL,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingXL),
                      ReviewOptionsGrid(
                        options: _options,
                        correctIndex: _correctOptionIndex,
                        selectedIndex: _selectedOptionIndex,
                        onSelect: _selectOption,
                      ),
                      const SizedBox(height: AppConstants.spacingM),
                      // Always occupies space to prevent layout shift.
                      Opacity(
                        opacity: answered ? 1.0 : 0.0,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: answered ? _nextCard : null,
                            child: Text(l10n.done),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _TermEntry {
  final Term term;
  final List<Translation> translations;

  const _TermEntry({required this.term, required this.translations});
}
