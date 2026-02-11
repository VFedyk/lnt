import 'dart:convert';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../models/review_card.dart';
import '../models/term.dart';
import '../service_locator.dart';

class ReviewService {
  ReviewService();

  late final fsrs.Scheduler _scheduler;

  void initialize() {
    _scheduler = fsrs.Scheduler(
      desiredRetention: 0.9,
      learningSteps: const [Duration(minutes: 1), Duration(minutes: 10)],
      relearningSteps: const [Duration(minutes: 10)],
      maximumInterval: 36500,
      enableFuzzing: true,
    );
  }

  /// Process a review rating for a term.
  /// Returns the updated ReviewCardRecord and the new TermStatus.
  Future<({ReviewCardRecord updatedCard, int newStatus})> reviewTerm(
    ReviewCardRecord record,
    fsrs.Rating rating,
  ) async {
    final (:card, :reviewLog) = _scheduler.reviewCard(record.card, rating);
    final newStatus = mapFsrsToTermStatus(card);
    final now = DateTime.now().toUtc();

    // Save review log
    await db.reviewLogs.create(
      record.termId,
      jsonEncode(reviewLog.toMap()),
      now,
    );

    // Update card in DB
    final updatedRecord = ReviewCardRecord(
      id: record.id,
      termId: record.termId,
      card: card,
      nextDue: card.due,
      createdAt: record.createdAt,
      updatedAt: now,
    );
    await db.reviewCards.update(updatedRecord);

    // Update term status
    final term = await db.terms.getById(record.termId);
    if (term != null && term.status != TermStatus.ignored) {
      await db.terms.update(
        term.copyWith(status: newStatus, lastAccessed: DateTime.now()),
      );
    }

    return (updatedCard: updatedRecord, newStatus: newStatus);
  }

  /// Map FSRS card state + stability to TermStatus.
  static int mapFsrsToTermStatus(fsrs.Card card) {
    switch (card.state) {
      case fsrs.State.learning:
        return (card.step ?? 0) <= 0
            ? TermStatus.unknown
            : TermStatus.learning2;
      case fsrs.State.relearning:
        return TermStatus.learning2;
      case fsrs.State.review:
        final stability = card.stability ?? 0;
        if (stability < 7) return TermStatus.learning3;
        if (stability < 30) return TermStatus.learning4;
        if (stability < 90) return TermStatus.known;
        return TermStatus.wellKnown;
    }
  }

  /// Get the approximate next interval for each rating (for UI hints).
  Map<fsrs.Rating, Duration> getNextIntervals(fsrs.Card card) {
    final now = DateTime.now().toUtc();
    final result = <fsrs.Rating, Duration>{};
    for (final rating in fsrs.Rating.values) {
      final preview = _scheduler.reviewCard(card, rating);
      result[rating] = preview.card.due.difference(now);
    }
    return result;
  }

  /// Get retrievability for a card.
  double getRetrievability(fsrs.Card card) {
    return _scheduler.getCardRetrievability(card);
  }
}
