import 'dart:async';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:uuid/uuid.dart';
import '../../domain/entities/review_card.dart';
import '../../domain/events/term_event.dart';
import '../../domain/repositories/review_card_repository.dart';
import '../../services/settings_service.dart';
import '../../utils/constants.dart';
import '../../domain/value_objects/review_scope.dart';
import '../../domain/value_objects/term_status.dart';
import 'base_repository.dart';

const _uuid = Uuid();

class ReviewCardRepositoryImpl extends BaseRepository
    implements ReviewCardRepository {
  StreamSubscription<TermEvent>? _termSub;
  final SettingsService? _settings;

  ReviewCardRepositoryImpl(super.getDatabase,
      {super.onChange, SettingsService? settings})
      : _settings = settings;

  /// SQL fragment that is 1 when a card has never been reviewed.
  static const String _isNewExpr =
      "CASE WHEN NOT EXISTS (SELECT 1 FROM review_logs rl WHERE rl.term_id = rc.term_id) THEN 1 ELSE 0 END";

  /// The daily new-card budget, or null when it does not apply.
  ///
  /// A practice pass (`includeNotDue`) deliberately bypasses it: the user asked
  /// for *every* word in a text, and the pass writes nothing, so there is no
  /// scheduling budget to protect.
  Future<int?> _budgetFor(String languageId, ReviewScope scope) =>
      scope.includeNotDue ? Future.value(null) : _newCardBudget(languageId);

  /// Remaining new cards allowed today, or null when there is no limit.
  Future<int?> _newCardBudget(String languageId) async {
    final settings = _settings;
    if (settings == null) return null;
    final perDay = await settings.getNewCardsPerDay();
    if (perDay <= 0) return null;
    final introduced = await _countNewCardsIntroducedToday(languageId);
    final budget = perDay - introduced;
    return budget < 0 ? 0 : budget;
  }

  /// Resolves the SQL fetch ceiling and the final trim cap for [getDueCards].
  ///
  /// - An explicit [limit] always wins and is used verbatim.
  /// - Otherwise the user's session card limit applies: its value is the trim
  ///   cap and the SQL fetches `2×` slack so the daily new-card budget filter
  ///   (which drops rows *after* the SQL LIMIT) cannot shrink the session
  ///   below the chosen size.
  /// - `0` (unlimited) with a [SettingsService] injected fetches everything
  ///   (SQLite treats a negative LIMIT as no limit).
  /// - No [SettingsService] injected falls back to the historical
  ///   [AppConstants.dueCardLimit], so tests and non-UI callers are unaffected.
  Future<({int fetchLimit, int? sessionLimit})> _resolveLimits(int? limit) async {
    if (limit != null) return (fetchLimit: limit, sessionLimit: limit);
    final settings = _settings;
    if (settings == null) {
      return (fetchLimit: AppConstants.dueCardLimit, sessionLimit: null);
    }
    final value = await settings.getSessionCardLimit();
    if (value <= 0) return (fetchLimit: -1, sessionLimit: null);
    return (
      fetchLimit: (value * 2).clamp(0, AppConstants.dueCardLimit * 2),
      sessionLimit: value,
    );
  }

  /// Number of terms whose first-ever review happened today.
  Future<int> _countNewCardsIntroducedToday(String languageId) async {
    final db = await getDatabase();
    final now = DateTime.now().toUtc();
    final todayStart =
        DateTime.utc(now.year, now.month, now.day).toIso8601String();
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as cnt FROM (
        SELECT rl.term_id FROM review_logs rl
        INNER JOIN terms t ON t.id = rl.term_id
        WHERE t.language_id = ?
        GROUP BY rl.term_id
        HAVING MIN(rl.reviewed_at) >= ?
      )
      ''',
      [languageId, todayStart],
    );
    return result.first['cnt'] as int;
  }

  void subscribeToTermEvents(Stream<TermEvent> events) {
    _termSub = events.listen(_onTermEvent);
  }

  Future<void> _onTermEvent(TermEvent event) async {
    switch (event) {
      case TermWritten(:final id, :final status):
        if (status == TermStatus.ignored) {
          await deleteByTermId(id);
        } else {
          await getOrCreate(id);
        }
      case TermsBulkWritten(:final terms):
        final reviewable = terms
            .where((t) => t.status != TermStatus.ignored)
            .map((t) => t.id)
            .toList();
        final nonReviewable = terms
            .where((t) => t.status == TermStatus.ignored)
            .map((t) => t.id)
            .toList();
        await ensureCardsExist(reviewable);
        for (final id in nonReviewable) {
          await deleteByTermId(id);
        }
    }
  }

  void cancelTermSubscription() => _termSub?.cancel();

  @override
  Future<String> create(ReviewCardRecord record) async {
    final db = await getDatabase();
    final id = record.id ?? _uuid.v4();
    await db.insert('review_cards', record.copyWith(id: id).toMap());
    notifyChange();
    return id;
  }

  @override
  Future<ReviewCardRecord?> getByTermId(String termId) async {
    final db = await getDatabase();
    final maps = await db.query(
      'review_cards',
      where: 'term_id = ?',
      whereArgs: [termId],
    );
    if (maps.isEmpty) return null;
    return ReviewCardRecord.fromMap(maps.first);
  }

  @override
  Future<int> update(ReviewCardRecord record) async {
    final db = await getDatabase();
    final result = await db.update(
      'review_cards',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    notifyChange();
    return result;
  }

  @override
  Future<int> deleteByTermId(String termId) async {
    final db = await getDatabase();
    // Ids are read up front so each removed card gets its own tombstone —
    // sync addresses cards by id, not by term_id.
    final cardIds = (await db.query('review_cards',
            columns: ['id'], where: 'term_id = ?', whereArgs: [termId]))
        .map((r) => r['id'] as String)
        .toList();
    final result = await db.delete(
      'review_cards',
      where: 'term_id = ?',
      whereArgs: [termId],
    );
    for (final cardId in cardIds) {
      await BaseRepository.recordTombstone(db, 'review_card', cardId);
    }
    notifyChange();
    return result;
  }

  /// Builds the scope predicate and its bind arguments. The returned SQL is
  /// appended inside the existing WHERE chain and always starts with AND
  /// (or is empty).
  ///
  /// Text scoping is a correlated EXISTS rather than an `IN (…)` list of term
  /// ids: a chapter can contain well over SQLite's 999 host-parameter limit.
  static ({String sql, List<Object?> args}) _scopeClause(ReviewScope scope) {
    final sql = StringBuffer();
    final args = <Object?>[];

    final statuses = scope.statuses;
    if (statuses != null && statuses.isNotEmpty) {
      sql.write(
          ' AND t.status IN (${List.filled(statuses.length, '?').join(', ')})');
      args.addAll(statuses);
    }

    final hasText = scope.textId != null;
    final hasExtra = scope.extraTermIds.isNotEmpty;
    if (hasText || hasExtra) {
      final parts = <String>[];
      if (hasText) {
        parts.add(
          'EXISTS (SELECT 1 FROM text_words tw '
          'WHERE tw.text_id = ? AND tw.lower_text = t.lower_text)',
        );
        args.add(scope.textId);
      }
      if (hasExtra) {
        final ids = scope.extraTermIds.take(400).toList();
        parts.add('rc.term_id IN (${List.filled(ids.length, '?').join(', ')})');
        args.addAll(ids);
      }
      sql.write(' AND (${parts.join(' OR ')})');
    }

    return (sql: sql.toString(), args: args);
  }

  /// `AND rc.next_due <= ?` unless the scope asks for not-yet-due cards too.
  static String _dueClause(ReviewScope scope) =>
      scope.includeNotDue ? '' : 'AND rc.next_due <= ?';

  static List<Object?> _dueArgs(ReviewScope scope, DateTime now) =>
      scope.includeNotDue ? const [] : [now.toIso8601String()];

  @override
  Future<List<ReviewCardRecord>> getDueCards(String languageId,
          {DateTime? now,
          int? limit,
          ReviewScope scope = const ReviewScope()}) =>
      _dueCards(languageId, now: now, limit: limit, scope: scope);

  @override
  Future<List<ReviewCardRecord>> getClozeDueCandidates(String languageId,
          {DateTime? now, ReviewScope scope = const ReviewScope()}) =>
      _dueCards(languageId,
          now: now,
          scope: scope,
          requireSentence: true,
          applySessionLimit: false);

  /// Shared body of [getDueCards] / [getClozeDueCandidates].
  ///
  /// - [requireSentence] appends the `term_sentences` EXISTS guard.
  /// - [applySessionLimit] false skips the user's session card limit entirely
  ///   (fetch everything, trim nothing) — the cloze caller trims after it has
  ///   dropped the cards whose sentence has no usable occurrence.
  Future<List<ReviewCardRecord>> _dueCards(
    String languageId, {
    DateTime? now,
    int? limit,
    ReviewScope scope = const ReviewScope(),
    bool requireSentence = false,
    bool applySessionLimit = true,
  }) async {
    final db = await getDatabase();
    now ??= DateTime.now().toUtc();
    final limits = applySessionLimit
        ? await _resolveLimits(limit)
        : (fetchLimit: limit ?? -1, sessionLimit: null);
    final sessionLimit = limits.sessionLimit;
    final scopeClause = _scopeClause(scope);
    final sentenceClause = requireSentence
        ? 'AND EXISTS (SELECT 1 FROM term_sentences ts WHERE ts.term_id = t.id)'
        : '';
    // ORDER BY next_due already yields overdue → due → future, which is the
    // right ordering for an includeNotDue session too.
    final maps = await db.rawQuery(
      '''
      SELECT rc.*, $_isNewExpr AS is_new FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        ${_dueClause(scope)}
        ${scopeClause.sql}
        $sentenceClause
      ORDER BY rc.next_due ASC
      LIMIT ?
      ''',
      [
        languageId,
        ..._dueArgs(scope, now),
        ...scopeClause.args,
        limits.fetchLimit,
      ],
    );

    final budget = await _budgetFor(languageId, scope);
    if (budget == null) {
      final all = maps.map((m) => ReviewCardRecord.fromMap(m)).toList();
      return sessionLimit == null ? all : all.take(sessionLimit).toList();
    }

    // Review cards are always shown; new cards are capped by the daily budget.
    // The session card limit trims the tail (ORDER BY next_due ASC keeps the
    // most-overdue cards).
    final result = <ReviewCardRecord>[];
    var newUsed = 0;
    for (final m in maps) {
      if ((m['is_new'] as int) == 1) {
        if (newUsed >= budget) continue;
        newUsed++;
      }
      result.add(ReviewCardRecord.fromMap(m));
      if (sessionLimit != null && result.length >= sessionLimit) break;
    }
    return result;
  }

  /// Total due once the daily new-card [budget] is applied (review cards are
  /// always counted; new cards are capped).
  int _applyBudget(int total, int newCnt, int? budget) {
    if (budget == null) return total;
    final cappedNew = newCnt < budget ? newCnt : budget;
    return (total - newCnt) + cappedNew;
  }

  @override
  Future<int> getDueCount(String languageId,
      {DateTime? now, ReviewScope scope = const ReviewScope()}) async {
    final db = await getDatabase();
    now ??= DateTime.now().toUtc();
    final scopeClause = _scopeClause(scope);
    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) as total, COALESCE(SUM($_isNewExpr), 0) as new_cnt
      FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        ${_dueClause(scope)}
        ${scopeClause.sql}
      ''',
      [languageId, ..._dueArgs(scope, now), ...scopeClause.args],
    );
    final total = result.first['total'] as int;
    final newCnt = result.first['new_cnt'] as int;
    return _applyBudget(total, newCnt, await _budgetFor(languageId, scope));
  }

  @override
  Future<DateTime?> getNextDueDate(String languageId) async {
    final db = await getDatabase();
    final result = await db.rawQuery(
      '''
      SELECT MIN(rc.next_due) as next_due FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
      ''',
      [languageId],
    );
    final value = result.first['next_due'] as String?;
    if (value == null) return null;
    return DateTime.parse(value);
  }

  @override
  Future<List<({DateTime date, int count})>> getDueForecast(
    String languageId, {
    int days = 14,
    DateTime? now,
  }) async {
    final db = await getDatabase();
    now ??= DateTime.now().toUtc();
    final todayStart = DateTime.utc(now.year, now.month, now.day);
    final end = todayStart.add(Duration(days: days));

    // No lower bound: overdue cards are folded into today's bucket below.
    final rows = await db.rawQuery(
      '''
      SELECT DATE(rc.next_due) as date, COUNT(*) as cnt
      FROM review_cards rc
      INNER JOIN terms t ON t.id = rc.term_id
      WHERE t.language_id = ?
        AND t.status != 0
        AND rc.next_due < ?
      GROUP BY DATE(rc.next_due)
      ''',
      [languageId, end.toIso8601String()],
    );

    String dayKey(DateTime d) => d.toIso8601String().substring(0, 10);
    final todayKey = dayKey(todayStart);
    final counts = <String, int>{};
    for (final row in rows) {
      final date = row['date'] as String;
      final cnt = row['cnt'] as int;
      // Anything due today or earlier (overdue) collapses into the first bar.
      final key = date.compareTo(todayKey) <= 0 ? todayKey : date;
      counts[key] = (counts[key] ?? 0) + cnt;
    }

    return List.generate(days, (i) {
      final day = todayStart.add(Duration(days: i));
      return (date: day, count: counts[dayKey(day)] ?? 0);
    });
  }

  @override
  Future<ReviewCardRecord> getOrCreate(String termId) async {
    final existing = await getByTermId(termId);
    if (existing != null) return existing;

    final now = DateTime.now().toUtc();
    final card = fsrs.Card(
      cardId: now.millisecondsSinceEpoch,
      due: now,
    );
    final record = ReviewCardRecord(
      termId: termId,
      cardData: card.toMap(),
      nextDue: now,
      createdAt: now,
      updatedAt: now,
    );
    final id = await create(record);
    return record.copyWith(id: id);
  }

  @override
  Future<void> ensureCardsExist(List<String> termIds) async {
    if (termIds.isEmpty) return;

    final db = await getDatabase();
    const batchSize = 500;
    final existingIds = <String>{};

    for (var i = 0; i < termIds.length; i += batchSize) {
      final batch = termIds.skip(i).take(batchSize).toList();
      final placeholders = List.filled(batch.length, '?').join(',');
      final maps = await db.rawQuery(
        'SELECT term_id FROM review_cards WHERE term_id IN ($placeholders)',
        batch,
      );
      existingIds.addAll(maps.map((m) => m['term_id'] as String));
    }

    final missingIds = termIds.where((id) => !existingIds.contains(id)).toList();
    if (missingIds.isEmpty) return;

    final now = DateTime.now().toUtc();
    final dbBatch = db.batch();
    for (var i = 0; i < missingIds.length; i++) {
      final termId = missingIds[i];
      final card = fsrs.Card(
        cardId: now.millisecondsSinceEpoch + i,
        due: now,
      );
      final record = ReviewCardRecord(
        id: _uuid.v4(),
        termId: termId,
        cardData: card.toMap(),
        nextDue: now,
        createdAt: now,
        updatedAt: now,
      );
      dbBatch.insert('review_cards', record.toMap());
    }
    await dbBatch.commit(noResult: true);
    notifyChange();
  }
}
