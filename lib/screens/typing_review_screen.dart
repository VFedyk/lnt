import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/review_card.dart';
import '../models/term.dart';
import '../service_locator.dart';
import '../utils/constants.dart';

enum TypingDirection { sourceToTarget, targetToSource }

abstract class _TypingReviewConstants {
  static const double cardElevation = 4.0;
  static const double cardBorderRadius = 16.0;
  static const double promptFontSize = 28.0;
  static const double resultFontSize = 18.0;
  static const double statusDotSize = 12.0;
  static const double completionIconSize = 80.0;
  static const double minCardHeight = 300.0;
  static const double romanizationFontSize = 16.0;
}

class TypingReviewScreen extends StatefulWidget {
  final Language language;
  final TypingDirection direction;

  const TypingReviewScreen({
    super.key,
    required this.language,
    required this.direction,
  });

  @override
  State<TypingReviewScreen> createState() => _TypingReviewScreenState();
}

class _TypingReviewScreenState extends State<TypingReviewScreen> {
  List<_ReviewItem> _dueItems = [];
  int _currentIndex = 0;
  int _reviewedCount = 0;
  bool _isLoading = true;
  bool _isSeeding = false;
  bool? _isCorrect; // null = not yet submitted
  final _answerController = TextEditingController();
  final _answerFocusNode = FocusNode();
  final _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadDueCards();
  }

  @override
  void dispose() {
    _answerController.dispose();
    _answerFocusNode.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TypingReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.language.id != widget.language.id) {
      _loadDueCards();
    }
  }

  Future<void> _loadDueCards() async {
    setState(() {
      _isLoading = true;
      _currentIndex = 0;
      _reviewedCount = 0;
      _isCorrect = null;
    });

    await _ensureCardsSeeded();

    final dueCards = await db.reviewCards
        .getDueCards(widget.language.id!);

    final items = <_ReviewItem>[];
    for (final rc in dueCards) {
      final term = await db.terms.getById(rc.termId);
      if (term == null) continue;

      List<Translation> translations = [];
      if (term.id != null) {
        translations = await db.translations.getByTermId(term.id!);
      }
      if (translations.isEmpty && term.translation.isNotEmpty) {
        translations = [
          Translation(termId: term.id ?? 0, meaning: term.translation),
        ];
      }

      // Only include items that have translations
      if (translations.isNotEmpty) {
        items.add(_ReviewItem(
          reviewCard: rc,
          term: term,
          translations: translations,
        ));
      }
    }

    if (mounted) {
      setState(() {
        _dueItems = items;
        _isLoading = false;
      });
      _answerFocusNode.requestFocus();
    }
  }

  Future<void> _ensureCardsSeeded() async {
    setState(() => _isSeeding = true);

    final allTerms = await db.terms.getAll(languageId: widget.language.id!);
    final eligibleIds = allTerms
        .where((t) =>
            t.id != null &&
            t.status != TermStatus.ignored &&
            t.status != TermStatus.wellKnown)
        .map((t) => t.id!)
        .toList();

    if (eligibleIds.isNotEmpty) {
      await db.reviewCards.ensureCardsExist(eligibleIds);
    }

    if (mounted) {
      setState(() => _isSeeding = false);
    }
  }

  void _submitAnswer() {
    if (_currentIndex >= _dueItems.length || _isCorrect != null) return;

    final item = _dueItems[_currentIndex];
    final answer = _answerController.text.trim().toLowerCase();

    bool correct;
    if (widget.direction == TypingDirection.sourceToTarget) {
      correct = item.translations.any(
        (t) => t.meaning.trim().toLowerCase() == answer,
      );
    } else {
      correct = item.term.lowerText == answer;
    }

    setState(() => _isCorrect = correct);
    _keyboardFocusNode.requestFocus();

    // Rate: correct → easy, incorrect → hard
    final rating = correct ? fsrs.Rating.easy : fsrs.Rating.hard;
    reviewService.reviewTerm(item.reviewCard, rating);
  }

  void _nextCard() {
    setState(() {
      _reviewedCount++;
      _currentIndex++;
      _isCorrect = null;
      _answerController.clear();
    });
    _answerFocusNode.requestFocus();
  }

  String _getPromptText(_ReviewItem item) {
    if (widget.direction == TypingDirection.sourceToTarget) {
      return item.term.text;
    }
    return item.translations.first.meaning;
  }

  String _getCorrectAnswer(_ReviewItem item) {
    if (widget.direction == TypingDirection.sourceToTarget) {
      return item.translations.map((t) => t.meaning).join(', ');
    }
    return item.term.lowerText;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final title = widget.direction == TypingDirection.sourceToTarget
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
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter &&
            _isCorrect != null) {
          _nextCard();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${l10n.typingReview} — $title'),
        ),
        body: body,
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    final hasNoTranslations = _dueItems.isEmpty && !_isLoading;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: _TypingReviewConstants.completionIconSize,
              color: TermStatus.colorFor(TermStatus.known),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              hasNoTranslations ? l10n.noTranslationsToReview : l10n.noCardsDue,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingL),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.done),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletionState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration,
              size: _TypingReviewConstants.completionIconSize,
              color: TermStatus.colorFor(TermStatus.known),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              l10n.reviewComplete,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppConstants.spacingS),
            Text(
              l10n.reviewedCount(_reviewedCount),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppConstants.subtitleColor,
                  ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.done),
              label: Text(l10n.done),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewCard(AppLocalizations l10n) {
    final item = _dueItems[_currentIndex];
    final prompt = _getPromptText(item);

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.reviewProgress(_currentIndex + 1, _dueItems.length),
                  style: TextStyle(color: AppConstants.subtitleColor),
                ),
                Container(
                  width: _TypingReviewConstants.statusDotSize,
                  height: _TypingReviewConstants.statusDotSize,
                  decoration: BoxDecoration(
                    color: TermStatus.colorFor(item.term.status),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          // Card with prompt + input
          Expanded(
            child: Card(
              elevation: _TypingReviewConstants.cardElevation,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    _TypingReviewConstants.cardBorderRadius),
              ),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: _TypingReviewConstants.minCardHeight,
                ),
                padding: const EdgeInsets.all(AppConstants.spacingXL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Prompt text
                    Text(
                      prompt,
                      style: const TextStyle(
                        fontSize: _TypingReviewConstants.promptFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    // TTS button for source language prompt
                    if (widget.direction == TypingDirection.sourceToTarget &&
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

                    // Romanization (source→target only)
                    if (widget.direction == TypingDirection.sourceToTarget &&
                        item.term.romanization.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spacingS),
                      Text(
                        item.term.romanization,
                        style: TextStyle(
                          fontSize: _TypingReviewConstants.romanizationFontSize,
                          color: AppConstants.subtitleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: AppConstants.spacingXL),

                    // Answer input or result
                    if (_isCorrect == null)
                      _buildAnswerInput(l10n)
                    else
                      _buildResult(l10n, item),
                  ],
                ),
              ),
            ),
          ),

          // Next button (after answer submitted)
          if (_isCorrect != null) ...[
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

  Widget _buildAnswerInput(AppLocalizations l10n) {
    return Column(
      children: [
        TextField(
          controller: _answerController,
          focusNode: _answerFocusNode,
          decoration: InputDecoration(
            hintText: l10n.typeYourAnswer,
            border: const OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitAnswer(),
        ),
        const SizedBox(height: AppConstants.spacingM),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitAnswer,
            child: Text(l10n.submit),
          ),
        ),
      ],
    );
  }

  Widget _buildResult(AppLocalizations l10n, _ReviewItem item) {
    final correct = _isCorrect!;
    final correctAnswer = _getCorrectAnswer(item);

    return Column(
      children: [
        // User's answer with color
        Text(
          _answerController.text,
          style: TextStyle(
            fontSize: _TypingReviewConstants.resultFontSize,
            fontWeight: FontWeight.bold,
            color: correct ? Colors.green : Colors.red,
            decoration: correct ? null : TextDecoration.lineThrough,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.spacingM),

        // Result label
        Text(
          correct ? l10n.correct : l10n.incorrect,
          style: TextStyle(
            fontSize: _TypingReviewConstants.resultFontSize,
            fontWeight: FontWeight.bold,
            color: correct ? Colors.green : Colors.red,
          ),
        ),

        // Show correct answer if wrong
        if (!correct) ...[
          const SizedBox(height: AppConstants.spacingS),
          Text(
            l10n.correctAnswerWas(correctAnswer),
            style: const TextStyle(
              fontSize: _TypingReviewConstants.resultFontSize,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        // TTS button for the term (in target→source mode, show after answer)
        if (widget.direction == TypingDirection.targetToSource &&
            widget.language.languageCode.isNotEmpty) ...[
          const SizedBox(height: AppConstants.spacingS),
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: l10n.pronounce,
            onPressed: () => ttsService.speak(
              item.term.lowerText,
              widget.language.languageCode,
            ),
          ),
        ],
      ],
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
