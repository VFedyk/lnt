import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../../l10n/generated/app_localizations.dart';
import '../../domain/entities/language.dart';
import '../../domain/entities/review_card.dart';
import '../../domain/entities/term.dart';
import '../../service_locator.dart';
import '../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../widgets/shared/app_empty_state.dart';
import '../widgets/shared/review_options_grid.dart';
import '../widgets/shared/review_progress_indicator.dart';

enum ClozeMode { easy, advanced }

abstract class _Constants {
  static const double cardElevation = 4.0;
  static const double cardBorderRadius = 16.0;
  static const double sentenceFontSize = 22.0;
  static const double hintFontSize = 16.0;
  static const double resultFontSize = 18.0;
  static const double statusDotSize = 12.0;
  static const double completionIconSize = 80.0;
}

class ClozeReviewScreen extends StatefulWidget {
  final Language language;
  final ClozeMode mode;

  const ClozeReviewScreen({
    super.key,
    required this.language,
    required this.mode,
  });

  @override
  State<ClozeReviewScreen> createState() => _ClozeReviewScreenState();
}

class _ClozeReviewScreenState extends State<ClozeReviewScreen> {
  List<_ReviewItem> _dueItems = [];
  List<String> _distractorPool = [];
  int _currentIndex = 0;
  int _reviewedCount = 0;
  bool _isLoading = true;
  bool _isSeeding = false;
  bool _hasReviewed = false;

  // Easy mode state
  List<String> _options = [];
  int _correctOptionIndex = -1;
  int? _selectedOptionIndex;

  // Advanced mode state
  bool? _isCorrect;
  final _answerController = TextEditingController();
  final _answerFocusNode = FocusNode();
  final _keyboardFocusNode = FocusNode();

