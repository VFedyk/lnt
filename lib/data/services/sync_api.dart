import 'dart:async' show TimeoutException;
import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:io' show SocketException;
import 'package:http/http.dart' as http;

const _kTimeout = Duration(seconds: 30);

/// Retries [fn] up to 3 times on transient network errors (socket / timeout),
/// backing off 1 s → 2 s between attempts. Not used for mutating calls that
/// are not idempotent (push events).
Future<T> _retry<T>(Future<T> Function() fn) async {
  var delay = const Duration(seconds: 1);
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      return await fn();
    } on SocketException {
      if (attempt == 2) rethrow;
    } on TimeoutException {
      if (attempt == 2) rethrow;
    }
    await Future<void>.delayed(delay);
    delay *= 2;
  }
  throw StateError('unreachable');
}

class SyncApiException implements Exception {
  final int statusCode;
  final String message;
  SyncApiException(this.statusCode, this.message);
  @override
  String toString() => 'SyncApiException($statusCode): $message';
}

class EventInput {
  final String domain;
  final String entityId;
  final Map<String, dynamic> payload;
  final DateTime clientTs;

  EventInput({
    required this.domain,
    required this.entityId,
    required this.payload,
    required this.clientTs,
  });

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'entity_id': entityId,
    'payload': payload,
    'client_ts': clientTs.toUtc().toIso8601String(),
  };
}

class RemoteSyncEvent {
  final int seq;
  final String domain;
  final String entityId;
  final Map<String, dynamic> payload;
  final DateTime clientTs;
  final DateTime serverTs;

  RemoteSyncEvent({
    required this.seq,
    required this.domain,
    required this.entityId,
    required this.payload,
    required this.clientTs,
    required this.serverTs,
  });

  factory RemoteSyncEvent.fromJson(Map<String, dynamic> json) {
    // payload may be a JSON object or a double-encoded string (from earlier bug)
    var decoded = jsonDecode(json['payload'] as String);
    if (decoded is String) decoded = jsonDecode(decoded);
    return RemoteSyncEvent(
      seq: json['seq'] as int,
      domain: json['domain'] as String,
      entityId: json['entity_id'] as String,
      payload: decoded as Map<String, dynamic>,
      clientTs: DateTime.parse(json['client_ts'] as String),
      serverTs: DateTime.parse(json['server_ts'] as String),
    );
  }
}

class PullResponse {
  final List<RemoteSyncEvent> events;
  final int latestSeq;

  PullResponse({required this.events, required this.latestSeq});

  factory PullResponse.fromJson(Map<String, dynamic> json) => PullResponse(
    events: (json['events'] as List)
        .map((e) => RemoteSyncEvent.fromJson(e as Map<String, dynamic>))
        .toList(),
    latestSeq: json['latest_seq'] as int,
  );
}

class SyncApi {
  final String baseUrl;
  final String? _token;

  /// Create an unauthenticated client (for /users/resolve only).
  SyncApi(this.baseUrl) : _token = null;

  /// Create an authenticated client that includes `Authorization: Bearer <token>`.
  SyncApi.withToken(this.baseUrl, String token) : _token = token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  void _checkStatus(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SyncApiException(res.statusCode, res.body);
    }
  }

  /// Returns (userId, bearerToken). Use an unauthenticated [SyncApi] instance.
  Future<(String userId, String token)> resolveUser(String nickname) => _retry(() async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/v1/users/resolve'),
          headers: _headers,
          body: jsonEncode({'nickname': nickname}),
        )
        .timeout(_kTimeout);
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['user_id'] as String, json['token'] as String);
  });

  // Not retried: pushing the same batch twice would duplicate events on the server.
  Future<int> pushEvents(
    String userId,
    String deviceId,
    List<EventInput> events,
  ) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/api/v1/users/$userId/events'),
          headers: _headers,
          body: jsonEncode({
            'device_id': deviceId,
            'events': events.map((e) => e.toJson()).toList(),
          }),
        )
        .timeout(_kTimeout);
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['last_seq'] as int;
  }

  Future<List<String>> checkImages(String userId, List<String> hashes) =>
      _retry(() async {
        final res = await http
            .post(
              Uri.parse('$baseUrl/api/v1/users/$userId/images/check'),
              headers: _headers,
              body: jsonEncode({'hashes': hashes}),
            )
            .timeout(_kTimeout);
        _checkStatus(res);
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        return (json['missing'] as List).cast<String>();
      });

  // Idempotent: server uses INSERT OR IGNORE so duplicate uploads are safe.
  Future<void> uploadImage(String userId, String hash, List<int> bytes) =>
      _retry(() async {
        final res = await http
            .post(
              Uri.parse('$baseUrl/api/v1/users/$userId/images/$hash'),
              headers: {'Content-Type': 'application/octet-stream'},
              body: bytes,
            )
            .timeout(_kTimeout);
        _checkStatus(res);
      });

  Future<List<int>?> downloadImage(String userId, String hash) =>
      _retry(() async {
        final res = await http
            .get(Uri.parse('$baseUrl/api/v1/users/$userId/images/$hash'))
            .timeout(_kTimeout);
        if (res.statusCode == 404) return null;
        _checkStatus(res);
        return res.bodyBytes;
      });

  Future<PullResponse> pullEvents(
    String userId, {
    int since = 0,
    int limit = 1000,
    String? domain,
    void Function(double)? onProgress,
  }) async {
    final query = {
      'since': since.toString(),
      'limit': limit.toString(),
      'domain': ?domain,
    };
    final uri = Uri.parse('$baseUrl/api/v1/users/$userId/events')
        .replace(queryParameters: query);

    final request = http.Request('GET', uri)..headers.addAll(_headers);
    // Timeout on initial connection; per-chunk timeout guards against stalled streams.
    final streamed = await http.Client().send(request).timeout(_kTimeout);

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw SyncApiException(streamed.statusCode, 'pull failed');
    }

    final contentLength = streamed.contentLength; // null if server omits header
    int received = 0;
    final chunks = <int>[];

    await for (final chunk in streamed.stream.timeout(_kTimeout)) {
      chunks.addAll(chunk);
      received += chunk.length;
      if (onProgress != null && contentLength != null && contentLength > 0) {
        onProgress(received / contentLength);
      }
    }

    return PullResponse.fromJson(
      jsonDecode(utf8.decode(chunks)) as Map<String, dynamic>,
    );
  }
}
