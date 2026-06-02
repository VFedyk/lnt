import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../data/datasources/database_service.dart';
import '../data/notifiers/data_change_notifier.dart';
import '../data/services/sync_api.dart';
import 'settings_service.dart';

const _batchSize = 200;

class SyncService {
  final DatabaseService _db;
  final SettingsService _settings;
  final DataChangeNotifier _changes;

  SyncService({
    required DatabaseService db,
    required SettingsService settings,
    required DataChangeNotifier changes,
  })  : _db = db,
        _settings = settings,
        _changes = changes;

  SyncApi _api(String serverUrl) => SyncApi(serverUrl);

  /// Full sync: pull new events from server, then push new local data.
  Future<void> sync() async {
    final serverUrl = await _settings.getSyncServerUrl();
    final nickname = await _settings.getSyncNickname();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('Sync server URL is not configured');
    }
    if (nickname == null || nickname.isEmpty) {
      throw Exception('Sync nickname is not configured');
    }

    final api = _api(serverUrl);

    // Resolve nickname → userId (cached in settings)
    final userId = await _resolveUserId(api, nickname);
    final deviceId = await _settings.getSyncDeviceId();

    // Pull first so we have the latest server state before pushing
    final lastPulledSeq = await _settings.getSyncLastPulledSeq();
    await _pull(api, userId, lastPulledSeq);

