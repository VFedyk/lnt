import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../l10n/generated/app_localizations.dart';
import '../models/language.dart';
import '../models/review_card.dart';
import '../models/term.dart';
import '../services/database_service.dart';
import '../services/review_service.dart';
import '../utils/constants.dart';

abstract class _FlashcardReviewConstants {
  static const double cardElevation = 4.0;
  static const double cardBorderRadius = 16.0;
  static const double termFontSize = 28.0;
  static const double romanizationFontSize = 16.0;
  static const double sentenceFontSize = 14.0;
  static const double translationFontSize = 18.0;
  static const double statusDotSize = 12.0;
  static const double completionIconSize = 80.0;
  static const double buttonSpacing = 8.0;
  static const double intervalFontSize = 11.0;
  static const double minCardHeight = 300.0;
}

class FlashcardReviewScreen extends StatefulWidget {
  final Language language;

  const FlashcardReviewScreen({super.key, required this.language});

  @override
  State<FlashcardReviewScreen> createState() => _FlashcardReviewScreenState();
}

class _FlashcardReviewScreenState extends State<FlashcardReviewScreen> {
  List<_ReviewItem> _dueItems = [];
  int _currentIndex = 0;
  int _reviewedCount = 0;
  bool _isLoading = true;
  bool _isAnswerRevealed = false;
  bool _isSeeding = false;
  Map<fsrs.Rating, Duration>? _nextIntervals;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadDueCards();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // When answer is not yet revealed, any rating key reveals it first
    if (!_isAnswerRevealed) {
      if (key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.digit1 ||
          key == LogicalKeyboardKey.digit2 ||
          key == LogicalKeyboardKey.digit3 ||
          key == LogicalKeyboardKey.digit4 ||
          key == LogicalKeyboardKey.keyA ||
          key == LogicalKeyboardKey.keyS ||
          key == LogicalKeyboardKey.keyD ||
          key == LogicalKeyboardKey.keyF) {
        _revealAnswer();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // Answer is revealed — rate the card
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.keyA) {
      _rateCard(fsrs.Rating.again);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.keyS) {
      _rateCard(fsrs.Rating.hard);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.keyD) {
      _rateCard(fsrs.Rating.good);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.keyF) {
      _rateCard(fsrs.Rating.easy);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void didUpdateWidget(FlashcardReviewScreen oldWidget) {
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
      _isAnswerRevealed = false;
      _nextIntervals = null;
    });

    // Ensure all eligible terms have review cards (lazy seeding)
    await _ensureCardsSeeded();

    final dueCards = await DatabaseService.instance.reviewCards
        .getDueCards(widget.language.id!);

    // Batch load terms and translations
    final items = <_ReviewItem>[];
    for (final rc in dueCards) {
      final term = await DatabaseService.instance.getTerm(rc.termId);
      if (term == null) continue;

      List<Translation> translations = [];
      if (term.id != null) {
        translations = await DatabaseService.instance.translations
            .getByTermId(term.id!);
      }
      // Fallback to legacy translation field
      if (translations.isEmpty && term.translation.isNotEmpty) {
        translations = [
          Translation(termId: term.id ?? 0, meaning: term.translation),
        ];
      }

      items.add(_ReviewItem(reviewCard: rc, term: term, translations: translations));
    }

    if (mounted) {
      setState(() {
        _dueItems = items;
        _isLoading = false;
      });
    }
  }

  Future<void> _ensureCardsSeeded() async {
    setState(() => _isSeeding = true);

    final allTerms = await DatabaseService.instance.getTerms(
      languageId: widget.language.id!,
    );
    final eligibleIds = allTerms
        .where((t) =>
            t.id != null &&
            t.status != TermStatus.ignored &&
            t.status != TermStatus.wellKnown)
        .map((t) => t.id!)
        .toList();

    if (eligibleIds.isNotEmpty) {
      await DatabaseService.instance.reviewCards.ensureCardsExist(eligibleIds);
    }

    if (mounted) {
      setState(() => _isSeeding = false);
    }
  }

  Future<void> _rateCard(fsrs.Rating rating) async {
    if (_currentIndex >= _dueItems.length) return;

    final item = _dueItems[_currentIndex];
    await ReviewService.instance.reviewTerm(item.reviewCard, rating);

    setState(() {
      _reviewedCount++;
      _currentIndex++;
      _isAnswerRevealed = false;
      _nextIntervals = null;
    });
  }

