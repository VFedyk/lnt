import 'package:sqflite/sqflite.dart';

import '../data/services/sync_api.dart';

/// Collects local database rows into [EventInput] batches for the push phase.
/// All methods receive an already-opened [rawDb] and mutate [events] in place.
class SyncPushService {
  const SyncPushService();

  Future<void> collectLanguages(Database rawDb, List<EventInput> events) async {
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

  Future<void> collectCollections(
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
        clientTs: DateTime.parse(row['created_at'] as String).toUtc(),
      ));
    }
  }

  Future<void> collectTerms(Database rawDb, List<EventInput> events, String? sinceStr) async {
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
}
