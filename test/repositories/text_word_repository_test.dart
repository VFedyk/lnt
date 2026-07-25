import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/data/datasources/database_migrations.dart'
    as migrations;
import 'package:language_nerd_tools/data/repositories/text_word_repository_impl.dart';
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

Future<void> _insertText(
  Database db, {
  required String id,
  String languageId = 'lang-1',
  String title = 'Title',
  int status = 0,
  String lastRead = '2026-01-01T00:00:00.000Z',
}) async {
  await db.insert('texts', {
    'id': id,
    'language_id': languageId,
    'title': title,
    'content': 'content',
    'created_at': '2026-01-01T00:00:00.000Z',
    'last_read': lastRead,
    'status': status,
  });
}

Future<void> _insertTerm(
  Database db, {
  required String id,
  required String lowerText,
  String languageId = 'lang-1',
}) async {
  const now = '2026-01-01T00:00:00.000Z';
  await db.insert('terms', {
    'id': id,
    'language_id': languageId,
    'text': lowerText,
    'lower_text': lowerText,
    'status': TermStatus.learning2,
    'created_at': now,
    'last_accessed': now,
  });
}

Map<String, ({int occurrences, int firstPosition})> _words(
  Map<String, (int, int)> raw,
) =>
    raw.map((k, v) =>
        MapEntry(k, (occurrences: v.$1, firstPosition: v.$2)));

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late TextWordRepositoryImpl repo;

  setUp(() async {
    db = await _openTestDb();
    repo = TextWordRepositoryImpl(() async => db);
  });

  tearDown(() async => db.close());

  group('replaceIndex / indexedHash / invalidate', () {
    test('stores words and the content hash', () async {
      await _insertText(db, id: 'x1');
      await repo.replaceIndex(
        'x1',
        'hash-1',
        _words({'alpha': (3, 0), 'beta': (1, 12)}),
      );

      final rows = await db.query('text_words', orderBy: 'lower_text');
      expect(rows.map((r) => r['lower_text']), ['alpha', 'beta']);
      expect(rows.first['occurrences'], 3);
      expect(rows.last['first_position'], 12);
      expect(await repo.indexedHash('x1'), 'hash-1');

      final meta = (await db.query('text_word_index')).single;
      expect(meta['word_count'], 2);
    });

    test('fully replaces a previous index rather than merging', () async {
      await _insertText(db, id: 'x1');
      await repo.replaceIndex('x1', 'h1', _words({'gone': (1, 0)}));
      await repo.replaceIndex('x1', 'h2', _words({'kept': (2, 5)}));

      final rows = await db.query('text_words');
      expect(rows.map((r) => r['lower_text']), ['kept']);
      expect(await repo.indexedHash('x1'), 'h2');
      expect((await db.query('text_word_index')).length, 1);
    });

    test('leaves other texts untouched', () async {
      await _insertText(db, id: 'x1');
      await _insertText(db, id: 'x2');
      await repo.replaceIndex('x1', 'h1', _words({'one': (1, 0)}));
      await repo.replaceIndex('x2', 'h2', _words({'two': (1, 0)}));
      await repo.replaceIndex('x1', 'h3', _words({'three': (1, 0)}));

      final x2 = await db.query('text_words',
          where: 'text_id = ?', whereArgs: ['x2']);
      expect(x2.single['lower_text'], 'two');
    });

    test('indexedHash is null for a never-indexed text', () async {
      await _insertText(db, id: 'x1');
      expect(await repo.indexedHash('x1'), isNull);
    });

    test('invalidate drops the meta row but keeps the words', () async {
      await _insertText(db, id: 'x1');
      await repo.replaceIndex('x1', 'h1', _words({'one': (1, 0)}));
      await repo.invalidate('x1');

      expect(await repo.indexedHash('x1'), isNull);
      expect((await db.query('text_words')).length, 1);
    });

    test('an empty word map still records the hash', () async {
      await _insertText(db, id: 'x1');
      await repo.replaceIndex('x1', 'h1', const {});
      expect(await repo.indexedHash('x1'), 'h1');
      expect((await db.query('text_words')).length, 0);
    });
  });

  group('termIdsInText', () {
    test('matches only terms of the given language', () async {
      await _insertText(db, id: 'x1');
      await _insertTerm(db, id: 'same', lowerText: 'alpha');
      await _insertTerm(db, id: 'other', lowerText: 'beta', languageId: 'lang-2');
      await _insertTerm(db, id: 'absent', lowerText: 'gamma');
      await repo.replaceIndex(
        'x1',
        'h1',
        _words({'alpha': (1, 0), 'beta': (1, 6)}),
      );

      expect(await repo.termIdsInText('x1', 'lang-1'), ['same']);
    });

    test('returns empty for an unindexed text', () async {
      await _insertText(db, id: 'x1');
      await _insertTerm(db, id: 't1', lowerText: 'alpha');
      expect(await repo.termIdsInText('x1', 'lang-1'), isEmpty);
    });
  });

  group('textsContainingTerms', () {
    setUp(() async {
      await _insertTerm(db, id: 't1', lowerText: 'alpha');
      await _insertTerm(db, id: 't2', lowerText: 'beta');
      await _insertTerm(db, id: 't3', lowerText: 'gamma');
    });

    test('respects minHits', () async {
      await _insertText(db, id: 'two-hits', title: 'Two');
      await _insertText(db, id: 'one-hit', title: 'One');
      await repo.replaceIndex('two-hits', 'h',
          _words({'alpha': (1, 0), 'beta': (1, 6)}));
      await repo.replaceIndex('one-hit', 'h', _words({'alpha': (1, 0)}));

      final result =
          await repo.textsContainingTerms('lang-1', ['t1', 't2'], minHits: 2);
      expect(result.map((r) => r.textId), ['two-hits']);
      expect(result.single.hits, 2);
      expect(result.single.title, 'Two');
    });

    test('orders read texts before unread ones', () async {
      await _insertText(db, id: 'unread', title: 'Unread', status: 0);
      await _insertText(db, id: 'read', title: 'Read', status: 1);
      final all = _words({'alpha': (1, 0), 'beta': (1, 6), 'gamma': (1, 12)});
      await repo.replaceIndex('unread', 'h', all);
      await repo.replaceIndex('read', 'h', all);

      final result =
          await repo.textsContainingTerms('lang-1', ['t1', 't2', 't3']);
      expect(result.map((r) => r.textId), ['read', 'unread']);
    });

    test('excludes texts in other languages', () async {
      await _insertText(db, id: 'other', languageId: 'lang-2');
      await repo.replaceIndex(
          'other', 'h', _words({'alpha': (1, 0), 'beta': (1, 6)}));

      expect(await repo.textsContainingTerms('lang-1', ['t1', 't2']), isEmpty);
    });

    test('honours limit and returns empty for no term ids', () async {
      for (var i = 0; i < 4; i++) {
        await _insertText(db, id: 'x$i', title: 'T$i');
        await repo.replaceIndex(
            'x$i', 'h', _words({'alpha': (1, 0), 'beta': (1, 6)}));
      }

      final limited =
          await repo.textsContainingTerms('lang-1', ['t1', 't2'], limit: 2);
      expect(limited.length, 2);
      expect(await repo.textsContainingTerms('lang-1', const []), isEmpty);
    });
  });
}
