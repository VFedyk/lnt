import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/data/datasources/database_migrations.dart' as migrations;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Builds a v21-shaped schema (current onCreate minus the v22 additions) on a
/// real file, seeds orphaned rows, then runs onUpgrade 21 → 22 over it.
/// Guards the migration that must succeed *before* FK enforcement begins:
/// a leftover dangling reference would make its row permanently un-updatable.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('v21 -> v22 upgrade runs and cleans orphans', () async {
    final dir = await Directory.systemTemp.createTemp('lnt_mig');
    final path = '${dir.path}/v21.db';
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 21,
        onCreate: (db, v) async {
          await migrations.onCreate(db, v);
          await db.execute('ALTER TABLE terms DROP COLUMN updated_at');
          await db.execute('ALTER TABLE collections DROP COLUMN updated_at');
          await db.execute('ALTER TABLE languages DROP COLUMN updated_at');
          await db.execute('DROP TABLE sync_tombstones');
          await db.execute('DROP TABLE text_words');
          await db.execute('DROP TABLE text_word_index');
        },
      ),
    );

    await db.insert('languages', {'id': 'l1', 'name': 'English'});
    await db.insert('terms', {
      'id': 't1', 'language_id': 'l1', 'text': 'a', 'lower_text': 'a', 'status': 1,
      'created_at': '2024-01-01T00:00:00.000Z', 'last_accessed': '2024-01-01T00:00:00.000Z',
      'base_term_id': 'gone',
    });
    // Orphan: language_id points nowhere.
    await db.insert('terms', {
      'id': 't2', 'language_id': 'missing', 'text': 'b', 'lower_text': 'b', 'status': 1,
      'created_at': '2024-01-01T00:00:00.000Z', 'last_accessed': '2024-01-01T00:00:00.000Z',
    });
    await db.insert('translations',
        {'id': 'tr1', 'term_id': 'nope', 'meaning': 'x', 'sort_order': 0});
    await db.insert('texts', {
      'id': 'x1', 'language_id': 'l1', 'collection_id': 'gone', 'title': 'T',
      'content': 'c', 'created_at': '2024-01-01T00:00:00.000Z',
      'last_read': '2024-01-01T00:00:00.000Z',
    });

    await db.close();

    final upgraded = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 22,
        onUpgrade: migrations.onUpgrade,
        onOpen: (d) => d.execute('PRAGMA foreign_keys = ON'),
      ),
    );

    expect((await upgraded.query('terms', where: 'id = ?', whereArgs: ['t2'])).length, 0);
    expect((await upgraded.query('translations')).length, 0);
    final t1 = (await upgraded.query('terms', where: 'id = ?', whereArgs: ['t1'])).first;
    expect(t1['base_term_id'], isNull);
    expect(t1['updated_at'], '2024-01-01T00:00:00.000Z');
    final x1 = (await upgraded.query('texts')).first;
    expect(x1['collection_id'], isNull);
    expect((await upgraded.query('sync_tombstones')).length, 0);
    final langs = await upgraded.query('languages');
    expect(langs.first['updated_at'], isNotNull);

    // FK enforcement is live and cascades.
    await upgraded.delete('languages', where: 'id = ?', whereArgs: ['l1']);
    expect((await upgraded.query('terms')).length, 0);
    expect((await upgraded.query('texts')).length, 0);

    await upgraded.close();
    await dir.delete(recursive: true);
  });

  test('v22 -> v23 upgrade creates the text word index and it cascades', () async {
    final dir = await Directory.systemTemp.createTemp('lnt_mig23');
    final path = '${dir.path}/v22.db';
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 22,
        onCreate: (db, v) async {
          await migrations.onCreate(db, v);
          await db.execute('DROP TABLE text_words');
          await db.execute('DROP TABLE text_word_index');
        },
      ),
    );

    await db.insert('languages', {'id': 'l1', 'name': 'English'});
    await db.insert('texts', {
      'id': 'x1', 'language_id': 'l1', 'title': 'T', 'content': 'hello world',
      'created_at': '2024-01-01T00:00:00.000Z',
      'last_read': '2024-01-01T00:00:00.000Z',
    });
    await db.close();

    final upgraded = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 23,
        onUpgrade: migrations.onUpgrade,
        onOpen: (d) => d.execute('PRAGMA foreign_keys = ON'),
      ),
    );

    // Both tables exist and no backfill happened — a fresh upgrade is unindexed.
    expect((await upgraded.query('text_words')).length, 0);
    expect((await upgraded.query('text_word_index')).length, 0);

    final indexes = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
      ['idx_text_words_lower'],
    );
    expect(indexes.length, 1);

    await upgraded.insert('text_words', {
      'text_id': 'x1', 'lower_text': 'hello', 'occurrences': 1,
      'first_position': 0,
    });
    await upgraded.insert('text_word_index', {
      'text_id': 'x1', 'content_hash': 'h', 'word_count': 1,
      'indexed_at': '2024-01-01T00:00:00.000Z',
    });

    await upgraded.delete('texts', where: 'id = ?', whereArgs: ['x1']);
    expect((await upgraded.query('text_words')).length, 0);
    expect((await upgraded.query('text_word_index')).length, 0);

    await upgraded.close();
    await dir.delete(recursive: true);
  });

  // Reproduces the v18 fallout: `ALTER TABLE new_terms RENAME TO terms` ran with
  // FK enforcement off, so children kept `REFERENCES new_terms`. Inert until v22
  // turned enforcement on, after which every review write died with
  // "no such table: main.new_terms".
  test('v23 -> v24 repoints foreign keys left pointing at new_* tables',
      () async {
    final dir = await Directory.systemTemp.createTemp('lnt_mig24');
    final path = '${dir.path}/v23.db';
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 23,
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE languages (id TEXT PRIMARY KEY, name TEXT NOT NULL)
          ''');
          // Exactly the shape v18 leaves behind: a self-reference and child
          // references, all naming the vanished scratch table.
          await db.execute('''
            CREATE TABLE terms (
              id TEXT PRIMARY KEY,
              language_id TEXT NOT NULL,
              lower_text TEXT NOT NULL,
              base_term_id TEXT,
              FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
              FOREIGN KEY (base_term_id) REFERENCES new_terms (id) ON DELETE SET NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_terms_lower ON terms(lower_text)');
          await db.execute('''
            CREATE TABLE review_logs (
              id TEXT PRIMARY KEY,
              term_id TEXT NOT NULL,
              reviewed_at TEXT NOT NULL,
              FOREIGN KEY (term_id) REFERENCES new_terms (id) ON DELETE CASCADE
            )
          ''');
          // A healthy table must be left completely alone.
          await db.execute('''
            CREATE TABLE review_cards (
              id TEXT PRIMARY KEY,
              term_id TEXT NOT NULL,
              FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE CASCADE
            )
          ''');
        },
      ),
    );

    await db.insert('languages', {'id': 'l1', 'name': 'English'});
    await db.insert('terms', {
      'id': 't1', 'language_id': 'l1', 'lower_text': 'alpha',
    });
    await db.insert('review_logs', {
      'id': 'r1', 'term_id': 't1', 'reviewed_at': '2026-01-01T00:00:00.000Z',
    });
    await db.close();

    final upgraded = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 24,
        onUpgrade: migrations.onUpgrade,
        onOpen: (d) => d.execute('PRAGMA foreign_keys = ON'),
      ),
    );

    // No schema anywhere still names a new_* table.
    final schema = await upgraded.rawQuery(
      "SELECT sql FROM sqlite_master WHERE type = 'table' AND sql IS NOT NULL",
    );
    expect(
      schema.any((r) => (r['sql'] as String).contains('new_terms')),
      isFalse,
    );

    // Existing rows survived the rebuild, and indexes came back with them.
    expect((await upgraded.query('review_logs')).length, 1);
    expect((await upgraded.query('terms')).length, 1);
    final indexes = await upgraded.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
      ['idx_terms_lower'],
    );
    expect(indexes.length, 1);

    // The write that used to fail now succeeds under live FK enforcement.
    await upgraded.insert('review_logs', {
      'id': 'r2', 'term_id': 't1', 'reviewed_at': '2026-02-01T00:00:00.000Z',
    });
    expect((await upgraded.query('review_logs')).length, 2);

    // And the repaired FKs really are enforced, in both directions.
    await expectLater(
      upgraded.insert('review_logs', {
        'id': 'r3', 'term_id': 'ghost',
        'reviewed_at': '2026-02-01T00:00:00.000Z',
      }),
      throwsA(isA<DatabaseException>()),
    );
    await upgraded.delete('terms', where: 'id = ?', whereArgs: ['t1']);
    expect((await upgraded.query('review_logs')).length, 0);

    await upgraded.close();
    await dir.delete(recursive: true);
  });

  test('v24 -> v25 adds is_continuous and backfills EPUB collections', () async {
    final dir = await Directory.systemTemp.createTemp('lnt_mig25');
    final path = '${dir.path}/v24.db';
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 24,
        onCreate: (db, v) async {
          await migrations.onCreate(db, v);
          await db.execute('ALTER TABLE collections DROP COLUMN is_continuous');
        },
      ),
    );

    await db.insert('languages', {'id': 'l1', 'name': 'English'});
    // Plain collection: no texts at all.
    await db.insert('collections', {
      'id': 'c-plain', 'language_id': 'l1', 'name': 'Plain',
      'created_at': '2024-01-01T00:00:00.000Z',
    });
    // Collection holding an EPUB-imported text.
    await db.insert('collections', {
      'id': 'c-epub', 'language_id': 'l1', 'name': 'Epub Book',
      'created_at': '2024-01-01T00:00:00.000Z',
    });
    await db.insert('texts', {
      'id': 'x-epub', 'language_id': 'l1', 'collection_id': 'c-epub',
      'title': 'Chapter 1', 'content': 'c', 'source_uri': 'epub://Epub Book',
      'created_at': '2024-01-01T00:00:00.000Z',
      'last_read': '2024-01-01T00:00:00.000Z',
    });
    // Collection holding only a non-EPUB text.
    await db.insert('collections', {
      'id': 'c-other', 'language_id': 'l1', 'name': 'Other',
      'created_at': '2024-01-01T00:00:00.000Z',
    });
    await db.insert('texts', {
      'id': 'x-other', 'language_id': 'l1', 'collection_id': 'c-other',
      'title': 'Text', 'content': 'c', 'source_uri': 'file:///x.txt',
      'created_at': '2024-01-01T00:00:00.000Z',
      'last_read': '2024-01-01T00:00:00.000Z',
    });
    await db.close();

    final upgraded = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 25,
        onUpgrade: migrations.onUpgrade,
        onOpen: (d) => d.execute('PRAGMA foreign_keys = ON'),
      ),
    );

    Future<Map<String, Object?>> collection(String id) async =>
        (await upgraded.query('collections', where: 'id = ?', whereArgs: [id])).first;

    final plain = await collection('c-plain');
    expect(plain['is_continuous'], 0);

    final epub = await collection('c-epub');
    expect(epub['is_continuous'], 1);
    expect(epub['updated_at'], isNotNull);

    final other = await collection('c-other');
    expect(other['is_continuous'], 0);

    await upgraded.close();
    await dir.delete(recursive: true);
  });

  test('v25 -> v26 adds updated_at and backfills legacy sentences', () async {
    final dir = await Directory.systemTemp.createTemp('lnt_mig26');
    final path = '${dir.path}/v25.db';
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 25,
        onCreate: (db, v) async {
          await migrations.onCreate(db, v);
          await db.execute('ALTER TABLE term_sentences DROP COLUMN updated_at');
        },
      ),
    );

    await db.insert('languages', {'id': 'l1', 'name': 'English'});
    await db.insert('terms', {
      'id': 't1', 'language_id': 'l1', 'text': 'a', 'lower_text': 'a', 'status': 1,
      'sentence': 'A cat sat.',
      'created_at': '2024-01-01T00:00:00.000Z',
      'last_accessed': '2024-01-01T00:00:00.000Z',
    });
    // Term with no legacy sentence.
    await db.insert('terms', {
      'id': 't2', 'language_id': 'l1', 'text': 'b', 'lower_text': 'b', 'status': 1,
      'created_at': '2024-01-01T00:00:00.000Z',
      'last_accessed': '2024-01-01T00:00:00.000Z',
    });
    // Pre-existing term_sentences row (no updated_at column yet).
    await db.insert('term_sentences', {
      'id': 's-existing', 'term_id': 't2', 'sentence': 'Existing.',
      'created_at': '2024-02-01T00:00:00.000Z',
    });
    await db.close();

    final upgraded = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 26,
        onUpgrade: migrations.onUpgrade,
        onOpen: (d) => d.execute('PRAGMA foreign_keys = ON'),
      ),
    );

    final cols = await upgraded.rawQuery('PRAGMA table_info(term_sentences)');
    expect(cols.any((c) => c['name'] == 'updated_at'), isTrue);

    final existing = (await upgraded.query('term_sentences',
            where: 'id = ?', whereArgs: ['s-existing']))
        .first;
    expect(existing['updated_at'], '2024-02-01T00:00:00.000Z');

    final backfilled = await upgraded.query('term_sentences',
        where: 'term_id = ?', whereArgs: ['t1']);
    expect(backfilled.length, 1);
    expect(backfilled.first['sentence'], 'A cat sat.');
    expect(backfilled.first['source_text_id'], isNull);
    expect(backfilled.first['created_at'], '2024-01-01T00:00:00.000Z');
    expect(backfilled.first['updated_at'], '2024-01-01T00:00:00.000Z');

    // Re-running the migration inserts nothing more.
    await migrations.onUpgrade(upgraded, 25, 26);
    expect(
      (await upgraded.query('term_sentences', where: 'term_id = ?', whereArgs: ['t1']))
          .length,
      1,
    );

    await upgraded.close();
    await dir.delete(recursive: true);
  });

  test('v25 -> v26 is a no-op when updated_at already exists', () async {
    final dir = await Directory.systemTemp.createTemp('lnt_mig26b');
    final path = '${dir.path}/v25b.db';
    final db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 26,
        onCreate: migrations.onCreate,
      ),
    );
    await db.insert('languages', {'id': 'l1', 'name': 'English'});
    await db.insert('terms', {
      'id': 't1', 'language_id': 'l1', 'text': 'a', 'lower_text': 'a', 'status': 1,
      'sentence': 'A cat sat.',
      'created_at': '2024-01-01T00:00:00.000Z',
      'last_accessed': '2024-01-01T00:00:00.000Z',
    });
    // Migration already backfilled this on the v26 onCreate? No — onCreate does
    // not backfill. Simulate the row already present.
    await db.insert('term_sentences', {
      'id': 's1', 'term_id': 't1', 'sentence': 'A cat sat.',
      'created_at': '2024-01-01T00:00:00.000Z',
      'updated_at': '2024-01-01T00:00:00.000Z',
    });

    await migrations.onUpgrade(db, 25, 26);
    expect((await db.query('term_sentences')).length, 1);

    await db.close();
    await dir.delete(recursive: true);
  });

  // The repair runs for every existing install, so it must be a strict no-op on
  // a database that was never corrupted.
  test('the FK repair leaves a healthy schema byte-identical', () async {
    final db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: migrations.databaseVersion,
        onCreate: migrations.onCreate,
      ),
    );

    Future<List<String>> schema() async => (await db.rawQuery(
          'SELECT name, sql FROM sqlite_master ORDER BY type, name',
        )).map((r) => '${r['name']}|${r['sql']}').toList();

    final before = await schema();
    await migrations.repairStaleRenameForeignKeys(db);
    expect(await schema(), before);

    await db.close();
  });
}
