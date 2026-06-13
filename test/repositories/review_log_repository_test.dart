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
    'text': 't',
    'lower_text': 't',
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
}
