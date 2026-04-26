import 'dart:convert';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../domain/entities/review_card.dart';
import '../service_locator.dart';
import '../domain/value_objects/term_status.dart';

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
  /// All writes run inside a single transaction for consistency.
  Future<({ReviewCardRecord updatedCard, int newStatus})> reviewTerm(
    ReviewCardRecord record,
    fsrs.Rating rating, {
    bool notify = true,
  }) async {
    final currentCard = fsrs.Card.fromMap(record.cardData);
    final (:card, :reviewLog) = _scheduler.reviewCard(currentCard, rating);
    final newStatus = mapFsrsToTermStatus(card);
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();

    final updatedRecord = ReviewCardRecord(
      id: record.id,
      termId: record.termId,
      cardData: card.toMap(),
      nextDue: card.due,
      createdAt: record.createdAt,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      // Save review log
      await txn.insert('review_logs', {
        'term_id': record.termId,
        'log_data': jsonEncode(reviewLog.toMap()),
        'reviewed_at': nowIso,
      });

      // Update review card
      await txn.update(
        'review_cards',
        updatedRecord.toMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );

      // Update term status
      final termMaps = await txn.query(
        'terms',
        where: 'id = ?',
        whereArgs: [record.termId],
      );
      if (termMaps.isNotEmpty) {
        final termStatus = termMaps.first['status'] as int;
        if (termStatus != TermStatus.ignored) {
          await txn.update(
            'terms',
            {'status': newStatus, 'last_accessed': nowIso},
            where: 'id = ?',
            whereArgs: [record.termId],
          );
          // Log status change for history chart (always log so graph has data
          // even when status stays the same — the query uses the latest entry).
          await txn.insert('term_status_log', {
            'term_id': record.termId,
            'status': newStatus,
            'changed_at': nowIso,
          });
        }
      }
    });

    if (notify) {
      db.reviewCards.notifyChange();
      db.terms.notifyChange();
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
  Map<fsrs.Rating, Duration> getNextIntervals(Map<String, dynamic> cardData) {
    final card = fsrs.Card.fromMap(cardData);
    final now = DateTime.now().toUtc();
    final result = <fsrs.Rating, Duration>{};
    for (final rating in fsrs.Rating.values) {
      final preview = _scheduler.reviewCard(card, rating);
      result[rating] = preview.card.due.difference(now);
    }
    return result;
  }

  /// Get retrievability for a card.
  double getRetrievability(Map<String, dynamic> cardData) {
    return _scheduler.getCardRetrievability(fsrs.Card.fromMap(cardData));
  }

  /// Ensure review cards exist for all eligible terms in a language.
  /// Eligible = not ignored and not well-known.
  Future<void> seedCardsForLanguage(String languageId) async {
    final allTerms = await db.terms.getAll(languageId: languageId);
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
  }
}