  final _random = Random();

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
    if (_hasReviewed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        dataChanges.reviewCards.notify();
        dataChanges.terms.notify();
      });
    }
    _answerController.dispose();
    _answerFocusNode.dispose();
    _keyboardFocusNode.dispose();
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

    if (widget.mode == ClozeMode.easy) {
      if (_selectedOptionIndex != null) {
        if (key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.enter) {
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
    } else {
      if (_isCorrect != null &&
          (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space)) {
        _nextCard();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _loadDueCards() async {
    setState(() {
      _isLoading = true;
      _currentIndex = 0;
      _reviewedCount = 0;
      _selectedOptionIndex = null;
      _isCorrect = null;
    });

    await _ensureCardsSeeded();

    final dueCards = await db.reviewCards.getDueCards(widget.language.id!);
    final termIds = dueCards.map((rc) => rc.termId).toList();
    final termsMap = await db.terms.getByIds(termIds);
    final translationsMap = await db.translations.getByTermIds(termIds);
    final minedSentencesMap = await db.termSentences.getByTermIds(termIds);

    final dueItems = <_ReviewItem>[];
    for (final rc in dueCards) {
      final term = termsMap[rc.termId];
      if (term == null) continue;

      // Collect all available sentences: mined sentences + term.sentence fallback
      final sentences = [
        ...?minedSentencesMap[term.id],
        if (term.sentence.trim().isNotEmpty) term.sentence.trim(),
      ];
      if (sentences.isEmpty) continue;

      var translations = translationsMap[term.id] ?? [];
      if (translations.isEmpty && term.translation.isNotEmpty) {
        translations = [
          Translation(termId: term.id ?? '', meaning: term.translation),
        ];
      }

      // Pick a random sentence for this review session
      final sentence = sentences[_random.nextInt(sentences.length)];
      dueItems.add(
        _ReviewItem(
          reviewCard: rc,
          term: term,
          translations: translations,
          sentence: sentence,
        ),
      );
    }

    // For easy mode: build distractor pool from all terms
    List<String> pool = [];
    if (widget.mode == ClozeMode.easy) {
      final allTerms = await db.terms.getAll(languageId: widget.language.id!);
      pool = allTerms.where((t) => t.id != null).map((t) => t.text).toList();
    }

    if (mounted) {
      setState(() {
        _dueItems = dueItems;
        _distractorPool = pool;
        _isLoading = false;
      });
      if (dueItems.isNotEmpty) {
        if (widget.mode == ClozeMode.easy) {
          _generateOptions();
        } else {
          _answerFocusNode.requestFocus();
        }
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
    final correct = item.term.text;
    final correctLower = item.term.lowerText;

    final candidates = _distractorPool
        .where((t) => t.trim().toLowerCase() != correctLower)
        .toList()
      ..shuffle(_random);

    final distractors = candidates.take(3).toList();
    final options = [correct, ...distractors]..shuffle(_random);

    setState(() {
      _options = options;
      _correctOptionIndex = options.indexOf(correct);
      _selectedOptionIndex = null;
    });
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

  void _submitAnswer() {
    if (_currentIndex >= _dueItems.length || _isCorrect != null) return;

    final item = _dueItems[_currentIndex];
    final answer = _answerController.text.trim().toLowerCase();
    final isCorrect = answer == item.term.lowerText;
    final rating = isCorrect ? fsrs.Rating.easy : fsrs.Rating.hard;
    _hasReviewed = true;
    reviewService.reviewTerm(item.reviewCard, rating, notify: false);

    setState(() => _isCorrect = isCorrect);
    _keyboardFocusNode.requestFocus();
  }

  void _nextCard() {
    setState(() {
      _reviewedCount++;
      _currentIndex++;
      _selectedOptionIndex = null;
      _isCorrect = null;
      _answerController.clear();
    });
    if (_currentIndex < _dueItems.length) {
      if (widget.mode == ClozeMode.easy) {
        _generateOptions();
      } else {
        _answerFocusNode.requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final modeLabel = widget.mode == ClozeMode.easy
        ? l10n.clozeEasyMode
        : l10n.clozeAdvancedMode;

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
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${l10n.clozeReview} — $modeLabel'),
        ),
        body: body,
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return AppEmptyState(
      icon: Icons.text_snippet_outlined,
      iconSize: _Constants.completionIconSize,
      title: l10n.noSentencesToReview,
      subtitle: l10n.noSentencesToReviewHint,
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
    final answered = widget.mode == ClozeMode.easy
        ? _selectedOptionIndex != null
        : _isCorrect != null;

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
            child: SizedBox(
              width: double.infinity,
              child: Card(
                elevation: _Constants.cardElevation,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(_Constants.cardBorderRadius),
                ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppConstants.spacingXL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppConstants.spacingL),
                    _buildClozeSentence(item),
                    const SizedBox(height: AppConstants.spacingM),
                    if (item.translations.isNotEmpty)
                      Text(
                        item.translations.map((t) => t.meaning).join(', '),
                        style: TextStyle(
                          fontSize: _Constants.hintFontSize,
                          color: AppConstants.subtitleColor,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: AppConstants.spacingXL),
                    if (widget.mode == ClozeMode.easy)
                      ReviewOptionsGrid(
                        options: _options,
                        correctIndex: _correctOptionIndex,
                        selectedIndex: _selectedOptionIndex,
                        onSelect: _selectOption,
                      )
                    else
                      _buildAdvancedInput(l10n, item, answered),
                    const SizedBox(height: AppConstants.spacingL),
                  ],
                ),
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

  Widget _buildClozeSentence(_ReviewItem item) {
    final sentence = item.sentence;
    final lowerSentence = sentence.toLowerCase();
    final lowerTerm = item.term.lowerText;
    final idx = lowerSentence.indexOf(lowerTerm);

    final blankLength = item.term.text.length.clamp(4, 12);
    final blank = '_' * blankLength;

    final blankStyle = TextStyle(
      fontSize: _Constants.sentenceFontSize,
      fontWeight: FontWeight.bold,
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      letterSpacing: 2,
    );
    final sentenceStyle = TextStyle(fontSize: _Constants.sentenceFontSize);

    final List<InlineSpan> spans;
    if (idx == -1) {
      spans = [
        TextSpan(text: sentence, style: sentenceStyle),
        const TextSpan(text: ' '),
        TextSpan(text: blank, style: blankStyle),
      ];
    } else {
      final before = sentence.substring(0, idx);
      final after = sentence.substring(idx + item.term.text.length);
      spans = [
        TextSpan(text: before, style: sentenceStyle),
        TextSpan(text: blank, style: blankStyle),
        TextSpan(text: after, style: sentenceStyle),
      ];
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildAdvancedInput(
    AppLocalizations l10n,
    _ReviewItem item,
    bool answered,
  ) {
    if (!answered) {
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

    final correct = _isCorrect!;
    return Column(
      children: [
        Text(
          _answerController.text,
          style: TextStyle(
            fontSize: _Constants.resultFontSize,
            fontWeight: FontWeight.bold,
            color: correct
                ? context.appColors.success
                : Theme.of(context).colorScheme.error,
            decoration: correct ? null : TextDecoration.lineThrough,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.spacingM),
        Text(
          correct ? l10n.correct : l10n.incorrect,
          style: TextStyle(
            fontSize: _Constants.resultFontSize,
            fontWeight: FontWeight.bold,
            color: correct
                ? context.appColors.success
                : Theme.of(context).colorScheme.error,
          ),
        ),
        if (!correct) ...[
          const SizedBox(height: AppConstants.spacingS),
          Text(
            l10n.correctAnswerWas(item.term.text),
            style: const TextStyle(fontSize: _Constants.resultFontSize),
            textAlign: TextAlign.center,
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
  final String sentence;

  const _ReviewItem({
    required this.reviewCard,
    required this.term,
    required this.translations,
    required this.sentence,
  });
}
