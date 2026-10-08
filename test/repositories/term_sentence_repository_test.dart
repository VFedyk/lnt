import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/data/datasources/database_migrations.dart'
    as migrations;
import 'package:language_nerd_tools/data/repositories/term_sentence_repository_impl.dart';
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

  late Database db;
  late TermSentenceRepositoryImpl repo;

  setUp(() async {
    db = await _openTestDb();
    repo = TermSentenceRepositoryImpl(() async => db);
    await db.insert('languages', {'id': 'l1', 'name': 'English'});
    await db.insert('terms', {
      'id': 't1', 'language_id': 'l1', 'text': 'a', 'lower_text': 'a', 'status': 1,
      'created_at': '2024-01-01T00:00:00.000Z',
      'last_accessed': '2024-01-01T00:00:00.000Z',
    });
    await db.insert('terms', {
      'id': 't2', 'language_id': 'l1', 'text': 'b', 'lower_text': 'b', 'status': 1,
      'created_at': '2024-01-01T00:00:00.000Z',
      'last_accessed': '2024-01-01T00:00:00.000Z',
    });
  });

  tearDown(() async => db.close());

  test('create stamps created_at and updated_at', () async {
    final s = await repo.create('t1', 'A cat sat.');
    final row = (await db.query('term_sentences', where: 'id = ?', whereArgs: [s.id]))
        .first;
    expect(row['sentence'], 'A cat sat.');
    expect(row['created_at'], isNotNull);
    expect(row['updated_at'], isNotNull);
    expect(row['updated_at'], row['created_at']);
  });

  test('update changes sentence and bumps updated_at', () async {
    final s = await repo.create('t1', 'Old.');
    final before = (await db.query('term_sentences', where: 'id = ?', whereArgs: [s.id]))
        .first['updated_at'] as String;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await repo.update(s.id!, 'New.');
    final row = (await db.query('term_sentences', where: 'id = ?', whereArgs: [s.id]))
        .first;
    expect(row['sentence'], 'New.');
    expect(DateTime.parse(row['updated_at'] as String).isAfter(DateTime.parse(before)),
        isTrue);
  });

  test('delete records a tombstone', () async {
    final s = await repo.create('t1', 'Bye.');
    await repo.delete(s.id!);
    final tomb = await db.query('sync_tombstones',
        where: 'domain = ? AND entity_id = ?', whereArgs: ['term_sentence', s.id]);
    expect(tomb.length, 1);
  });

  test('delete of a missing id records no tombstone', () async {
    await repo.delete('ghost');
    expect(await db.query('sync_tombstones'), isEmpty);
  });

  test('getByTermIds groups sentences by term', () async {
    await repo.create('t1', 'One.');
    await repo.create('t1', 'Two.');
    await repo.create('t2', 'Three.');
    final grouped = await repo.getByTermIds(['t1', 't2']);
    expect(grouped['t1'], ['One.', 'Two.']);
    expect(grouped['t2'], ['Three.']);
  });

  test('existsForTerm is case- and whitespace-insensitive, scoped to term',
      () async {
    await repo.create('t1', 'A Cat Sat.');

    expect(await repo.existsForTerm('t1', '  a cat sat.  '), isTrue);
    expect(await repo.existsForTerm('t1', 'A CAT SAT.'), isTrue);
    expect(await repo.existsForTerm('t1', 'A dog sat.'), isFalse);
    expect(await repo.existsForTerm('t2', 'A Cat Sat.'), isFalse);
  });

  test('getByTermId returns full entities oldest-first', () async {
    await repo.create('t1', 'One.');
    await repo.create('t1', 'Two.');
    final rows = await repo.getByTermId('t1');
    expect(rows.map((r) => r.sentence), ['One.', 'Two.']);
    expect(rows.first.updatedAt, isNotNull);
  });

  group('getCountsByTermIds', () {
    test('counts per term and omits terms without sentences', () async {
      await repo.create('t1', 'One.');
      await repo.create('t1', 'Two.');
      await repo.create('t1', 'Three.');
      final counts = await repo.getCountsByTermIds(['t1', 't2']);
      expect(counts, {'t1': 3});
    });

    test('empty input returns an empty map', () async {
      expect(await repo.getCountsByTermIds([]), isEmpty);
    });

    test('handles more ids than SQLite host parameters (chunking)', () async {
      final ids = <String>[];
      final batch = db.batch();
      for (var i = 0; i < 600; i++) {
        final id = 'bulk$i';
        ids.add(id);
        batch.insert('terms', {
          'id': id, 'language_id': 'l1', 'text': id, 'lower_text': id,
          'status': 1,
          'created_at': '2024-01-01T00:00:00.000Z',
          'last_accessed': '2024-01-01T00:00:00.000Z',
        });
      }
      await batch.commit(noResult: true);
      await repo.create('bulk0', 'First.');
      await repo.create('bulk599', 'Last A.');
      await repo.create('bulk599', 'Last B.');

      final counts = await repo.getCountsByTermIds(ids);
      expect(counts, {'bulk0': 1, 'bulk599': 2});
    });
  });
}
