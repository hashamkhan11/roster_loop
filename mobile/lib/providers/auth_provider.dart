import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/api_client.dart';
import '../services/push_notifications.dart';

const _secureStorage = FlutterSecureStorage();

class AuthState {
  const AuthState({this.token, this.user, this.restoring = true});

  final String? token;
  final Json? user;

  /// True until the saved-session check on cold start has finished, so the
  /// app never flashes the login screen at someone already logged in.
  final bool restoring;

  bool get isLoggedIn => token != null;
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restoreSession();
    return const AuthState();
  }

  Future<void> _restoreSession() async {
    final token = await _secureStorage.read(key: 'token');
    if (token == null) {
      state = const AuthState(restoring: false);
      return;
    }

    state = AuthState(token: token, restoring: false);
    unawaited(registerPushToken(_client(token)));

    // Refresh the name/phone in the background; an offline start still works.
    try {
      final user = await _client(token).me();
      if (state.token == token) state = AuthState(token: token, user: user, restoring: false);
    } catch (_) {}
  }

  Future<void> login(String email, String password) async {
    await _startSession(await ApiClient().login(email, password));
  }

  Future<void> register({required String name, required String email, required String password, String? phone}) async {
    await _startSession(await ApiClient().register(name: name, email: email, password: password, phone: phone));
  }

  void updateUser(Json user) => state = AuthState(token: state.token, user: user, restoring: false);

  Future<void> logout() async {
    final token = state.token;
    if (token != null) await ApiClient(token: token).logout();
    await _clearLocalSession();
  }

  /// Clears the local login without calling the server; used when the
  /// server already said the token is invalid.
  Future<void> forceLogout() async {
    if (state.token == null) return;
    await _clearLocalSession();
  }

  Future<void> _startSession(Json data) async {
    final token = data['token'] as String;
    await _secureStorage.write(key: 'token', value: token);
    state = AuthState(token: token, user: data['user'] as Json, restoring: false);
    unawaited(registerPushToken(_client(token)));
  }

  Future<void> _clearLocalSession() async {
    await _secureStorage.delete(key: 'token');
    await forgetPushToken();
    state = const AuthState(restoring: false);
  }

  ApiClient _client(String token) => ApiClient(token: token, onSessionExpired: forceLogout);
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

final apiClientProvider = Provider<ApiClient>((ref) {
  final token = ref.watch(authProvider.select((s) => s.token));
  return ApiClient(token: token, onSessionExpired: () => ref.read(authProvider.notifier).forceLogout());
});
