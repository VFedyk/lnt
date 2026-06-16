import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/data/datasources/database_migrations.dart'
    as migrations;
import 'package:language_nerd_tools/data/repositories/term_status_log_repository_impl.dart';
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('getByTermId', () {
    late Database db;
    late TermStatusLogRepositoryImpl repo;

    setUp(() async {
      db = await _openTestDb();
      repo = TermStatusLogRepositoryImpl(() async => db);
    });

    tearDown(() async => db.close());

    test('returns status changes oldest-first for the term', () async {
      final base = DateTime.utc(2026, 6, 1, 12);
      await repo.logChange('t1', TermStatus.learning2, base.add(const Duration(days: 2)));
      await repo.logChange('t1', TermStatus.unknown, base); // earlier
      await repo.logChange('t2', TermStatus.known, base);

      final history = await repo.getByTermId('t1');
      expect(history.map((e) => e.status), [TermStatus.unknown, TermStatus.learning2]);
      expect(history.first.changedAt, base);
    });

    test('returns empty for a term with no log', () async {
      expect(await repo.getByTermId('nope'), isEmpty);
    });
  });
}
