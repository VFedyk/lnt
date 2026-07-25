import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';

import '../data/services/sync_api.dart';
import 'sync_image_service.dart';

/// Applies remote [RemoteSyncEvent]s to the local database.
///
/// Content domains are resolved last-write-wins on row timestamps: a remote
/// write lands only when it is strictly newer than the local row. Equal
/// timestamps are the echo of this device's own push and are a no-op.
/// `review_log` / `term_status_log` are append-only and bypass LWW entirely.
///
/// Image resolution is delegated to [SyncImageService].
class SyncPullService {
  final SyncImageService _imageService;

  SyncPullService(this._imageService);

  /// Domains resolved by last-write-wins, mapped to their table.
  static const Map<String, String> _lwwTables = {
    'language': 'languages',
    'collection': 'collections',
    'text': 'texts',
    'term': 'terms',
    'review_card': 'review_cards',
  };

  /// Applies a single remote event to [rawDb].
  /// Skips the event silently (with a debug log) if the payload is invalid,
  /// or if an older write loses last-write-wins against local state.
  Future<void> applyEvent(
    Database rawDb,
    RemoteSyncEvent event,
    SyncApi api,
    String userId,
    Map<String, String?> imageRefCache,
  ) async {
    if (event.payload['_deleted'] == true) {
      await _applyDelete(rawDb, event);
      return;
    }
    if (!validatePayload(event.domain, event.payload)) {
      debugPrint('SyncPullService: invalid payload domain=${event.domain} seq=${event.seq}');
      return;
    }
    final payload = event.payload;
    switch (event.domain) {
      case 'language':
        if (!await _shouldApply(rawDb, event)) return;
        await _upsert(rawDb, 'languages', event.entityId, withId(payload, event.entityId));
      case 'collection':
        if (!await _shouldApply(rawDb, event)) return;
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
        await _upsert(rawDb, 'collections', event.entityId, row);
      case 'text':
        if (!await _shouldApply(rawDb, event)) return;
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
        await _upsert(rawDb, 'texts', event.entityId, row);
      case 'term':
        if (!await _shouldApply(rawDb, event)) return;
        final translations = payload['translations'] as List<dynamic>?;
        final termRow = Map<String, dynamic>.from(payload)..remove('translations');
        // Transaction ensures the term row and its translations land atomically.
        // Without it, a mid-loop failure after deleting translations leaves a term
        // with no translations — visible as a silent data loss to the user.
        await rawDb.transaction((txn) async {
          await _upsert(txn, 'terms', event.entityId, withId(termRow, event.entityId));
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
      case 'review_card':
        if (!await _shouldApply(rawDb, event)) return;
        // review_cards has UNIQUE(term_id), so a local card for the same term
        // under a *different* id also competes for this slot — resolve it by
        // the same LWW rule rather than letting the insert fail.
        final termId = payload['term_id'];
        final conflicting = await rawDb.query('review_cards',
            where: 'term_id = ? AND id != ?', whereArgs: [termId, event.entityId]);
        if (conflicting.isNotEmpty) {
          final otherTs = _rowTs(conflicting.first);
          if (otherTs != null && !_eventTs(event).isAfter(otherTs)) return;
          await rawDb.delete('review_cards',
              where: 'id = ?', whereArgs: [conflicting.first['id']]);
        }
        await _upsert(rawDb, 'review_cards', event.entityId, withId(payload, event.entityId));
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

  // ── LWW plumbing ───────────────────────────────────────────────────────────

  /// UPDATE-or-INSERT. Never `ConflictAlgorithm.replace`: with FKs enforced,
  /// SQLite REPLACE deletes the existing row first, cascading its children
  /// (translations, review cards, whole language subtrees) away with it.
  Future<void> _upsert(DatabaseExecutor db, String table, String entityId,
      Map<String, dynamic> row) async {
    final updated = await db.update(table, row, where: 'id = ?', whereArgs: [entityId]);
    if (updated == 0) await db.insert(table, row);
  }

  /// True when [event] is a strictly newer write than local state.
  ///
  /// Also handles resurrection: a write newer than a tombstone clears it, an
  /// older one leaves the entity deleted.
  Future<bool> _shouldApply(DatabaseExecutor db, RemoteSyncEvent event) async {
    final table = _lwwTables[event.domain];
    if (table == null) return true;
    final eventTs = _eventTs(event);

    final tombstones = await db.query('sync_tombstones',
        where: 'domain = ? AND entity_id = ?',
        whereArgs: [event.domain, event.entityId]);
    if (tombstones.isNotEmpty) {
      final deletedAt = _parseTs(tombstones.first['deleted_at']);
      if (deletedAt != null && !eventTs.isAfter(deletedAt)) return false;
      await db.delete('sync_tombstones',
          where: 'domain = ? AND entity_id = ?',
          whereArgs: [event.domain, event.entityId]);
    }

    final rows = await db.query(table, where: 'id = ?', whereArgs: [event.entityId]);
    if (rows.isEmpty) return true;
    final localTs = _rowTs(rows.first);
    if (localTs == null) return true;
    return eventTs.isAfter(localTs);
  }

  /// Applies a remote tombstone: deletes the entity (FK cascade takes its
  /// children) and records the tombstone locally so a late older write can't
  /// resurrect it.
  Future<void> _applyDelete(Database db, RemoteSyncEvent event) async {
    final table = _lwwTables[event.domain];
    if (table == null) return;
    final deletedAt = _parseTs(event.payload['deleted_at']) ?? event.clientTs.toUtc();

    final rows = await db.query(table, where: 'id = ?', whereArgs: [event.entityId]);
    if (rows.isNotEmpty) {
      final localTs = _rowTs(rows.first);
      // The local write wins. Its own event is already on the server, so every
      // device converges on the row surviving — no tombstone is recorded.
      if (localTs != null && !deletedAt.isAfter(localTs)) return;
      await db.delete(table, where: 'id = ?', whereArgs: [event.entityId]);
    }
    await db.insert(
      'sync_tombstones',
      {
        'domain': event.domain,
        'entity_id': event.entityId,
        'deleted_at': deletedAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  DateTime _eventTs(RemoteSyncEvent e) =>
      _parseTs(e.payload['updated_at']) ??
      _parseTs(e.payload['created_at']) ??
      e.clientTs.toUtc();

  DateTime? _rowTs(Map<String, Object?> row) =>
      _parseTs(row['updated_at']) ?? _parseTs(row['created_at']);

  DateTime? _parseTs(Object? raw) =>
      raw is String && raw.isNotEmpty ? DateTime.parse(raw).toUtc() : null;

  /// Returns true if [payload] contains the required fields for [domain].
  bool validatePayload(String domain, Map<String, dynamic> payload) {
    switch (domain) {
      case 'language': return payload['name'] != null;
      case 'collection': return payload['language_id'] != null;
      // collection_id is intentionally NOT required: texts at the library root
      // legally have collection_id NULL (schema: ON DELETE SET NULL).
      case 'text': return payload['language_id'] != null;
      case 'term': return payload['language_id'] != null && payload['text'] != null;
      case 'review_card': return payload['term_id'] != null && payload['card_data'] != null;
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
