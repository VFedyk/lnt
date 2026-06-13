import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fsrs/fsrs.dart' as fsrs;
import 'package:language_nerd_tools/data/datasources/database_migrations.dart'
    as migrations;
import 'package:language_nerd_tools/data/repositories/review_card_repository_impl.dart';
import 'package:language_nerd_tools/domain/entities/review_card.dart';
import 'package:language_nerd_tools/domain/events/term_event.dart';
import 'package:language_nerd_tools/domain/value_objects/term_status.dart';
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
    'text': 't',
    'lower_text': 't',
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
}
