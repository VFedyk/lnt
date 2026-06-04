import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';

import '../data/services/sync_api.dart';
import 'sync_image_service.dart';

/// Applies remote [RemoteSyncEvent]s to the local database.
/// Image resolution is delegated to [SyncImageService].
class SyncPullService {
  final SyncImageService _imageService;

  SyncPullService(this._imageService);

  /// Applies a single remote event to [rawDb].
  /// Skips the event silently (with a debug log) if the payload is invalid.
  Future<void> applyEvent(
    Database rawDb,
    RemoteSyncEvent event,
    SyncApi api,
    String userId,
    Map<String, String?> imageRefCache,
  ) async {
    if (!validatePayload(event.domain, event.payload)) {
      debugPrint('SyncPullService: invalid payload domain=${event.domain} seq=${event.seq}');
      return;
    }
    final payload = event.payload;
    switch (event.domain) {
      case 'language':
        await rawDb.insert(
          'languages',
          withId(payload, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      case 'collection':
        final row = Map<String, dynamic>.from(payload)
          ..remove('cover_image')
          ..remove('cover_image_id')
          ..['id'] = event.entityId;
        row['cover_image_id'] = await _imageService.resolveCoverImageId(
          rawDb, api, userId,
          ref: payload['cover_image'] as String?,
          table: 'collections',
          entityId: event.entityId,
          cache: imageRefCache,
        );
        await rawDb.insert('collections', row, conflictAlgorithm: ConflictAlgorithm.replace);
      case 'text':
        final row = Map<String, dynamic>.from(payload)
          ..remove('cover_image')
          ..remove('cover_image_id')
          ..['id'] = event.entityId;
        row['cover_image_id'] = await _imageService.resolveCoverImageId(
          rawDb, api, userId,
          ref: payload['cover_image'] as String?,
          table: 'texts',
          entityId: event.entityId,
          cache: imageRefCache,
        );
        await rawDb.insert('texts', row, conflictAlgorithm: ConflictAlgorithm.replace);
      case 'term':
        final translations = payload['translations'] as List<dynamic>?;
        final termRow = Map<String, dynamic>.from(payload)..remove('translations');
        // Transaction ensures the term row and its translations land atomically.
        // Without it, a mid-loop failure after deleting translations leaves a term
        // with no translations — visible as a silent data loss to the user.
        await rawDb.transaction((txn) async {
          await txn.insert(
            'terms',
            withId(termRow, event.entityId),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          if (translations != null) {
            await txn.delete('translations',
                where: 'term_id = ?', whereArgs: [event.entityId]);
            for (final t in translations) {
              await txn.insert(
                'translations',
                Map<String, dynamic>.from(t as Map),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }
        });
      case 'review_log':
        await rawDb.insert(
          'review_logs',
          withId(payload, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      case 'term_status_log':
        await rawDb.insert(
          'term_status_log',
          withId(payload, event.entityId),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
    }
  }

  /// Returns true if [payload] contains the required fields for [domain].
  bool validatePayload(String domain, Map<String, dynamic> payload) {
    switch (domain) {
      case 'language': return payload['name'] != null;
      case 'collection': return payload['language_id'] != null;
      case 'text': return payload['language_id'] != null && payload['collection_id'] != null;
      case 'term': return payload['language_id'] != null && payload['text'] != null;
      case 'review_log': return payload['term_id'] != null && payload['reviewed_at'] != null;
      case 'term_status_log':
        return payload['term_id'] != null &&
            payload['status'] != null &&
            payload['changed_at'] != null;
      default: return true;
    }
  }

  /// Merges [id] into [map] under the key 'id'.
  Map<String, dynamic> withId(Map<String, dynamic> map, String id) =>
      {...map, 'id': id};
}
