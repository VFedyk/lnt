import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:language_nerd_tools/data/datasources/database_migrations.dart'
    as migrations;
import 'package:language_nerd_tools/data/repositories/review_card_repository_impl.dart';
import 'package:language_nerd_tools/domain/entities/review_card.dart';
import 'package:language_nerd_tools/domain/events/term_event.dart';
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
}