  void _revealAnswer() {
    if (_currentIndex >= _dueItems.length) return;

    final item = _dueItems[_currentIndex];
    final intervals =
        ReviewService.instance.getNextIntervals(item.reviewCard.card);

    setState(() {
      _isAnswerRevealed = true;
      _nextIntervals = intervals;
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

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
          title: Text(l10n.flashcardReview),
        ),
        body: body,
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: _FlashcardReviewConstants.completionIconSize,
              color: TermStatus.colorFor(TermStatus.known),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              l10n.noCardsDue,
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
              size: _FlashcardReviewConstants.completionIconSize,
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
    final term = item.term;

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
                  width: _FlashcardReviewConstants.statusDotSize,
                  height: _FlashcardReviewConstants.statusDotSize,
                  decoration: BoxDecoration(
                    color: TermStatus.colorFor(term.status),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          // Flashcard
          Expanded(
            child: Card(
              elevation: _FlashcardReviewConstants.cardElevation,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    _FlashcardReviewConstants.cardBorderRadius),
              ),
              child: InkWell(
                onTap: _isAnswerRevealed ? null : _revealAnswer,
                borderRadius: BorderRadius.circular(
                    _FlashcardReviewConstants.cardBorderRadius),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: _FlashcardReviewConstants.minCardHeight,
                  ),
                  padding: const EdgeInsets.all(AppConstants.spacingXL),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Term text
                      Text(
                        term.text,
                        style: const TextStyle(
                          fontSize: _FlashcardReviewConstants.termFontSize,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      // Romanization
                      if (term.romanization.isNotEmpty) ...[
                        const SizedBox(height: AppConstants.spacingS),
                        Text(
                          term.romanization,
                          style: TextStyle(
                            fontSize:
                                _FlashcardReviewConstants.romanizationFontSize,
                            color: AppConstants.subtitleColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      // Sentence
                      if (term.sentence.isNotEmpty) ...[
                        const SizedBox(height: AppConstants.spacingM),
                        Text(
                          term.sentence,
                          style: TextStyle(
                            fontSize: _FlashcardReviewConstants.sentenceFontSize,
                            color: AppConstants.subtitleColor,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      // Divider + translations (revealed)
                      if (_isAnswerRevealed) ...[
                        const SizedBox(height: AppConstants.spacingL),
                        const Divider(),
                        const SizedBox(height: AppConstants.spacingM),
                        ...item.translations.map((t) => Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppConstants.spacingXS),
                              child: Text(
                                t.partOfSpeech != null && t.partOfSpeech!.isNotEmpty
                                    ? '${t.meaning} (${t.partOfSpeech})'
                                    : t.meaning,
                                style: const TextStyle(
                                  fontSize:
                                      _FlashcardReviewConstants.translationFontSize,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )),
                      ],

                      // "Tap to reveal" hint
                      if (!_isAnswerRevealed) ...[
                        const SizedBox(height: AppConstants.spacingXL),
                        Text(
                          l10n.showAnswer,
                          style: TextStyle(
                            color: AppConstants.subtitleColor,
                            fontSize: AppConstants.fontSizeCaption,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Rating buttons
          if (_isAnswerRevealed) ...[
            const SizedBox(height: AppConstants.spacingM),
            _buildRatingButtons(l10n),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingButtons(AppLocalizations l10n) {
    final intervals = _nextIntervals;

    return Row(
      children: [
        _buildRatingButton(
          label: l10n.rateAgain,
          rating: fsrs.Rating.again,
          color: Colors.red,
          interval: intervals?[fsrs.Rating.again],
        ),
        const SizedBox(width: _FlashcardReviewConstants.buttonSpacing),
        _buildRatingButton(
          label: l10n.rateHard,
          rating: fsrs.Rating.hard,
          color: Colors.orange,
          interval: intervals?[fsrs.Rating.hard],
        ),
        const SizedBox(width: _FlashcardReviewConstants.buttonSpacing),
        _buildRatingButton(
          label: l10n.rateGood,
          rating: fsrs.Rating.good,
          color: Colors.green,
          interval: intervals?[fsrs.Rating.good],
        ),
        const SizedBox(width: _FlashcardReviewConstants.buttonSpacing),
        _buildRatingButton(
          label: l10n.rateEasy,
          rating: fsrs.Rating.easy,
          color: Colors.blue,
          interval: intervals?[fsrs.Rating.easy],
        ),
      ],
    );
  }

  Widget _buildRatingButton({
    required String label,
    required fsrs.Rating rating,
    required Color color,
    Duration? interval,
  }) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _rateCard(rating),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingM),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (interval != null)
              Text(
                _formatDuration(interval),
                style: TextStyle(
                  fontSize: _FlashcardReviewConstants.intervalFontSize,
                  color: color.withValues(alpha: 0.7),
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
