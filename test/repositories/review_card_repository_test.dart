import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:language_nerd_tools/data/datasources/database_migrations.dart'
    as migrations;
import 'package:language_nerd_tools/data/repositories/review_card_repository_impl.dart';
import 'package:language_nerd_tools/domain/entities/review_card.dart';
import 'package:language_nerd_tools/domain/events/term_event.dart';
import 'package:language_nerd_tools/domain/value_objects/review_scope.dart';
import 'package:language_nerd_tools/domain/value_objects/term_status.dart';
import 'package:language_nerd_tools/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> _openTestDb() async {
  return await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: migrations.databaseVersion,
      onCreate: migrations.onCreate,
      onUpgrade: migrations.onUpgrade,
    ),
  );
}

Future<void> _insertTerm(
  Database db, {
  required String id,
  int status = TermStatus.known,
  String languageId = 'lang-1',
}) async {
  final now = DateTime.now().toUtc().toIso8601String();
  await db.insert('terms', {
    'id': id,
    'language_id': languageId,
    'text': id,
    'lower_text': id,
    'status': status,
    'created_at': now,
    'last_accessed': now,
  });
}

Future<void> _insertDueCard(
  ReviewCardRepositoryImpl repo, {
  required String termId,
}) async {
  final past = DateTime.now().toUtc().subtract(const Duration(days: 1));
  final card = fsrs.Card(cardId: 1, due: past)
    ..state = fsrs.State.review
    ..stability = 100.0;
  await repo.create(ReviewCardRecord(
    termId: termId,
    cardData: card.toMap(),
    nextDue: past,
    createdAt: past,
    updatedAt: past,
  ));
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // A term reaching "well known" (status 99) must keep its FSRS card so it stays
  // scheduled; only "ignored" (status 0) terms should have their card removed.
  group('term-event card lifecycle', () {
    late Database db;
    late ReviewCardRepositoryImpl repo;
    late StreamController<TermEvent> events;

    setUp(() async {
      db = await _openTestDb();
      repo = ReviewCardRepositoryImpl(() async => db);
      events = StreamController<TermEvent>();
      repo.subscribeToTermEvents(events.stream);
    });

    tearDown(() async {
      repo.cancelTermSubscription();
      await events.close();
      await db.close();
    });

    test('well-known term keeps its review card', () async {
      await repo.getOrCreate('term-1');
      events.add(TermWritten('term-1', TermStatus.wellKnown));
      await pumpEventQueue();
      expect(await repo.getByTermId('term-1'), isNotNull);
    });

    test('ignored term deletes its review card', () async {
      await repo.getOrCreate('term-1');
      events.add(TermWritten('term-1', TermStatus.ignored));
      await pumpEventQueue();
      expect(await repo.getByTermId('term-1'), isNull);
    });

    test('bulk write keeps non-ignored cards and drops ignored ones', () async {
      await repo.getOrCreate('keep');
      await repo.getOrCreate('drop');
      events.add(TermsBulkWritten([
        (id: 'keep', status: TermStatus.wellKnown),
        (id: 'drop', status: TermStatus.ignored),
      ]));
      await pumpEventQueue();
      expect(await repo.getByTermId('keep'), isNotNull);
      expect(await repo.getByTermId('drop'), isNull);
    });
  });

  group('getDueCards status filtering', () {
    late Database db;
    late ReviewCardRepositoryImpl repo;

    setUp(() async {
      db = await _openTestDb();
      repo = ReviewCardRepositoryImpl(() async => db);
    });

    tearDown(() async => db.close());

    test('returns a due well-known term', () async {
      await _insertTerm(db, id: 'wk', status: TermStatus.wellKnown);
      await _insertDueCard(repo, termId: 'wk');
      final due = await repo.getDueCards('lang-1');
      expect(due.map((c) => c.termId), contains('wk'));
    });

    test('excludes ignored terms', () async {
      await _insertTerm(db, id: 'ig', status: TermStatus.ignored);
      await _insertDueCard(repo, termId: 'ig');
      final due = await repo.getDueCards('lang-1');
      expect(due.map((c) => c.termId), isNot(contains('ig')));
    });
  });

  group('getDueForecast', () {
    late Database db;
    late ReviewCardRepositoryImpl repo;

    setUp(() async {
      db = await _openTestDb();
      repo = ReviewCardRepositoryImpl(() async => db);
    });

    tearDown(() async => db.close());

    Future<void> insertCard(String termId, DateTime due) async {
      await repo.create(ReviewCardRecord(
        termId: termId,
        cardData: fsrs.Card(cardId: 1, due: due).toMap(),
        nextDue: due,
        createdAt: due,
        updatedAt: due,
      ));
    }

    test('buckets upcoming cards and folds overdue into today', () async {
      final now = DateTime.utc(2026, 6, 13, 12);
      final today = DateTime.utc(2026, 6, 13);
      await _insertTerm(db, id: 'a');
      await _insertTerm(db, id: 'b');
      await _insertTerm(db, id: 'c');
      await _insertTerm(db, id: 'd');
      await _insertTerm(db, id: 'e', status: TermStatus.ignored);

      await insertCard('a', today.subtract(const Duration(days: 2))); // overdue
      await insertCard('b', today.add(const Duration(hours: 5))); // today
      await insertCard('c', today.add(const Duration(days: 3))); // +3 days
      await insertCard('d', today.add(const Duration(days: 30))); // out of range
      await insertCard('e', today); // ignored term

      final forecast = await repo.getDueForecast('lang-1', days: 7, now: now);

      expect(forecast.length, 7);
      expect(forecast.first.count, 2); // overdue + today
      expect(forecast[3].count, 1); // +3 days
      // 'd' (out of range) and 'e' (ignored) are excluded.
      expect(forecast.fold<int>(0, (s, d) => s + d.count), 3);
    });
  });

  group('daily new-card limit', () {
    late Database db;

    setUp(() async {
      db = await _openTestDb();
    });

    tearDown(() async => db.close());

    ReviewCardRepositoryImpl makeRepo(int perDay) {
      SharedPreferences.setMockInitialValues({'new_cards_per_day': perDay});
      return ReviewCardRepositoryImpl(() async => db, settings: SettingsService());
    }

    final past = DateTime.now().toUtc().subtract(const Duration(days: 1));

    Future<void> insertDueCard(ReviewCardRepositoryImpl repo, String termId) async {
      await _insertTerm(db, id: termId);
      await repo.create(ReviewCardRecord(
        termId: termId,
        cardData: fsrs.Card(cardId: 1, due: past).toMap(),
        nextDue: past,
        createdAt: past,
        updatedAt: past,
      ));
    }

    // Adds a prior review so the card counts as "review" rather than "new".
    Future<void> markReviewed(String termId, {required DateTime at}) async {
      await db.insert('review_logs', {
        'id': '$termId-log',
        'term_id': termId,
        'log_data': '{}',
        'reviewed_at': at.toIso8601String(),
      });
    }

    test('caps new cards but never review cards', () async {
      final repo = makeRepo(2);
      for (final id in ['n1', 'n2', 'n3', 'n4', 'n5']) {
        await insertDueCard(repo, id);
      }
      for (final id in ['r1', 'r2']) {
        await insertDueCard(repo, id);
        await markReviewed(id, at: past); // reviewed yesterday → not "new"
      }

      final due = await repo.getDueCards('lang-1');
      final newCount = due.where((c) => c.termId.startsWith('n')).length;
      final reviewCount = due.where((c) => c.termId.startsWith('r')).length;
      expect(newCount, 2); // capped at budget
      expect(reviewCount, 2); // all review cards
      expect(await repo.getDueCount('lang-1'), 4);
    });

    test('cards already introduced today reduce the budget', () async {
      final repo = makeRepo(3);
      for (final id in ['n1', 'n2', 'n3', 'n4']) {
        await insertDueCard(repo, id);
      }
      // A term first reviewed today consumes one of today's new-card slots.
      await _insertTerm(db, id: 'seenToday');
      await markReviewed('seenToday', at: DateTime.now().toUtc());

      final due = await repo.getDueCards('lang-1');
      expect(due.where((c) => c.termId.startsWith('n')).length, 2); // 3 - 1
      expect(await repo.getDueCount('lang-1'), 2);
    });

    test('zero means unlimited', () async {
      final repo = makeRepo(0);
      for (final id in ['n1', 'n2', 'n3', 'n4', 'n5']) {
        await insertDueCard(repo, id);
      }
      expect((await repo.getDueCards('lang-1')).length, 5);
      expect(await repo.getDueCount('lang-1'), 5);
    });
  });

  group('session card limit', () {
    late Database db;

    setUp(() async {
      db = await _openTestDb();
    });

    tearDown(() async => db.close());

    ReviewCardRepositoryImpl makeRepo({int? sessionLimit, int? perDay}) {
      SharedPreferences.setMockInitialValues({
        'session_card_limit': ?sessionLimit,
        'new_cards_per_day': ?perDay,
      });
      return ReviewCardRepositoryImpl(() async => db,
          settings: SettingsService());
    }

    final base = DateTime.now().toUtc().subtract(const Duration(days: 5));

    // [dueOffset] shifts next_due so ordering is controllable; [reviewed] adds a
    // prior review so the card counts as "review" rather than "new".
    Future<void> insertCard(
      ReviewCardRepositoryImpl repo,
      String termId, {
      Duration dueOffset = Duration.zero,
      bool reviewed = false,
    }) async {
      await _insertTerm(db, id: termId);
      final due = base.add(dueOffset);
      await repo.create(ReviewCardRecord(
        termId: termId,
        cardData: fsrs.Card(cardId: 1, due: due).toMap(),
        nextDue: due,
        createdAt: due,
        updatedAt: due,
      ));
      if (reviewed) {
        await db.insert('review_logs', {
          'id': '$termId-log',
          'term_id': termId,
          'log_data': '{}',
          'reviewed_at': base.toIso8601String(),
        });
      }
    }

    Future<void> insertDueCards(
      ReviewCardRepositoryImpl repo,
      int count, {
      String prefix = 'c',
    }) async {
      for (var i = 0; i < count; i++) {
        await insertCard(repo, '$prefix$i',
            dueOffset: Duration(minutes: i), reviewed: true);
      }
    }

    test('caps the session', () async {
      final repo = makeRepo(sessionLimit: 10);
      await insertDueCards(repo, 30);
      expect((await repo.getDueCards('lang-1')).length, 10);
    });

    test('returns everything below the cap', () async {
      final repo = makeRepo(sessionLimit: 50);
      await insertDueCards(repo, 5);
      expect((await repo.getDueCards('lang-1')).length, 5);
    });

    test('0 means unlimited', () async {
      final repo = makeRepo(sessionLimit: 0);
      await insertDueCards(repo, 30);
      expect((await repo.getDueCards('lang-1')).length, 30);
    });

    test('no SettingsService injected keeps historical behaviour', () async {
      final repo = ReviewCardRepositoryImpl(() async => db);
      await insertDueCards(repo, 30);
      expect((await repo.getDueCards('lang-1')).length, 30);
    });

    test('an explicit limit argument overrides the setting', () async {
      final repo = makeRepo(sessionLimit: 100);
      await insertDueCards(repo, 30);
      expect((await repo.getDueCards('lang-1', limit: 3)).length, 3);
    });

    test('over-fetches so the new-card budget filter cannot shrink the session',
        () async {
      final repo = makeRepo(sessionLimit: 10, perDay: 5);
      // 10 new cards ordered ahead of 10 review cards by next_due.
      for (var i = 0; i < 10; i++) {
        await insertCard(repo, 'new$i', dueOffset: Duration(minutes: i));
      }
      for (var i = 0; i < 10; i++) {
        await insertCard(repo, 'rev$i',
            dueOffset: Duration(minutes: 100 + i), reviewed: true);
      }
      final due = await repo.getDueCards('lang-1');
      expect(due.length, 10); // 5 new (budget) + 5 review
      expect(due.where((c) => c.termId.startsWith('new')).length, 5);
      expect(due.where((c) => c.termId.startsWith('rev')).length, 5);
    });

    test('practice scope is capped too', () async {
      final repo = makeRepo(sessionLimit: 10);
      await insertDueCards(repo, 30);
      final due = await repo.getDueCards('lang-1',
          scope: const ReviewScope(includeNotDue: true));
      expect(due.length, 10);
    });

    test('getDueCount is unaffected', () async {
      final repo = makeRepo(sessionLimit: 10);
      await insertDueCards(repo, 30);
      expect(await repo.getDueCount('lang-1'), 30);
    });
  });

  group('status filter', () {
    late Database db;
    late ReviewCardRepositoryImpl repo;

    setUp(() async {
      db = await _openTestDb();
      repo = ReviewCardRepositoryImpl(() async => db);
      // One due card per status group.
      for (final entry in {
        'u': TermStatus.unknown,
        'l': TermStatus.learning3,
        'k': TermStatus.known,
        'w': TermStatus.wellKnown,
        'ig': TermStatus.ignored,
      }.entries) {
        await _insertTerm(db, id: entry.key, status: entry.value);
        await _insertDueCard(repo, termId: entry.key);
      }
    });

    tearDown(() async => db.close());

    test('null returns every non-ignored due card', () async {
      final due = await repo.getDueCards('lang-1');
      expect(due.map((c) => c.termId).toSet(), {'u', 'l', 'k', 'w'});
      expect(await repo.getDueCount('lang-1'), 4);
    });

    test('filters cards and count to the requested statuses', () async {
      const scope = ReviewScope(statuses: [TermStatus.known]);
      final due = await repo.getDueCards('lang-1', scope: scope);
      expect(due.map((c) => c.termId), ['k']);
      expect(await repo.getDueCount('lang-1', scope: scope), 1);
    });

    test('supports multiple statuses', () async {
      final due = await repo.getDueCards(
        'lang-1',
        scope: const ReviewScope(
          statuses: [TermStatus.unknown, TermStatus.wellKnown],
        ),
      );
      expect(due.map((c) => c.termId).toSet(), {'u', 'w'});
    });

    test('ignored stays excluded even if its status is requested', () async {
      final due = await repo.getDueCards(
        'lang-1',
        scope: const ReviewScope(
          statuses: [TermStatus.ignored, TermStatus.known],
        ),
      );
      expect(due.map((c) => c.termId), ['k']);
    });
  });

  group('text scope', () {
    late Database db;
    late ReviewCardRepositoryImpl repo;

    Future<void> indexWord(String textId, String lowerText) async {
      await db.insert('text_words', {
        'text_id': textId,
        'lower_text': lowerText,
        'occurrences': 1,
        'first_position': 0,
      });
    }

    setUp(() async {
      db = await _openTestDb();
      repo = ReviewCardRepositoryImpl(() async => db);
      // 'in1'/'in2' occur in text x1, 'out' does not. 'phrase' is a multi-word
      // term, which the word index cannot represent.
      for (final id in ['in1', 'in2', 'out', 'phrase']) {
        await _insertTerm(db, id: id);
        await _insertDueCard(repo, termId: id);
      }
      await indexWord('x1', 'in1');
      await indexWord('x1', 'in2');
      await indexWord('x2', 'out');
    });

    tearDown(() async => db.close());

    test('restricts to terms occurring in the text', () async {
      const scope = ReviewScope(textId: 'x1');
      final due = await repo.getDueCards('lang-1', scope: scope);
      expect(due.map((c) => c.termId).toSet(), {'in1', 'in2'});
      expect(await repo.getDueCount('lang-1', scope: scope), 2);
    });

    test('extraTermIds are OR-ed in alongside the text', () async {
      const scope = ReviewScope(textId: 'x1', extraTermIds: ['phrase']);
      final due = await repo.getDueCards('lang-1', scope: scope);
      expect(due.map((c) => c.termId).toSet(), {'in1', 'in2', 'phrase'});
      expect(await repo.getDueCount('lang-1', scope: scope), 3);
    });

    test('extraTermIds alone select exactly those terms', () async {
      const scope = ReviewScope(extraTermIds: ['phrase', 'out']);
      final due = await repo.getDueCards('lang-1', scope: scope);
      expect(due.map((c) => c.termId).toSet(), {'phrase', 'out'});
    });

    test('composes with a status filter', () async {
      await _insertTerm(db, id: 'in3', status: TermStatus.unknown);
      await _insertDueCard(repo, termId: 'in3');
      await indexWord('x1', 'in3');

      const scope = ReviewScope(textId: 'x1', statuses: [TermStatus.unknown]);
      final due = await repo.getDueCards('lang-1', scope: scope);
      expect(due.map((c) => c.termId), ['in3']);
    });

    test('an unindexed text yields nothing', () async {
      expect(
        await repo.getDueCount('lang-1', scope: const ReviewScope(textId: 'x9')),
        0,
      );
    });
  });

  group('includeNotDue', () {
    late Database db;
    late ReviewCardRepositoryImpl repo;

    final past = DateTime.now().toUtc().subtract(const Duration(days: 1));
    final future = DateTime.now().toUtc().add(const Duration(days: 30));

    Future<void> insertCard(String termId, DateTime due) async {
      await _insertTerm(db, id: termId);
      await repo.create(ReviewCardRecord(
        termId: termId,
        cardData: fsrs.Card(cardId: 1, due: due).toMap(),
        nextDue: due,
        createdAt: past,
        updatedAt: past,
      ));
    }

    setUp(() async {
      db = await _openTestDb();
      SharedPreferences.setMockInitialValues({'new_cards_per_day': 1});
      repo = ReviewCardRepositoryImpl(() async => db,
          settings: SettingsService());
    });

    tearDown(() async => db.close());

    test('returns future cards ordered after the due ones', () async {
      await insertCard('later', future);
      await insertCard('now', past);

      final due =
          await repo.getDueCards('lang-1', scope: const ReviewScope(includeNotDue: true));
      expect(due.map((c) => c.termId), ['now', 'later']);
    });

    test('bypasses the daily new-card budget', () async {
      for (final id in ['n1', 'n2', 'n3']) {
        await insertCard(id, future);
      }

      // Budget of 1 would otherwise cap these never-reviewed cards.
      const practice = ReviewScope(includeNotDue: true);
      expect((await repo.getDueCards('lang-1', scope: practice)).length, 3);
      expect(await repo.getDueCount('lang-1', scope: practice), 3);
      // The graded path still enforces it.
      expect(await repo.getDueCount('lang-1'), 0); // none are due yet
    });
  });

  group('getClozeDueCandidates', () {
    late Database db;

    setUp(() async {
      db = await _openTestDb();
    });

    tearDown(() async => db.close());

    Future<void> addSentence(String termId, String text) async {
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert('term_sentences', {
        'id': '$termId-${text.hashCode}',
        'term_id': termId,
        'sentence': text,
        'created_at': now,
        'updated_at': now,
      });
    }

    test('returns only carded terms that have a stored sentence', () async {
      final repo = ReviewCardRepositoryImpl(() async => db);
      await _insertTerm(db, id: 'with');
      await _insertTerm(db, id: 'without');
      await _insertDueCard(repo, termId: 'with');
      await _insertDueCard(repo, termId: 'without');
      await addSentence('with', 'A sentence.');

      final ids = (await repo.getClozeDueCandidates('lang-1'))
          .map((c) => c.termId)
          .toList();
      expect(ids, ['with']);
    });

    test('honours the status scope', () async {
      final repo = ReviewCardRepositoryImpl(() async => db);
      await _insertTerm(db, id: 'k', status: TermStatus.known);
      await _insertTerm(db, id: 'u', status: TermStatus.unknown);
      await _insertDueCard(repo, termId: 'k');
      await _insertDueCard(repo, termId: 'u');
      await addSentence('k', 'K sentence.');
      await addSentence('u', 'U sentence.');

      final ids = (await repo.getClozeDueCandidates('lang-1',
              scope: const ReviewScope(statuses: [TermStatus.known])))
          .map((c) => c.termId)
          .toList();
      expect(ids, ['k']);
    });

    test('is not trimmed by the session card limit', () async {
      SharedPreferences.setMockInitialValues({'session_card_limit': 2});
      final repo = ReviewCardRepositoryImpl(() async => db,
          settings: SettingsService());
      for (var i = 0; i < 6; i++) {
        await _insertTerm(db, id: 't$i');
        await _insertDueCard(repo, termId: 't$i');
        await addSentence('t$i', 'Sentence $i.');
      }
      expect((await repo.getClozeDueCandidates('lang-1')).length, 6);
    });

    test('honours the daily new-card budget', () async {
      SharedPreferences.setMockInitialValues({'new_cards_per_day': 1});
      final repo = ReviewCardRepositoryImpl(() async => db,
          settings: SettingsService());
      for (var i = 0; i < 4; i++) {
        await _insertTerm(db, id: 'n$i');
        await _insertDueCard(repo, termId: 'n$i'); // never reviewed → new
        await addSentence('n$i', 'Sentence $i.');
      }
      expect((await repo.getClozeDueCandidates('lang-1')).length, 1);
    });
  });
}
