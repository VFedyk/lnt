import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/data/datasources/database_migrations.dart'
    as migrations;
import 'package:language_nerd_tools/data/repositories/review_log_repository_impl.dart';
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
  String languageId = 'lang-1',
}) async {
  final now = DateTime.now().toUtc().toIso8601String();
  await db.insert('terms', {
    'id': id,
    'language_id': languageId,
    'text': id,
    'lower_text': id,
    'status': TermStatus.known,
    'created_at': now,
    'last_accessed': now,
  });
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('getRetention', () {
    late Database db;
    late ReviewLogRepositoryImpl repo;

    setUp(() async {
      db = await _openTestDb();
      repo = ReviewLogRepositoryImpl(() async => db);
    });

    tearDown(() async => db.close());

    Future<void> log(String termId, int rating, DateTime at) async {
      await repo.create(
        termId,
        jsonEncode({
          'cardId': 1,
          'rating': rating,
          'reviewDateTime': at.toIso8601String(),
          'reviewDuration': null,
        }),
        at,
      );
    }

    test('counts non-again reviews as recalled', () async {
      await _insertTerm(db, id: 't1');
      final now = DateTime.now().toUtc();
      await log('t1', 1, now); // again — a lapse
      await log('t1', 2, now); // hard
      await log('t1', 3, now); // good
      await log('t1', 4, now); // easy

      final r = await repo.getRetention('lang-1');
      expect(r.total, 4);
      expect(r.recalled, 3);
    });

    test('excludes reviews outside the window', () async {
      await _insertTerm(db, id: 't1');
      final old = DateTime.now().toUtc().subtract(const Duration(days: 60));
      await log('t1', 3, old);

      final r = await repo.getRetention('lang-1', days: 30);
      expect(r.total, 0);
    });

    test('returns zero totals when there are no reviews', () async {
      final r = await repo.getRetention('lang-1');
      expect(r.total, 0);
      expect(r.recalled, 0);
    });
  });

  group('getByTermId', () {
    late Database db;
    late ReviewLogRepositoryImpl repo;

    setUp(() async {
      db = await _openTestDb();
      repo = ReviewLogRepositoryImpl(() async => db);
    });

    tearDown(() async => db.close());

    test('returns parsed reviews oldest-first for the term only', () async {
      await _insertTerm(db, id: 't1');
      await _insertTerm(db, id: 't2');
      final base = DateTime.utc(2026, 6, 1, 12);
      await repo.create(
        't1',
        jsonEncode({'cardId': 1, 'rating': 3, 'reviewDuration': 1500}),
        base.add(const Duration(days: 1)),
      );
      await repo.create(
        't1',
        jsonEncode({'cardId': 1, 'rating': 1, 'reviewDuration': null}),
        base, // earlier — should sort first
      );
      await repo.create(
        't2',
        jsonEncode({'cardId': 2, 'rating': 4, 'reviewDuration': null}),
        base,
      );

      final history = await repo.getByTermId('t1');
      expect(history.map((e) => e.rating), [1, 3]); // oldest-first
      expect(history.first.reviewedAt, base);
      expect(history.last.durationMs, 1500);
    });

    test('returns empty for a term with no reviews', () async {
      await _insertTerm(db, id: 't1');
      expect(await repo.getByTermId('t1'), isEmpty);
    });
  });
}
