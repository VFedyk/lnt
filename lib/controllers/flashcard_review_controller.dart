import 'package:flutter/scheduler.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../models/language.dart';
import '../models/review_card.dart';
import '../models/term.dart';
import '../service_locator.dart';
import 'base_controller.dart';

class ReviewItem {
  final ReviewCardRecord reviewCard;
  final Term term;
  final List<Translation> translations;

  const ReviewItem({
    required this.reviewCard,
    required this.term,
    required this.translations,
  });
}

class FlashcardReviewController extends BaseController {
  final Language language;

  List<ReviewItem> _dueItems = [];
  int _currentIndex = 0;
  int _reviewedCount = 0;
  bool _isLoading = true;
  bool _isAnswerRevealed = false;
  bool _isSeeding = false;
  bool _hasReviewed = false;
  bool _isRating = false;
  int _reloadVersion = 0;
  Map<fsrs.Rating, Duration>? _nextIntervals;

  List<ReviewItem> get dueItems => _dueItems;
  int get currentIndex => _currentIndex;
  int get reviewedCount => _reviewedCount;
  bool get isLoading => _isLoading;
  bool get isAnswerRevealed => _isAnswerRevealed;
  bool get isSeeding => _isSeeding;
  bool get hasReviewed => _hasReviewed;
  int get reloadVersion => _reloadVersion;
  Map<fsrs.Rating, Duration>? get nextIntervals => _nextIntervals;

  ReviewItem? get currentItem =>
      _currentIndex < _dueItems.length ? _dueItems[_currentIndex] : null;

  FlashcardReviewController({required this.language}) {
    loadDueCards();
  }

  @override
  void dispose() {
    if (_hasReviewed) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        dataChanges.reviewCards.notify();
        dataChanges.terms.notify();
      });
    }
    super.dispose();
  }

  Future<void> loadDueCards() async {
    _isLoading = true;
    _currentIndex = 0;
    _reviewedCount = 0;
    _isAnswerRevealed = false;
    _nextIntervals = null;
    safeNotify();

    // Ensure all eligible terms have review cards (lazy seeding)
    await _ensureCardsSeeded();

    final dueCards = await db.reviewCards.getDueCards(language.id!);

    // Batch load terms and translations (2 queries instead of 2N)
    final termIds = dueCards.map((rc) => rc.termId).toList();
    final termsMap = await db.terms.getByIds(termIds);
    final translationsMap = await db.translations.getByTermIds(termIds);

    final items = <ReviewItem>[];
    for (final rc in dueCards) {
      final term = termsMap[rc.termId];
      if (term == null) continue;

      var translations = translationsMap[term.id] ?? [];
      // Fallback to legacy translation field
      if (translations.isEmpty && term.translation.isNotEmpty) {
        translations = [
          Translation(termId: term.id ?? 0, meaning: term.translation),
        ];
      }

      items.add(
        ReviewItem(reviewCard: rc, term: term, translations: translations),
      );
    }

    _dueItems = items;
    _isLoading = false;
    safeNotify();
  }

  Future<void> _ensureCardsSeeded() async {
    _isSeeding = true;
    safeNotify();
    await reviewService.seedCardsForLanguage(language.id!);
    _isSeeding = false;
    safeNotify();
  }

  Future<void> rateCard(fsrs.Rating rating) async {
    if (_isRating || _currentIndex >= _dueItems.length) return;

    _isRating = true;
    final item = _dueItems[_currentIndex];
    await reviewService.reviewTerm(item.reviewCard, rating, notify: false);

    _hasReviewed = true;
    _reviewedCount++;
    _currentIndex++;
    _isAnswerRevealed = false;
    _nextIntervals = null;
    _isRating = false;
    safeNotify();
  }

  void revealAnswer() {
    if (_currentIndex >= _dueItems.length) return;

    final item = _dueItems[_currentIndex];
    final intervals = reviewService.getNextIntervals(item.reviewCard.card);

    _isAnswerRevealed = true;
    _nextIntervals = intervals;
    safeNotify();
  }

  Future<void> reloadCurrentItem() async {
    if (_currentIndex >= _dueItems.length) return;

    final currentItem = _dueItems[_currentIndex];
    final termId = currentItem.term.id;
    if (termId == null) return;

    final updatedTerm = await db.terms.getById(termId);
    if (updatedTerm == null) return;

    final translations = await db.translations.getByTermId(termId);

    _dueItems[_currentIndex] = ReviewItem(
      term: updatedTerm,
      reviewCard: currentItem.reviewCard,
      translations: translations,
    );
    _reloadVersion++;
    safeNotify();
  }
}
