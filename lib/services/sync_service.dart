import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/datasources/database_service.dart';
import '../data/notifiers/data_change_notifier.dart';
import '../data/services/sync_api.dart';
import 'settings_service.dart';

const _batchSize = 200;
const _uuid = Uuid();

typedef SyncProgressCallback = void Function(double progress, String status);

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
  Future<void> sync({SyncProgressCallback? onProgress}) async {
    final serverUrl = await _settings.getSyncServerUrl();
    final nickname = await _settings.getSyncNickname();
    if (serverUrl == null || serverUrl.isEmpty) {
      throw Exception('Sync server URL is not configured');
    }
    if (nickname == null || nickname.isEmpty) {
      throw Exception('Sync nickname is not configured');
    }

    _report(onProgress, 0.00, 'Connecting…');

    final api = _api(serverUrl);

    final userId = await _resolveUserId(api, nickname);
    final deviceId = await _settings.getSyncDeviceId();

    final lastPulledSeq = await _settings.getSyncLastPulledSeq();
    await _pull(api, userId, lastPulledSeq, onProgress);

    final lastPushedAt = await _settings.getSyncLastPushedAt();
    await _push(api, userId, deviceId, lastPushedAt, onProgress);
    await _settings.setSyncLastPushedAt(DateTime.now().toUtc());
  }

  Future<String> _resolveUserId(SyncApi api, String nickname) async {
    var cached = await _settings.getSyncUserId();
    if (cached != null && cached.isNotEmpty) return cached;
    final userId = await api.resolveUser(nickname);
    await _settings.setSyncUserId(userId);
    return userId;
  }

  // ── Pull ─────────────────────────────────────────────────────────────────

  Future<void> _pull(
    SyncApi api,
    String userId,
    int since,
    SyncProgressCallback? onProgress,
  ) async {
    _report(onProgress, 0.10, 'Pulling events…');
    final response = await api.pullEvents(userId, since: since);
    if (response.events.isEmpty) return;

    final total = response.events.length;
    _report(onProgress, 0.20, 'Applying $total events…');

    final rawDb = await _db.database;
    for (final event in response.events) {
      await _applyEvent(rawDb, event, api, userId);
    }

    await _settings.setSyncLastPulledSeq(response.latestSeq);
    _changes.notifyAll();
  }

  Future<void> _applyEvent(
    Database rawDb,
    RemoteSyncEvent event,
    SyncApi api,
    String userId,
  ) async {
    final payload = event.payload;
    switch (event.domain) {
      case 'language':
        await rawDb.insert(
          'languages',
          _withId(payload, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      case 'collection':
        final row = Map<String, dynamic>.from(payload)
          ..remove('cover_image')
          ..remove('cover_image_id')
          ..['id'] = event.entityId;
        row['cover_image_id'] = await _resolveCoverImageId(
          rawDb, api, userId,
          ref: payload['cover_image'] as String?,
          table: 'collections',
          entityId: event.entityId,
        );
        await rawDb.insert('collections', row, conflictAlgorithm: ConflictAlgorithm.replace);
      case 'text':
        final row = Map<String, dynamic>.from(payload)
          ..remove('cover_image')
          ..remove('cover_image_id')
          ..['id'] = event.entityId;
        row['cover_image_id'] = await _resolveCoverImageId(
          rawDb, api, userId,
          ref: payload['cover_image'] as String?,
          table: 'texts',
          entityId: event.entityId,
        );
        await rawDb.insert('texts', row, conflictAlgorithm: ConflictAlgorithm.replace);
      case 'term':
        final translations = payload['translations'] as List<dynamic>?;
        final termRow = Map<String, dynamic>.from(payload)..remove('translations');
        await rawDb.insert(
          'terms',
          _withId(termRow, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        if (translations != null) {
          await rawDb.delete('translations', where: 'term_id = ?', whereArgs: [event.entityId]);
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
          _withId(payload, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      case 'term_status_log':
        await rawDb.insert(
          'term_status_log',
          _withId(payload, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
    }
  }

  /// Returns the cover_image_id to store on a pulled entity row.
  ///
  /// Priority:
  /// 1. If [ref] is a valid image ref, download and register it → use that ID.
  /// 2. Otherwise (no ref or download failed) fall back to the existing local
  ///    cover_image_id so we don't erase a cover the user already has.
  Future<String?> _resolveCoverImageId(
    Database rawDb,
    SyncApi api,
    String userId, {
    required String? ref,
    required String table,
    required String entityId,
  }) async {
    if (ref != null && _isImageRef(ref)) {
      final id = await _downloadAndRegisterCoverImage(rawDb, api, userId, ref);
      if (id != null) return id;
    }
    // Fall back to whatever the local row currently has.
    final existing = await rawDb.query(
      table,
      columns: ['cover_image_id'],
      where: 'id = ?',
      whereArgs: [entityId],
    );
    return existing.isNotEmpty ? existing.first['cover_image_id'] as String? : null;
  }

  /// Downloads image for [ref], saves to disk, inserts into cover_images table.
  /// Returns the cover_images.id for use as a FK.
  Future<String?> _downloadAndRegisterCoverImage(
    Database rawDb,
    SyncApi api,
    String userId,
    String ref,
  ) async {
    final localPath = await _downloadCoverImage(api, userId, ref);
    if (localPath == null) return null;
    return _getOrCreateCoverImage(rawDb, localPath, syncHash: ref);
  }

  // ── Push ─────────────────────────────────────────────────────────────────

  Future<void> _push(
    SyncApi api,
    String userId,
    String deviceId,
    DateTime? lastPushedAt,
    SyncProgressCallback? onProgress,
  ) async {
    final rawDb = await _db.database;
    final sinceStr = lastPushedAt?.toIso8601String();
    final events = <EventInput>[];

    _report(onProgress, 0.40, 'Uploading images…');
    final coverRefs = await _syncCoverImages(api, userId, rawDb);

    await _collectLanguages(rawDb, events);
    await _collectCollections(rawDb, events, sinceStr, coverRefs);
    await _collectTexts(rawDb, events, sinceStr, coverRefs);
    await _collectTerms(rawDb, events, sinceStr);
    await _collectReviewLogs(rawDb, events, sinceStr);
    await _collectStatusLogs(rawDb, events, sinceStr);

    if (events.isEmpty) return;

    final totalBatches = (events.length / _batchSize).ceil();
    _report(onProgress, 0.55, 'Pushing ${events.length} events…');

    for (int i = 0; i < events.length; i += _batchSize) {
      final batchIndex = i ~/ _batchSize + 1;
      final batch = events.sublist(i, min(i + _batchSize, events.length));
      await api.pushEvents(userId, deviceId, batch);
      _report(
        onProgress,
        0.55 + (batchIndex / totalBatches) * 0.45,
        'Pushing events ($batchIndex/$totalBatches)…',
      );
    }
  }

  /// Uploads all cover images whose sync_hash is not yet set.
  /// Returns a map of cover_images.id → sync_hash ref for use in event payloads.
  Future<Map<String, String>> _syncCoverImages(
    SyncApi api,
    String userId,
    Database rawDb,
  ) async {
    final allRows = await rawDb.query('cover_images');
    final idToRef = <String, String>{};

    // Pre-populate already-uploaded entries
    for (final row in allRows) {
      final syncHash = row['sync_hash'] as String?;
      if (syncHash != null) idToRef[row['id'] as String] = syncHash;
    }

    final unsynced = allRows.where((r) => r['sync_hash'] == null).toList();
    if (unsynced.isEmpty) return idToRef;

    // Read bytes and compute hashes for unsynced images
    final idToHash = <String, String>{};   // cover_images.id → sha256 hex
    final idToRef2 = <String, String>{};   // cover_images.id → "hash.ext"
    final hashToBytes = <String, List<int>>{};

    for (final row in unsynced) {
      final id = row['id'] as String;
      final localPath = row['local_path'] as String;
      final absPath = await _resolveLocalPath(localPath);
      final file = File(absPath);
      if (!file.existsSync()) continue;

      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      final ext = p.extension(localPath).toLowerCase();
      final ref = '$hash$ext';

      idToHash[id] = hash;
      idToRef2[id] = ref;
      hashToBytes[hash] = bytes;
    }

    if (hashToBytes.isEmpty) return idToRef;

    // Batch-check and upload missing images
    final missing = await api.checkImages(userId, hashToBytes.keys.toList());
    for (final hash in missing) {
      await api.uploadImage(userId, hash, hashToBytes[hash]!);
    }

    // Persist sync_hash and update return map
    for (final entry in idToRef2.entries) {
      await rawDb.update(
        'cover_images',
        {'sync_hash': entry.value},
        where: 'id = ?',
        whereArgs: [entry.key],
      );
      idToRef[entry.key] = entry.value;
    }

    return idToRef;
  }

  Future<void> _collectLanguages(
    Database rawDb,
    List<EventInput> events,
  ) async {
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
    Map<String, String> coverRefs,
  ) async {
    final rows = sinceStr != null
        ? await rawDb.query('collections', where: 'created_at > ?', whereArgs: [sinceStr])
        : await rawDb.query('collections');
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      final payload = Map<String, dynamic>.from(row)..remove('cover_image_id');
      payload['cover_image'] = coverRefs[row['cover_image_id']];
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
    Map<String, String> coverRefs,
  ) async {
    final rows = sinceStr != null
        ? await rawDb.query(
            'texts',
            where: 'COALESCE(updated_at, created_at) > ?',
            whereArgs: [sinceStr],
          )
        : await rawDb.query('texts');
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      final payload = Map<String, dynamic>.from(row)..remove('cover_image_id');
      payload['cover_image'] = coverRefs[row['cover_image_id']];
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
      if (id == null) continue;
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
      if (id == null) continue;
      events.add(EventInput(
        domain: 'term_status_log',
        entityId: id,
        payload: Map<String, dynamic>.from(row),
        clientTs: DateTime.parse(row['changed_at'] as String).toUtc(),
      ));
    }
  }

  // ── Image helpers ─────────────────────────────────────────────────────────

  /// Downloads image for [ref] ("hash.ext") and saves to disk.
  /// Returns the relative local path, or null on failure.
  Future<String?> _downloadCoverImage(SyncApi api, String userId, String ref) async {
    final hash = _hashFromRef(ref);
    final ext = _extFromRef(ref);
    final appDir = await getApplicationDocumentsDirectory();
    final relPath = p.join('covers', '$hash$ext');
    final absPath = p.join(appDir.path, relPath);

    if (File(absPath).existsSync()) return relPath;

    final bytes = await api.downloadImage(userId, hash);
    if (bytes == null) return null;

    final coversDir = Directory(p.join(appDir.path, 'covers'));
    if (!coversDir.existsSync()) await coversDir.create(recursive: true);
    await File(absPath).writeAsBytes(bytes);
    return relPath;
  }

  /// Looks up or creates a cover_images row for [localPath].
  Future<String> _getOrCreateCoverImage(
    Database rawDb,
    String localPath, {
    String? syncHash,
  }) async {
    final rows = await rawDb.query(
      'cover_images',
      columns: ['id'],
      where: 'local_path = ?',
      whereArgs: [localPath],
    );
    if (rows.isNotEmpty) return rows.first['id'] as String;
    final id = _uuid.v4();
    await rawDb.insert('cover_images', {
      'id': id,
      'local_path': localPath,
      'sync_hash': syncHash,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return id;
  }

  Future<String> _resolveLocalPath(String relativePath) async {
    if (relativePath.startsWith('/')) return relativePath;
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, relativePath);
  }

  bool _isImageRef(String? value) {
    if (value == null) return false;
    final hashPart = value.contains('.') ? value.substring(0, value.indexOf('.')) : value;
    return hashPart.length == 64 && RegExp(r'^[0-9a-f]+$').hasMatch(hashPart);
  }

  String _hashFromRef(String ref) {
    final dot = ref.indexOf('.');
    return dot == -1 ? ref : ref.substring(0, dot);
  }

  String _extFromRef(String ref) {
    final dot = ref.lastIndexOf('.');
    return dot == -1 ? '.jpg' : ref.substring(dot);
  }

  Map<String, dynamic> _withId(Map<String, dynamic> map, String id) {
    return {...map, 'id': id};
  }

  void _report(SyncProgressCallback? cb, double progress, String status) =>
      cb?.call(progress, status);
}
