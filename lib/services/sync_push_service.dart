import 'package:sqflite/sqflite.dart';

import '../data/services/sync_api.dart';

/// Collects local database rows into [EventInput] batches for the push phase.
/// All methods receive an already-opened [rawDb] and mutate [events] in place.
class SyncPushService {
  const SyncPushService();

  Future<void> collectLanguages(
      Database rawDb, List<EventInput> events, String? sinceStr) async {
    // Incremental: pushing every language on every sync grew the server event
    // log without bound and stamped bogus (now()) timestamps on unchanged rows.
    final rows = sinceStr != null
        ? await rawDb.query('languages', where: 'updated_at > ?', whereArgs: [sinceStr])
        : await rawDb.query('languages');
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      events.add(EventInput(
        domain: 'language',
        entityId: id,
        payload: Map<String, dynamic>.from(row),
        clientTs: _rowTs(row) ?? DateTime.now().toUtc(),
      ));
    }
  }

  Future<void> collectCollections(
    Database rawDb,
    List<EventInput> events,
    String? sinceStr,
    Map<String, String> coverRefs,
  ) async {
    final rows = sinceStr != null
        ? await rawDb.query('collections',
            where: 'COALESCE(updated_at, created_at) > ?', whereArgs: [sinceStr])
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
        clientTs: _rowTs(row) ?? DateTime.now().toUtc(),
      ));
    }
  }

  Future<void> collectTexts(
    Database rawDb,
    List<EventInput> events,
    String? sinceStr,
    Map<String, String> coverRefs,
  ) async {
    final rows = sinceStr != null
        ? await rawDb.query('texts',
            where: 'COALESCE(updated_at, created_at) > ?', whereArgs: [sinceStr])
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
        clientTs: _rowTs(row) ?? DateTime.now().toUtc(),
      ));
    }
  }

  Future<void> collectTerms(Database rawDb, List<EventInput> events, String? sinceStr) async {
    final rows = sinceStr != null
        ? await rawDb.query('terms',
            where: 'COALESCE(updated_at, created_at) > ?', whereArgs: [sinceStr])
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
        clientTs: _rowTs(row) ?? DateTime.now().toUtc(),
      ));
    }
  }

  Future<void> collectReviewLogs(
      Database rawDb, List<EventInput> events, String? sinceStr) async {
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

  Future<void> collectReviewCards(
      Database rawDb, List<EventInput> events, String? sinceStr) async {
    final rows = sinceStr != null
        ? await rawDb.query('review_cards',
            where: 'COALESCE(updated_at, created_at) > ?', whereArgs: [sinceStr])
        : await rawDb.query('review_cards');
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      events.add(EventInput(
        domain: 'review_card',
        entityId: id,
        payload: Map<String, dynamic>.from(row),
        clientTs: DateTime.parse(
            (row['updated_at'] ?? row['created_at']) as String).toUtc(),
      ));
    }
  }

  Future<void> collectStatusLogs(
      Database rawDb, List<EventInput> events, String? sinceStr) async {
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

  /// Collects deletion tombstones as `_deleted` events so removals propagate
  /// to other devices. The receiving side applies them with LWW semantics.
  Future<void> collectTombstones(
      Database rawDb, List<EventInput> events, String? sinceStr) async {
    final rows = sinceStr != null
        ? await rawDb.query('sync_tombstones',
            where: 'deleted_at > ?', whereArgs: [sinceStr])
        : await rawDb.query('sync_tombstones');
    for (final row in rows) {
      final deletedAt = DateTime.parse(row['deleted_at'] as String).toUtc();
      events.add(EventInput(
        domain: row['domain'] as String,
        entityId: row['entity_id'] as String,
        payload: {'_deleted': true, 'deleted_at': row['deleted_at']},
        clientTs: deletedAt,
      ));
    }
  }

  /// Last-write timestamp of a row: updated_at, falling back to created_at.
  static DateTime? _rowTs(Map<String, Object?> row) {
    final raw = (row['updated_at'] ?? row['created_at']) as String?;
    return raw == null ? null : DateTime.parse(raw).toUtc();
  }
}
