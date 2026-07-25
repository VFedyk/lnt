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
}
