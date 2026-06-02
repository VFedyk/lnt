import 'dart:convert' show jsonDecode, jsonEncode;
import 'package:http/http.dart' as http;

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
    return RemoteSyncEvent(
      seq: json['seq'] as int,
      domain: json['domain'] as String,
      entityId: json['entity_id'] as String,
      payload: jsonDecode(json['payload'] as String) as Map<String, dynamic>,
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

  SyncApi(this.baseUrl);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  void _checkStatus(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw SyncApiException(res.statusCode, res.body);
    }
  }

  Future<String> resolveUser(String nickname) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/users/resolve'),
      headers: _headers,
      body: jsonEncode({'nickname': nickname}),
    );
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['user_id'] as String;
  }

  Future<int> pushEvents(
    String userId,
    String deviceId,
    List<EventInput> events,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/v1/users/$userId/events'),
      headers: _headers,
      body: jsonEncode({
        'device_id': deviceId,
        'events': events.map((e) => e.toJson()).toList(),
      }),
    );
    _checkStatus(res);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['last_seq'] as int;
  }

  Future<PullResponse> pullEvents(String userId, {int since = 0, String? domain}) async {
    final query = {
      'since': since.toString(),
      if (domain != null) 'domain': domain,
    };
    final uri = Uri.parse('$baseUrl/api/v1/users/$userId/events')
        .replace(queryParameters: query);
    final res = await http.get(uri, headers: _headers);
    _checkStatus(res);
    return PullResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
