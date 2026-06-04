import 'package:flutter_test/flutter_test.dart';
import 'package:language_nerd_tools/data/datasources/database_migrations.dart' as migrations;
import 'package:language_nerd_tools/data/services/sync_api.dart';
import 'package:language_nerd_tools/services/sync_image_service.dart';
import 'package:language_nerd_tools/services/sync_pull_service.dart';
import 'package:language_nerd_tools/services/sync_push_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ── DB helpers ────────────────────────────────────────────────────────────────

Future<Database> _openTestDb() async {
  sqfliteFfiInit();
  return await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: migrations.databaseVersion,
      onCreate: migrations.onCreate,
      onUpgrade: migrations.onUpgrade,
    ),
  );
}

// ── SyncPullService — validatePayload ─────────────────────────────────────────

void main() {
  // No image service needed for validate tests (they're pure).
  late SyncPullService pullService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    // The tested domains (language, term, review_log) never call image methods,
    // so the real no-arg const SyncImageService is safe to pass here.
    pullService = SyncPullService(const SyncImageService());
  });

  group('SyncPullService.validatePayload', () {
    test('accepts valid language payload', () {
      expect(pullService.validatePayload('language', {'name': 'English'}), isTrue);
    });

    test('rejects language payload missing name', () {
      expect(pullService.validatePayload('language', {}), isFalse);
    });

    test('accepts valid collection payload', () {
      expect(pullService.validatePayload('collection', {'language_id': 'en'}), isTrue);
    });

    test('rejects collection payload missing language_id', () {
      expect(pullService.validatePayload('collection', {}), isFalse);
    });

    test('accepts valid text payload', () {
      expect(pullService.validatePayload('text', {'language_id': 'en', 'collection_id': 'c1'}),
          isTrue);
    });

    test('rejects text payload missing collection_id', () {
      expect(pullService.validatePayload('text', {'language_id': 'en'}), isFalse);
    });

    test('accepts valid term payload', () {
      expect(pullService.validatePayload('term', {'language_id': 'en', 'text': 'hello'}), isTrue);
    });

    test('rejects term payload missing text', () {
      expect(pullService.validatePayload('term', {'language_id': 'en'}), isFalse);
    });

    test('accepts valid review_log payload', () {
      expect(
          pullService.validatePayload(
              'review_log', {'term_id': 't1', 'reviewed_at': '2024-01-01T00:00:00Z'}),
          isTrue);
    });

    test('accepts valid term_status_log payload', () {
      expect(
          pullService.validatePayload('term_status_log',
              {'term_id': 't1', 'status': 1, 'changed_at': '2024-01-01T00:00:00Z'}),
          isTrue);
    });

    test('unknown domain passes through', () {
      expect(pullService.validatePayload('future_domain', {}), isTrue);
    });
  });

  // ── SyncPullService.applyEvent ─────────────────────────────────────────────

  group('SyncPullService.applyEvent — language (LWW)', () {
    late Database db;

    setUp(() async { db = await _openTestDb(); });
    tearDown(() async { await db.close(); });

    test('inserts language row', () async {
      await pullService.applyEvent(
        db,
        _makeEvent('language', 'lang-1', {'name': 'English', 'language_code': 'en'}),
        _noOpApi(), 'user1', {},
      );
      final rows = await db.query('languages', where: 'id = ?', whereArgs: ['lang-1']);
      expect(rows.length, 1);
      expect(rows.first['name'], 'English');
    });

    test('replaces language row on re-apply (LWW)', () async {
      await pullService.applyEvent(
        db,
        _makeEvent('language', 'lang-1', {'name': 'Old', 'language_code': 'en'}),
        _noOpApi(), 'user1', {},
      );
      await pullService.applyEvent(
        db,
        _makeEvent('language', 'lang-1', {'name': 'New', 'language_code': 'en'}),
        _noOpApi(), 'user1', {},
      );
      final rows = await db.query('languages', where: 'id = ?', whereArgs: ['lang-1']);
      expect(rows.length, 1);
      expect(rows.first['name'], 'New');
    });
  });

  group('SyncPullService.applyEvent — review_log (ignore duplicate)', () {
    late Database db;

    setUp(() async { db = await _openTestDb(); });
    tearDown(() async { await db.close(); });

    test('ignores duplicate review_log', () async {
      // Insert a language and term first (FK constraints).
      await db.insert('languages', {'id': 'lang-1', 'name': 'English', 'language_code': 'en'});
      await db.insert('terms', {'id': 'term-1', 'language_id': 'lang-1',
          'text': 'hello', 'lower_text': 'hello', 'status': 1,
          'created_at': '2024-01-01T00:00:00.000Z',
          'last_accessed': '2024-01-01T00:00:00.000Z'});

      final payload = {
        'term_id': 'term-1',
        'log_data': '{}',
        'reviewed_at': '2024-01-01T00:00:00Z',
      };

      await pullService.applyEvent(
          db, _makeEvent('review_log', 'log-1', payload), _noOpApi(), 'u', {});
      await pullService.applyEvent(
          db, _makeEvent('review_log', 'log-1', payload), _noOpApi(), 'u', {});

      final rows = await db.query('review_logs', where: 'id = ?', whereArgs: ['log-1']);
      expect(rows.length, 1);
    });
  });

  group('SyncPullService.applyEvent — term (atomic term+translations)', () {
    late Database db;

    setUp(() async { db = await _openTestDb(); });
    tearDown(() async { await db.close(); });

    test('inserts term with translations atomically', () async {
      await db.insert('languages', {'id': 'lang-1', 'name': 'English', 'language_code': 'en'});

      await pullService.applyEvent(
        db,
        _makeEvent('term', 'term-1', {
          'language_id': 'lang-1',
          'text': 'hello',
          'lower_text': 'hello',
          'status': 1,
          'created_at': '2024-01-01T00:00:00.000Z',
          'last_accessed': '2024-01-01T00:00:00.000Z',
          'translations': [
            {'id': 'tr-1', 'term_id': 'term-1', 'meaning': 'greeting', 'sort_order': 0},
          ],
        }),
        _noOpApi(), 'u', {},
      );

      final terms = await db.query('terms', where: 'id = ?', whereArgs: ['term-1']);
      expect(terms.length, 1);
      final translations =
          await db.query('translations', where: 'term_id = ?', whereArgs: ['term-1']);
      expect(translations.length, 1);
      expect(translations.first['meaning'], 'greeting');
    });

    test('replaces translations on re-apply', () async {
      await db.insert('languages', {'id': 'lang-1', 'name': 'English', 'language_code': 'en'});

      final base = {
        'language_id': 'lang-1', 'text': 'hello', 'lower_text': 'hello',
        'status': 1, 'created_at': '2024-01-01T00:00:00.000Z',
        'last_accessed': '2024-01-01T00:00:00.000Z',
      };

      await pullService.applyEvent(db,
          _makeEvent('term', 'term-1', {
            ...base,
            'translations': [
              {'id': 'tr-old', 'term_id': 'term-1', 'meaning': 'old meaning', 'sort_order': 0},
            ],
          }),
          _noOpApi(), 'u', {});

      await pullService.applyEvent(db,
          _makeEvent('term', 'term-1', {
            ...base,
            'translations': [
              {'id': 'tr-new', 'term_id': 'term-1', 'meaning': 'new meaning', 'sort_order': 0},
            ],
          }),
          _noOpApi(), 'u', {});

      final translations =
          await db.query('translations', where: 'term_id = ?', whereArgs: ['term-1']);
      expect(translations.length, 1);
      expect(translations.first['meaning'], 'new meaning');
    });
  });

  // ── SyncPushService collectors ────────────────────────────────────────────

  group('SyncPushService.collectLanguages', () {
    late Database db;
    final push = SyncPushService();

    setUp(() async { db = await _openTestDb(); });
    tearDown(() async { await db.close(); });

    test('collects all languages when sinceStr is null', () async {
      await db.insert('languages', {'id': 'lang-1', 'name': 'English', 'language_code': 'en'});

      final events = <EventInput>[];
      await push.collectLanguages(db, events);

      expect(events.length, 1);
      expect(events.first.domain, 'language');
      expect(events.first.entityId, 'lang-1');
    });
  });

  group('SyncPushService.collectReviewLogs — time window', () {
    late Database db;
    final push = SyncPushService();

    setUp(() async { db = await _openTestDb(); });
    tearDown(() async { await db.close(); });

    test('filters review logs by since timestamp', () async {
      await db.insert('languages', {'id': 'lang-1', 'name': 'English', 'language_code': 'en'});
      await db.insert('terms', {'id': 'term-1', 'language_id': 'lang-1',
          'text': 'hello', 'lower_text': 'hello', 'status': 1,
          'created_at': '2024-01-01T00:00:00.000Z',
          'last_accessed': '2024-01-01T00:00:00.000Z'});

      await db.insert('review_logs', {'id': 'log-old', 'term_id': 'term-1',
          'log_data': '{}', 'reviewed_at': '2023-01-01T00:00:00.000Z'});
      await db.insert('review_logs', {'id': 'log-new', 'term_id': 'term-1',
          'log_data': '{}', 'reviewed_at': '2025-01-01T00:00:00.000Z'});

      final events = <EventInput>[];
      await push.collectReviewLogs(db, events, '2024-01-01T00:00:00.000Z');

      expect(events.length, 1);
      expect(events.first.entityId, 'log-new');
    });
  });
}

// ── Helpers ───────────────────────────────────────────────────────────────────

RemoteSyncEvent _makeEvent(String domain, String entityId, Map<String, dynamic> payload) =>
    RemoteSyncEvent(
      seq: 1,
      domain: domain,
      entityId: entityId,
      payload: payload,
      clientTs: DateTime.utc(2024),
      serverTs: DateTime.utc(2024),
    );

/// Real SyncApi pointed at an unreachable URL. Tests that call applyEvent for
/// language/term/review_log domains never trigger network calls, so this is safe.
SyncApi _noOpApi() => SyncApi('http://localhost:0');
