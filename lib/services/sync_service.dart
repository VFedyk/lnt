import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;

import '../data/datasources/database_service.dart';
import '../data/notifiers/data_change_notifier.dart';
import '../data/services/sync_api.dart';
import 'settings_service.dart';
import 'sync_image_service.dart';
import 'sync_pull_service.dart';
import 'sync_push_service.dart';

export 'sync_image_service.dart' show isImageRef;

const _batchSize = 200;

/// [progress] is 0.0–1.0 for determinate progress, or null for indeterminate.
typedef SyncProgressCallback = void Function(double? progress, String status);

/// Orchestrates a full sync cycle: pull remote events, then push local data.
/// Heavy lifting is delegated to [SyncPullService], [SyncPushService], and
/// [SyncImageService].
class SyncService {
  final DatabaseService _db;
  final SettingsService _settings;
  final DataChangeNotifier _changes;

  static const _imageService = SyncImageService();
  static const _pushService = SyncPushService();
  late final _pullService = SyncPullService(_imageService);

  SyncService({
    required DatabaseService db,
    required SettingsService settings,
    required DataChangeNotifier changes,
  })  : _db = db,
        _settings = settings,
        _changes = changes;

  SyncApi _unauthApi(String serverUrl) => SyncApi(serverUrl);
  SyncApi _authApi(String serverUrl, String token) => SyncApi.withToken(serverUrl, token);

  /// Resets all sync cursors and clears image upload state, then does a full sync.
  Future<void> fullSync({SyncProgressCallback? onProgress}) async {
    await _settings.clearSyncState();
    final rawDb = await _db.database;
    await rawDb.update('cover_images', {'sync_hash': null});
    await sync(onProgress: onProgress);
  }

  /// Incremental sync: pull new events from server, then push new local data.
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

    // Resolve returns a token; use an unauthenticated client for this one call.
    final userId = await _resolveUserId(_unauthApi(serverUrl), nickname);
    final token = (await _settings.getSyncToken())!;
    final api = _authApi(serverUrl, token);
    final deviceId = await _settings.getSyncDeviceId();

    final lastPulledSeq = await _settings.getSyncLastPulledSeq();
    await _pull(api, userId, lastPulledSeq, onProgress);

    final lastPushedAt = await _settings.getSyncLastPushedAt();
    final pushLastSeq = await _push(api, userId, deviceId, lastPushedAt, onProgress);
    await _settings.setSyncLastPushedAt(DateTime.now().toUtc());

    // Advance the pull cursor past the events we just pushed. Without this,
    // the next pull would start from the pre-push seq and fetch all our own
    // events back from the server.
    if (pushLastSeq > 0) {
      final pulledSeq = await _settings.getSyncLastPulledSeq();
      if (pushLastSeq > pulledSeq) {
        await _settings.setSyncLastPulledSeq(pushLastSeq);
      }
    }
  }

  // ── Pull ──────────────────────────────────────────────────────────────────

  Future<void> _pull(
    SyncApi api,
    String userId,
    int since,
    SyncProgressCallback? onProgress,
  ) async {
    final rawDb = await _db.database;
    final imageRefCache = <String, String?>{};
    int cursor = since;
    int? latestSeq;
    int page = 1;
    int totalReceived = 0;

    while (true) {
      _report(onProgress, 0.10,
          page == 1 ? 'Pulling events…' : 'Pulling events (page $page, $totalReceived received)…');
      final response = await api.pullEvents(
        userId,
        since: cursor,
        onProgress: page == 1
            ? (fraction) => _report(
                onProgress,
                0.10 + fraction * 0.10,
                'Pulling events (${(fraction * 100).round()}%)…',
              )
            : null,
      );
      if (response.events.isEmpty) break;
      latestSeq = response.latestSeq;
      totalReceived += response.events.length;
      page++;

      await _imageService.prefetchImageRefs(
          rawDb, api, userId, response.events, imageRefCache, onProgress);

      final pageEvents = response.events.length;
      final alreadyApplied = totalReceived - pageEvents;
      for (int i = 0; i < pageEvents; i++) {
        final event = response.events[i];
        try {
          await _pullService.applyEvent(rawDb, event, api, userId, imageRefCache);
        } catch (e, st) {
          debugPrint('SyncService: skipped event seq=${event.seq} domain=${event.domain}: $e\n$st');
        }
        _report(onProgress, null, 'Applying events (${alreadyApplied + i + 1}/$totalReceived)…');
      }

      cursor = response.events.last.seq;
    }

    if (latestSeq != null) {
      await _settings.setSyncLastPulledSeq(latestSeq);
      _changes.notifyAll();
    }
  }

  // ── Push ──────────────────────────────────────────────────────────────────

  /// Returns the highest seq the server assigned to the pushed batch (0 if nothing pushed).
  Future<int> _push(
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
    final coverRefs = await _imageService.syncCoverImages(api, userId, rawDb, onProgress);

    await _pushService.collectLanguages(rawDb, events, sinceStr);
    await _pushService.collectCollections(rawDb, events, sinceStr, coverRefs);
    await _pushService.collectTexts(rawDb, events, sinceStr, coverRefs);
    await _pushService.collectTerms(rawDb, events, sinceStr);
    // Immediately after collectTerms so the parent term precedes its sentences
    // within a push batch — the pull side applies events in order and a
    // sentence ahead of its term would fail the FK.
    await _pushService.collectTermSentences(rawDb, events, sinceStr);
    await _pushService.collectReviewCards(rawDb, events, sinceStr);
    await _pushService.collectReviewLogs(rawDb, events, sinceStr);
    await _pushService.collectStatusLogs(rawDb, events, sinceStr);
    await _pushService.collectTombstones(rawDb, events, sinceStr);

    if (events.isEmpty) return 0;

    final totalBatches = (events.length / _batchSize).ceil();
    _report(onProgress, 0.55, 'Pushing ${events.length} events…');

    int lastSeq = 0;
    for (int i = 0; i < events.length; i += _batchSize) {
      final batchIndex = i ~/ _batchSize + 1;
      final batch = events.sublist(i, min(i + _batchSize, events.length));
      lastSeq = await api.pushEvents(userId, deviceId, batch);
      _report(
        onProgress,
        0.55 + (batchIndex / totalBatches) * 0.45,
        'Pushing events ($batchIndex/$totalBatches)…',
      );
    }
    return lastSeq;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _resolveUserId(SyncApi api, String nickname) async {
    final cachedId = await _settings.getSyncUserId();
    final cachedToken = await _settings.getSyncToken();
    if (cachedId != null && cachedId.isNotEmpty &&
        cachedToken != null && cachedToken.isNotEmpty) {
      return cachedId;
    }
    final (userId, token) = await api.resolveUser(nickname);
    await _settings.setSyncUserId(userId);
    await _settings.setSyncToken(token);
    return userId;
  }

  void _report(SyncProgressCallback? cb, double? progress, String status) =>
      cb?.call(progress, status);
}
