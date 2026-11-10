import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class OfflineException implements Exception {
  const OfflineException([this.message = "You're offline. Check your connection and try again."]);

  final String message;

  @override
  String toString() => message;
}

class SessionExpiredException implements Exception {
  const SessionExpiredException([this.message = 'Your session has expired. Please log in again.']);

  final String message;

  @override
  String toString() => message;
}

/// An error the server explained (validation, "spot is full", 403...).
class ApiException implements Exception {
  const ApiException(this.message, [this.statusCode]);

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

typedef Json = Map<String, dynamic>;

class ApiClient {
  /// 10.0.2.2 is how the Android emulator reaches the PC running
  /// `php artisan serve`. For a real phone or a live server, pass
  /// --dart-define=API_BASE_URL=https://your-server/api
  static const String baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/api');

  ApiClient({this.token, this.onSessionExpired, http.Client? client}) : _client = client ?? http.Client();

  final String? token;
  final void Function()? onSessionExpired;
  final http.Client _client;

  // ---------------------------------------------------------------- auth

  Future<Json> login(String email, String password) =>
      _request('POST', '/login', body: {'email': email, 'password': password});

  Future<Json> register({required String name, required String email, required String password, String? phone}) =>
      _request('POST', '/register', body: {'name': name, 'email': email, 'password': password, 'phone': ?phone});

  Future<Json> me() async => (await _request('GET', '/me'))['user'] as Json;

  Future<Json> updateProfile({String? name, String? phone}) async =>
      (await _request('PUT', '/me', body: {'name': ?name, 'phone': ?phone}))['user'] as Json;

  Future<void> updateFcmToken(String fcmToken) => _request('POST', '/me/fcm-token', body: {'fcm_token': fcmToken});

  Future<void> logout() async {
    try {
      await _request('POST', '/logout');
    } catch (_) {
      // Logging out locally must work even if the server can't be reached.
    }
  }

  // ---------------------------------------------------------------- teams & players

  Future<List<dynamic>> teams() async => (await _request('GET', '/teams'))['teams'] as List<dynamic>;

  Future<Json> joinTeam(String code) async =>
      (await _request('POST', '/teams/join', body: {'join_code': code.trim().toUpperCase()}))['team'] as Json;

  Future<void> leaveTeam(int teamId) => _request('POST', '/teams/$teamId/leave');

  /// Returns {team, players, coaches, parent_count}.
  Future<Json> team(int teamId) => _request('GET', '/teams/$teamId');

  Future<Json> addPlayer(int teamId, Json player) async =>
      (await _request('POST', '/teams/$teamId/players', body: player))['player'] as Json;

  Future<void> updatePlayer(int playerId, Json fields) => _request('PUT', '/players/$playerId', body: fields);

  Future<void> removePlayer(int playerId) => _request('DELETE', '/players/$playerId');

  Future<void> claimPlayer(int playerId, {String? relationship}) =>
      _request('POST', '/players/$playerId/claim', body: {'relationship': ?relationship});

  // ---------------------------------------------------------------- events

  Future<List<dynamic>> upcomingEvents() async => (await _request('GET', '/events/upcoming'))['events'] as List<dynamic>;

  Future<List<dynamic>> teamEvents(int teamId, {bool past = false}) async =>
      (await _request('GET', '/teams/$teamId/events${past ? '?when=past' : ''}'))['events'] as List<dynamic>;

  /// Returns {event, players}.
  Future<Json> event(int eventId) => _request('GET', '/events/$eventId');

  Future<void> createEvent(int teamId, Json event) => _request('POST', '/teams/$teamId/events', body: event);

  Future<void> updateEvent(int eventId, Json fields) => _request('PUT', '/events/$eventId', body: fields);

  Future<void> cancelEvent(int eventId, {bool wholeSeries = false, String? reason}) =>
      _request('POST', '/events/$eventId/cancel${wholeSeries ? '?series=1' : ''}', body: {'reason': ?reason});