    // Push local data that isn't on the server yet
    final lastPushedAt = await _settings.getSyncLastPushedAt();
    await _push(api, userId, deviceId, lastPushedAt);
    await _settings.setSyncLastPushedAt(DateTime.now().toUtc());
  }

  Future<String> _resolveUserId(SyncApi api, String nickname) async {
    var cached = await _settings.getSyncUserId();
    if (cached != null && cached.isNotEmpty) return cached;
    final userId = await api.resolveUser(nickname);
    await _settings.setSyncUserId(userId);
    return userId;
  }

  Future<void> _pull(SyncApi api, String userId, int since) async {
    final response = await api.pullEvents(userId, since: since);
    if (response.events.isEmpty) return;

    final rawDb = await _db.database;
    for (final event in response.events) {
      await _applyEvent(rawDb, event);
    }

    await _settings.setSyncLastPulledSeq(response.latestSeq);
    _changes.notifyAll();
  }

  Future<void> _applyEvent(Database rawDb, RemoteSyncEvent event) async {
    final p = event.payload;
    switch (event.domain) {
      case 'language':
        await rawDb.insert(
          'languages',
          _withId(p, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      case 'collection':
        await rawDb.insert(
          'collections',
          _withId(p, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      case 'text':
        await rawDb.insert(
          'texts',
          _withId(p, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      case 'term':
        final translations = p['translations'] as List<dynamic>?;
        final termRow = Map<String, dynamic>.from(p)..remove('translations');
        await rawDb.insert(
          'terms',
          _withId(termRow, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        if (translations != null) {
          await rawDb.delete(
            'translations',
            where: 'term_id = ?',
            whereArgs: [event.entityId],
          );
          for (final t in translations) {
            await rawDb.insert(
              'translations',
              Map<String, dynamic>.from(t as Map),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      case 'review_log':
        await rawDb.insert(
          'review_logs',
          _withId(p, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      case 'term_status_log':
        await rawDb.insert(
          'term_status_log',
          _withId(p, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
    }
  }

  Map<String, dynamic> _withId(Map<String, dynamic> map, String id) {
    return {...map, 'id': id};
  }

  Future<void> _push(
    SyncApi api,
    String userId,
    String deviceId,
    DateTime? lastPushedAt,
  ) async {
    final rawDb = await _db.database;
    final sinceStr = lastPushedAt?.toIso8601String();
    final events = <EventInput>[];

    await _collectLanguages(rawDb, events);
    await _collectCollections(rawDb, events, sinceStr);
    await _collectTexts(rawDb, events, sinceStr);
    await _collectTerms(rawDb, events, sinceStr);
    await _collectReviewLogs(rawDb, events, sinceStr);
    await _collectStatusLogs(rawDb, events, sinceStr);

    if (events.isEmpty) return;

    for (int i = 0; i < events.length; i += _batchSize) {
      final batch = events.sublist(i, min(i + _batchSize, events.length));
      await api.pushEvents(userId, deviceId, batch);
    }
  }

  Future<void> _collectLanguages(
    Database rawDb,
    List<EventInput> events,
  ) async {
    // Languages have no created_at — always push all (usually just a handful)
    final rows = await rawDb.query('languages');
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      events.add(EventInput(
        domain: 'language',
        entityId: id,
        payload: Map<String, dynamic>.from(row),
        clientTs: DateTime.now().toUtc(),
      ));
    }
  }

  Future<void> _collectCollections(
    Database rawDb,
    List<EventInput> events,
    String? sinceStr,
  ) async {
    final rows = sinceStr != null
        ? await rawDb.query('collections', where: 'created_at > ?', whereArgs: [sinceStr])
        : await rawDb.query('collections');
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      final payload = Map<String, dynamic>.from(row)..remove('cover_image');
      events.add(EventInput(
        domain: 'collection',
        entityId: id,
        payload: payload,
        clientTs: DateTime.parse(row['created_at'] as String).toUtc(),
      ));
    }
  }

  Future<void> _collectTexts(
    Database rawDb,
    List<EventInput> events,
    String? sinceStr,
  ) async {
    final rows = sinceStr != null
        ? await rawDb.query('texts', where: 'created_at > ?', whereArgs: [sinceStr])
        : await rawDb.query('texts');
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      final payload = Map<String, dynamic>.from(row)..remove('cover_image');
      events.add(EventInput(
        domain: 'text',
        entityId: id,
        payload: payload,
        clientTs: DateTime.parse(row['created_at'] as String).toUtc(),
      ));
    }
  }

  Future<void> _collectTerms(
    Database rawDb,
    List<EventInput> events,
    String? sinceStr,
  ) async {
    final rows = sinceStr != null
        ? await rawDb.query('terms', where: 'created_at > ?', whereArgs: [sinceStr])
        : await rawDb.query('terms');
    if (rows.isEmpty) return;

    final termIds = rows.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(termIds.length, '?').join(',');
    final translations = await rawDb.rawQuery(
      'SELECT * FROM translations WHERE term_id IN ($placeholders)',
      termIds,
    );
    final byTermId = <String, List<Map<String, Object?>>>{};
    for (final t in translations) {
      (byTermId[t['term_id'] as String] ??= []).add(t);
    }

    for (final row in rows) {
      final id = row['id'] as String;
      final payload = Map<String, dynamic>.from(row);
      payload['translations'] = byTermId[id] ?? [];
      events.add(EventInput(
        domain: 'term',
        entityId: id,
        payload: payload,
        clientTs: DateTime.parse(row['created_at'] as String).toUtc(),
      ));
    }
  }

  Future<void> _collectReviewLogs(
    Database rawDb,
    List<EventInput> events,
    String? sinceStr,
  ) async {
    final rows = sinceStr != null
        ? await rawDb.query('review_logs', where: 'reviewed_at > ?', whereArgs: [sinceStr])
        : await rawDb.query('review_logs');
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue; // legacy rows without UUID
      events.add(EventInput(
        domain: 'review_log',
        entityId: id,
        payload: Map<String, dynamic>.from(row),
        clientTs: DateTime.parse(row['reviewed_at'] as String).toUtc(),
      ));
    }
  }

  Future<void> _collectStatusLogs(
    Database rawDb,
    List<EventInput> events,
    String? sinceStr,
  ) async {
    final rows = sinceStr != null
        ? await rawDb.query('term_status_log', where: 'changed_at > ?', whereArgs: [sinceStr])
        : await rawDb.query('term_status_log');
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue; // legacy rows without UUID
      events.add(EventInput(
        domain: 'term_status_log',
        entityId: id,
        payload: Map<String, dynamic>.from(row),
        clientTs: DateTime.parse(row['changed_at'] as String).toUtc(),
      ));
    }
  }
}
