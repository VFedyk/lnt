import 'dart:convert';
import 'package:fsrs/fsrs.dart' as fsrs;
import '../../../domain/entities/review_card.dart';
import '../../../domain/repositories/review_card_repository.dart';
import '../../../domain/repositories/review_log_repository.dart';
import '../../../domain/repositories/term_repository.dart';
import '../../../domain/repositories/term_status_log_repository.dart';
import '../../../domain/value_objects/term_status.dart';

class ReviewTerm {
  ReviewTerm({
    required ReviewCardRepository reviewCards,
    required TermRepository terms,
    required ReviewLogRepository reviewLogs,
    required TermStatusLogRepository termStatusLog,
  })  : _reviewCards = reviewCards,
        _terms = terms,
        _reviewLogs = reviewLogs,
        _termStatusLog = termStatusLog,
        _scheduler = fsrs.Scheduler(
          desiredRetention: 0.9,
          learningSteps: const [Duration(minutes: 1), Duration(minutes: 10)],
          relearningSteps: const [Duration(minutes: 10)],
          maximumInterval: 36500,
          enableFuzzing: true,
        );

  final ReviewCardRepository _reviewCards;
  final TermRepository _terms;
  final ReviewLogRepository _reviewLogs;
  final TermStatusLogRepository _termStatusLog;
  final fsrs.Scheduler _scheduler;

  Future<({ReviewCardRecord updatedCard, int newStatus})> call(
    ReviewCardRecord record,
    fsrs.Rating rating,
  ) async {
    final currentCard = fsrs.Card.fromMap(record.cardData);
    final (:card, :reviewLog) = _scheduler.reviewCard(currentCard, rating);
    final newStatus = mapFsrsToTermStatus(card);
    final now = DateTime.now().toUtc();

    final updatedRecord = ReviewCardRecord(
      id: record.id,
      termId: record.termId,
      cardData: card.toMap(),
      nextDue: card.due,
      createdAt: record.createdAt,
      updatedAt: now,
    );

    await _reviewLogs.create(record.termId, jsonEncode(reviewLog.toMap()), now);
    await _reviewCards.update(updatedRecord);

    final term = await _terms.getById(record.termId);
    if (term != null && term.status != TermStatus.ignored) {
      await _terms.update(term.copyWith(status: newStatus, lastAccessed: now));
      await _termStatusLog.logChange(record.termId, newStatus, now);
    }

    return (updatedCard: updatedRecord, newStatus: newStatus);
  }

  Map<fsrs.Rating, Duration> nextIntervals(Map<String, dynamic> cardData) {
    final card = fsrs.Card.fromMap(cardData);
    final now = DateTime.now().toUtc();
    return {
      for (final r in fsrs.Rating.values)
        r: _scheduler.reviewCard(card, r).card.due.difference(now),
    };
  }

  double retrievability(Map<String, dynamic> cardData) =>
      _scheduler.getCardRetrievability(fsrs.Card.fromMap(cardData));

  static int mapFsrsToTermStatus(fsrs.Card card) {
    switch (card.state) {
      case fsrs.State.learning:
        return (card.step ?? 0) <= 0 ? TermStatus.unknown : TermStatus.learning2;
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
}
