import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/services/sync_api.dart';
import 'sync_service.dart' show SyncProgressCallback;

const _uuid = Uuid();
const _transferConcurrency = 4;

/// Returns true if [value] looks like a valid image ref ("sha256hex.ext").
bool isImageRef(String? value) {
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

/// Handles all image-related sync operations: upload (push phase) and
/// download/registration (pull phase).
class SyncImageService {
  const SyncImageService();

  // ── Push phase ────────────────────────────────────────────────────────────

  /// Uploads all unsynced cover images to the server.
  /// Returns a map of cover_images.id → sync_hash ref for use in event payloads.
  Future<Map<String, String>> syncCoverImages(
    SyncApi api,
    String userId,
    Database rawDb,
    SyncProgressCallback? onProgress,
  ) async {
    final allRows = await rawDb.query('cover_images');
    final idToRef = <String, String>{};

    for (final row in allRows) {
      final syncHash = row['sync_hash'] as String?;
      if (syncHash != null) idToRef[row['id'] as String] = syncHash;
    }

    final unsynced = allRows.where((r) => r['sync_hash'] == null).toList();
    if (unsynced.isEmpty) return idToRef;

    final idToRef2 = <String, String>{};
    final hashToBytes = <String, List<int>>{};

    for (final row in unsynced) {
      final id = row['id'] as String;
      final localPath = row['local_path'] as String;
      final absPath = await resolveLocalPath(localPath);
      final file = File(absPath);
      if (!file.existsSync()) continue;

      final bytes = await file.readAsBytes();
      final hash = sha256.convert(bytes).toString();
      final ext = p.extension(localPath).toLowerCase();
      idToRef2[id] = '$hash$ext';
      hashToBytes[hash] = bytes;
    }

    if (hashToBytes.isEmpty) return idToRef;

    final missing = await api.checkImages(userId, hashToBytes.keys.toList());
    final total = missing.length;

    int uploaded = 0;
    for (int i = 0; i < total; i += _transferConcurrency) {
      final chunk = missing.sublist(i, min(i + _transferConcurrency, total));
      await Future.wait(chunk.map((hash) => api.uploadImage(userId, hash, hashToBytes[hash]!)));
      uploaded += chunk.length;
      onProgress?.call(0.40 + uploaded / total * 0.15, 'Uploading images ($uploaded/$total)…');
    }

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

  // ── Pull phase ────────────────────────────────────────────────────────────

  /// Pre-fetches cover images referenced in [events] that are not already in
  /// [cache]. Downloads run in parallel, [_transferConcurrency] at a time.
  Future<void> prefetchImageRefs(
    Database rawDb,
    SyncApi api,
    String userId,
    List<RemoteSyncEvent> events,
    Map<String, String?> cache,
    SyncProgressCallback? onProgress,
  ) async {
    final newRefs = <String>{};
    for (final event in events) {
      if (event.domain == 'collection' || event.domain == 'text') {
        final ref = event.payload['cover_image'] as String?;
        if (ref != null && isImageRef(ref) && !cache.containsKey(ref)) {
          newRefs.add(ref);
        }
      }
    }
    if (newRefs.isEmpty) return;

    final refs = newRefs.toList();
    int done = 0;
    for (int i = 0; i < refs.length; i += _transferConcurrency) {
      final chunk = refs.sublist(i, min(i + _transferConcurrency, refs.length));
      final results = await Future.wait(
        chunk.map((ref) => downloadAndRegisterCoverImage(rawDb, api, userId, ref)),
      );
      for (var j = 0; j < chunk.length; j++) {
        cache[chunk[j]] = results[j];
      }
      done += chunk.length;
      onProgress?.call(null, 'Downloading images ($done/${refs.length})…');
    }
  }

  /// Resolves the cover_image_id for a pulled entity row.
  ///
  /// Priority:
  /// 1. If [ref] is a valid image ref, resolve via [cache] (download + register on miss).
  /// 2. Otherwise fall back to the existing local cover_image_id on the row.
  Future<String?> resolveCoverImageId(
    Database rawDb,
    SyncApi api,
    String userId, {
    required String? ref,
    required String table,
    required String entityId,
    required Map<String, String?> cache,
  }) async {
    if (ref != null && isImageRef(ref)) {
      if (cache.containsKey(ref)) return cache[ref];
      final id = await downloadAndRegisterCoverImage(rawDb, api, userId, ref);
      cache[ref] = id;
      if (id != null) return id;
    }
    final existing = await rawDb.query(
      table,
      columns: ['cover_image_id'],
      where: 'id = ?',
      whereArgs: [entityId],
    );
    return existing.isNotEmpty ? existing.first['cover_image_id'] as String? : null;
  }

  /// Downloads [ref] and registers it in the cover_images table.
  /// Returns the cover_images.id FK, or null on download failure.
  Future<String?> downloadAndRegisterCoverImage(
    Database rawDb,
    SyncApi api,
    String userId,
    String ref,
  ) async {
    final localPath = await _downloadCoverImage(api, userId, ref);
    if (localPath == null) return null;
    return _getOrCreateCoverImage(rawDb, localPath, syncHash: ref);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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

  Future<String> _getOrCreateCoverImage(Database rawDb, String localPath, {String? syncHash}) async {
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

  Future<String> resolveLocalPath(String relativePath) async {
    if (relativePath.startsWith('/')) return relativePath;
    final appDir = await getApplicationDocumentsDirectory();
    return p.join(appDir.path, relativePath);
  }
}
