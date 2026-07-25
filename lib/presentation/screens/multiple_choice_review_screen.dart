import '../theme/term_status_ui.dart';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../controllers/flashcard_review_controller.dart';
import '../controllers/review_session_outcome.dart';
import '../models/review_session_spec.dart';
import '../widgets/shared/review_session_app_bar.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/term.dart';
import '../../service_locator.dart';
import '../../utils/constants.dart';
import '../../utils/helpers.dart';
import '../widgets/shared/app_empty_state.dart';
import '../widgets/shared/reread_suggestion_card.dart';
import '../widgets/shared/review_options_grid.dart';
import '../widgets/shared/review_progress_indicator.dart';
import '../../domain/value_objects/term_status.dart';

enum MultipleChoiceDirection { sourceToTarget, targetToSource, romanization }

abstract class _Constants {
  static const double promptFontSize = 28.0;
  static const double romanizationFontSize = 16.0;
  static const double statusDotSize = 12.0;
  static const double completionIconSize = 80.0;
}

class MultipleChoiceReviewScreen extends StatefulWidget {
  final ReviewSessionSpec spec;
  final MultipleChoiceDirection direction;

  const MultipleChoiceReviewScreen({
    super.key,
    required this.spec,
    required this.direction,
  });

  Language get language => spec.language;

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
  final _outcome = ReviewSessionOutcome();

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
    // A practice pass writes nothing, so there is nothing to invalidate.
    if (_hasReviewed && widget.spec.graded) {
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

    // When review is complete or empty, Space/Enter/Esc dismisses the screen
    if (_dueItems.isEmpty || _currentIndex >= _dueItems.length) {
      if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.escape) {
        Navigator.pop(context);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

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

    final dueCards = await db.reviewCards
        .getDueCards(widget.language.id!, scope: widget.spec.scope);
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
          Translation(termId: term.id ?? '', meaning: term.translation),
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

    final filteredDueItems =
        widget.direction == MultipleChoiceDirection.romanization
            ? dueItems
                .where((item) => item.term.romanization.trim().isNotEmpty)
                .toList()
            : dueItems;
    final filteredPool =
        widget.direction == MultipleChoiceDirection.romanization
            ? pool
                .where((e) => e.term.romanization.trim().isNotEmpty)
                .toList()
            : pool;

    if (mounted) {
      setState(() {
        _dueItems = filteredDueItems;
        _distractorPool = filteredPool;
        _isLoading = false;
      });
      if (filteredDueItems.isNotEmpty) {
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
                  ? e.translations.map((t) => t.meaning).join(', ')
                  : widget.direction == MultipleChoiceDirection.targetToSource
                      ? e.term.text
                      : e.term.romanization;
          final trimmed = answer.trim();
          return trimmed.isNotEmpty &&
              trimmed.toLowerCase() != correct.trim().toLowerCase();
        })
        .toList()
      ..shuffle(_random);

    final distractors = candidates.take(3).map((e) {
      return widget.direction == MultipleChoiceDirection.sourceToTarget
          ? e.translations.map((t) => t.meaning).join(', ')
          : widget.direction == MultipleChoiceDirection.targetToSource
              ? e.term.text
              : e.term.romanization;
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
    if (widget.direction == MultipleChoiceDirection.targetToSource) {
      return item.translations.map((t) => t.meaning).join(', ');
    }
    return item.term.text; // sourceToTarget and romanization both show characters
  }

  String _getCorrectAnswer(ReviewItem item) {
    if (widget.direction == MultipleChoiceDirection.sourceToTarget) {
      return item.translations.map((t) => t.meaning).join(', ');
    }
    if (widget.direction == MultipleChoiceDirection.romanization) {
      return item.term.romanization;
    }
    return item.term.text;
  }

  /// Applies [rating] to [item] — persisting it only in a graded session.
  void _grade(ReviewItem item, fsrs.Rating rating) {
    _hasReviewed = true;
    if (widget.spec.graded) {
      reviewService.reviewTerm(item.reviewCard, rating, notify: false);
    } else {
      reviewService.practiceTerm(item.reviewCard, rating);
    }
    final termId = item.term.id;
    if (termId != null) _outcome.record(termId, rating);
  }

  void _selectOption(int index) {
    if (_selectedOptionIndex != null) return;

    final isCorrect = index == _correctOptionIndex;
    _grade(_dueItems[_currentIndex],
        isCorrect ? fsrs.Rating.good : fsrs.Rating.again);

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

    final dirLabel = switch (widget.direction) {
      MultipleChoiceDirection.sourceToTarget => l10n.typingSourceToTarget,
      MultipleChoiceDirection.targetToSource => l10n.typingTargetToSource,
      MultipleChoiceDirection.romanization => l10n.multipleChoiceRomanization,
    };

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
        appBar: reviewSessionAppBar(
          context, widget.spec, '${l10n.multipleChoiceReview} — $dirLabel'),
        body: body,
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return AppEmptyState(
      icon: Icons.check_circle_outline,
      iconSize: _Constants.completionIconSize,
      iconColor: TermStatusUI.colorFor(TermStatus.known),
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
      footer: RereadSuggestionCard(
        language: widget.spec.language,
        failedTermIds: _outcome.failedTermIds,
        excludeTextId: widget.spec.sourceTextId,
      ),
    );
  }

  Widget _buildReviewCard(AppLocalizations l10n) {
    final item = _dueItems[_currentIndex];
    final prompt = _getPromptText(item);
    final answered = _selectedOptionIndex != null;
    final statusColor = TermStatusUI.colorFor(item.term.status);
    final hasAudio =
        widget.direction != MultipleChoiceDirection.targetToSource &&
            widget.language.languageCode.isNotEmpty;

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
              showStatusDot: false,
            ),

            // Word centered in the space between progress bar and options.
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Status dot + word + audio on one line.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: _Constants.statusDotSize,
                            height: _Constants.statusDotSize,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AppConstants.spacingS),
                          Flexible(
                            child: Text(
                              prompt,
                              style: const TextStyle(
                                fontSize: _Constants.promptFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (hasAudio) ...[
                            const SizedBox(width: AppConstants.spacingXS),
                            IconButton(
                              icon: const Icon(Icons.volume_up),
                              tooltip: l10n.pronounce,
                              onPressed: () => ttsService.speak(
                                item.term.lowerText,
                                widget.language.languageCode,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ],
                      ),
                      if (widget.direction ==
                              MultipleChoiceDirection.sourceToTarget &&
                          item.term.romanization.isNotEmpty) ...[
                        const SizedBox(height: AppConstants.spacingS),
                        Text(
                          item.term.romanization,
                          style: TextStyle(
                            fontSize: _Constants.romanizationFontSize,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (widget.direction ==
                          MultipleChoiceDirection.romanization) ...[
                        const SizedBox(height: AppConstants.spacingS),
                        Text(
                          item.translations.map((t) => t.meaning).join(', '),
                          style: TextStyle(
                            fontSize: _Constants.romanizationFontSize,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Options at the vertical midpoint.
            ReviewOptionsGrid(
              options: _options,
              correctIndex: _correctOptionIndex,
              selectedIndex: _selectedOptionIndex,
              onSelect: _selectOption,
            ),

            // Done button centered in the space between options and bottom edge.
            Expanded(
              child: Center(
                child: Opacity(
                  opacity: answered ? 1.0 : 0.0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: 200,
                          maxWidth: PlatformHelper.isDesktop ? 320 : double.infinity,
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 52),
                          ),
                          onPressed: answered ? _nextCard : null,
                          child: Text(l10n.done),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spacingXS),
                      Text(
                        l10n.keyboardHintContinue,
                        style: TextStyle(
                          fontSize: AppConstants.fontSizeCaption,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
