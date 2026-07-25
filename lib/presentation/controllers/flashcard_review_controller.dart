import 'package:flutter/scheduler.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../../domain/entities/language.dart';
import '../../domain/entities/review_card.dart';
import '../../domain/entities/term.dart';
import '../../service_locator.dart';
import '../../services/logger_service.dart';
import '../models/review_session_spec.dart';
import 'base_controller.dart';
import 'review_session_outcome.dart';

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

/// Explicit states of the flashcard review flow.
///
/// Replaces the previous set of independent booleans (`_isLoading`,
/// `_isSeeding`, `_isAnswerRevealed`, `_isRating`) with a single enum that
/// makes invalid combinations impossible.
enum ReviewPhase {
  /// Loading due cards from the database.
  loading,

  /// Seeding review cards for eligible terms (sub-step of initial load;
  /// shows the same loading indicator but is kept distinct for observability).
  seeding,

  /// No cards are due for this language.
  empty,

  /// A card is being shown with its answer hidden.
  question,

  /// A card is shown with answer revealed; rating buttons are visible.
  revealed,

  /// A rating is being persisted asynchronously. No UI notification is emitted
  /// for this phase — it serves only as a re-entry guard.
  rating,

  /// All due cards have been reviewed.
  done,
}

class FlashcardReviewController extends BaseController {
  final ReviewSessionSpec spec;

  /// What went wrong this session; read by the completion screen.
  final ReviewSessionOutcome outcome = ReviewSessionOutcome();

  Language get language => spec.language;

  List<ReviewItem> _dueItems = [];
  int _currentIndex = 0;
  int _reviewedCount = 0;
  ReviewPhase _phase = ReviewPhase.loading;
  bool _hasReviewed = false;
  int _reloadVersion = 0;
  Map<fsrs.Rating, Duration>? _nextIntervals;

  List<ReviewItem> get dueItems => _dueItems;
  int get currentIndex => _currentIndex;
  int get reviewedCount => _reviewedCount;
  ReviewPhase get phase => _phase;
  bool get hasReviewed => _hasReviewed;
  int get reloadVersion => _reloadVersion;
  Map<fsrs.Rating, Duration>? get nextIntervals => _nextIntervals;

  ReviewItem? get currentItem =>
      _currentIndex < _dueItems.length ? _dueItems[_currentIndex] : null;

  FlashcardReviewController({required this.spec}) {
    loadDueCards();
  }

  @override
  void dispose() {
    // A practice pass writes nothing, so there is nothing to invalidate.
    if (_hasReviewed && spec.graded) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        dataChanges.reviewCards.notify();
        dataChanges.terms.notify();
      });
    }
    super.dispose();
  }

  Future<void> loadDueCards() async {
    _phase = ReviewPhase.loading;
    _currentIndex = 0;
    _reviewedCount = 0;
    _nextIntervals = null;
    safeNotify();

    // Ensure all eligible terms have review cards (lazy seeding).
    _phase = ReviewPhase.seeding;
    safeNotify();
    await reviewService.seedCardsForLanguage(language.id!);

    _phase = ReviewPhase.loading;
    safeNotify();

    final dueCards =
        await db.reviewCards.getDueCards(language.id!, scope: spec.scope);

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
          Translation(termId: term.id ?? '', meaning: term.translation),
        ];
      }

      items.add(
        ReviewItem(reviewCard: rc, term: term, translations: translations),
      );
    }

    _dueItems = items;
    _phase = _dueItems.isEmpty ? ReviewPhase.empty : ReviewPhase.question;
    safeNotify();
  }

  Future<void> rateCard(fsrs.Rating rating) async {
    // Guard against re-entry and post-completion calls.
    if (_phase == ReviewPhase.rating || _phase == ReviewPhase.done) return;

    // Transition to rating phase without notifying — the UI stays in its
    // current revealed state while the async write completes.
    _phase = ReviewPhase.rating;

    final item = _dueItems[_currentIndex];
    try {
      if (spec.graded) {
        await reviewService.reviewTerm(item.reviewCard, rating, notify: false);
      } else {
        await reviewService.practiceTerm(item.reviewCard, rating);
      }
    } catch (e, stackTrace) {
      // Never strand the phase on `rating`: the UI is still showing the
      // revealed card, and the re-entry guard above would silently swallow
      // every further tap and keystroke for the rest of the session.
      AppLogger.error('Rating a card failed', error: e, stackTrace: stackTrace);
      _phase = ReviewPhase.revealed;
      safeNotify();
      return;
    }
    final termId = item.term.id;
    if (termId != null) outcome.record(termId, rating);

    _hasReviewed = true;
    _reviewedCount++;
    _currentIndex++;
    _nextIntervals = null;
    _phase = _currentIndex >= _dueItems.length
        ? ReviewPhase.done
        : ReviewPhase.question;
    safeNotify();
  }

  void revealAnswer() {
    if (_phase != ReviewPhase.question) return;

    final item = _dueItems[_currentIndex];
    _nextIntervals = reviewService.getNextIntervals(item.reviewCard.cardData);
    _phase = ReviewPhase.revealed;
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