  Future<void> rsvp(int eventId, int playerId, String answer) =>
      _request('POST', '/events/$eventId/rsvp', body: {'player_id': playerId, 'rsvp': answer});

  /// [present] maps player id to whether they showed up.
  Future<void> saveAttendance(int eventId, Map<int, bool> present) => _request('POST', '/events/$eventId/attendance',
      body: {'attendance': present.map((id, here) => MapEntry('$id', here))});

  Future<List<dynamic>> attendanceReport(int teamId) async =>
      (await _request('GET', '/teams/$teamId/attendance-report'))['report'] as List<dynamic>;

  // ---------------------------------------------------------------- broadcasts

  Future<List<dynamic>> broadcasts(int teamId) async =>
      (await _request('GET', '/teams/$teamId/broadcasts'))['data'] as List<dynamic>;

  Future<void> sendBroadcast(int teamId, {required String title, required String body, bool urgent = false}) =>
      _request('POST', '/teams/$teamId/broadcasts', body: {'title': title, 'body': body, 'is_urgent': urgent});

  Future<void> markBroadcastRead(int broadcastId) => _request('POST', '/broadcasts/$broadcastId/read');

  /// Returns {seen: [...], not_seen: [...]}.
  Future<Json> broadcastReaders(int broadcastId) => _request('GET', '/broadcasts/$broadcastId/readers');

  Future<void> deleteBroadcast(int broadcastId) => _request('DELETE', '/broadcasts/$broadcastId');

  // ---------------------------------------------------------------- sign-ups

  Future<List<dynamic>> signups(int teamId) async =>
      (await _request('GET', '/teams/$teamId/signups'))['signups'] as List<dynamic>;

  Future<void> createSignup(int teamId, Json signup) => _request('POST', '/teams/$teamId/signups', body: signup);

  Future<void> deleteSignup(int signupId) => _request('DELETE', '/signups/$signupId');

  Future<void> addSlot(int signupId, {required String label, required int capacity, String? note}) =>
      _request('POST', '/signups/$signupId/slots', body: {'label': label, 'capacity': capacity, 'note': ?note});

  Future<void> removeSlot(int slotId) => _request('DELETE', '/slots/$slotId');

  Future<void> claimSlot(int slotId, {int? playerId}) =>
      _request('POST', '/slots/$slotId/claim', body: {'player_id': ?playerId});

  Future<void> unclaim(int claimId) => _request('DELETE', '/claims/$claimId');

  // ---------------------------------------------------------------- notifications

  /// Returns {notifications, unread_count}.
  Future<Json> notifications() => _request('GET', '/notifications');

  Future<void> markNotificationsRead() => _request('POST', '/notifications/read-all');

  // ---------------------------------------------------------------- plumbing

  /// Sends one request and turns every failure into a clear exception:
  /// no network -> [OfflineException], bad token -> [SessionExpiredException],
  /// anything else the server rejected -> [ApiException] with its message.
  /// Always bounded by a timeout so a stalled connection can't leave a
  /// spinner running forever.
  Future<Json> _request(String method, String path, {Json? body}) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const OfflineException();
    } on SocketException {
      throw const OfflineException();
    } on http.ClientException {
      throw const OfflineException();
    }

    if (response.statusCode == 401 && token != null) {
      onSessionExpired?.call();
      throw const SessionExpiredException();
    }

    final decoded = response.body.isEmpty ? <String, dynamic>{} : _decode(response.body);
    if (response.statusCode >= 400) {
      throw ApiException(_errorMessage(decoded), response.statusCode);
    }

    return decoded;
  }

  Json _decode(String body) {
    try {
      return jsonDecode(body) as Json;
    } catch (_) {
      return {};
    }
  }

  /// Laravel validation errors look like {"errors": {"email": ["..."]}};
  /// show the first one, since that's what the user needs to fix.
  String _errorMessage(Json data) {
    final errors = data['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    return data['message']?.toString() ?? 'Something went wrong. Please try again.';
  }
}
