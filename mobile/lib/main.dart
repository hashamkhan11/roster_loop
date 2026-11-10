import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/push_notifications.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Push is best-effort: without a Firebase project (google-services.json)
  // or Google Play, initializeApp throws and the app simply runs without it.
  var firebaseReady = false;
  try {
    await Future.wait([Firebase.initializeApp(), initLocalNotifications()]).timeout(const Duration(seconds: 10));
    firebaseReady = true;
  } catch (_) {}

  final container = ProviderContainer();
  if (firebaseReady) listenForForegroundMessages(container);

  runApp(UncontrolledProviderScope(container: container, child: const RosterLoopApp()));

  if (firebaseReady) unawaited(initNotificationTapHandling(container));
}

class RosterLoopApp extends ConsumerWidget {
  const RosterLoopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return MaterialApp(
      // A new key on login/logout throws away every open screen. Changing
      // `home` alone would leave pushed screens (an open event) on top.
      key: ValueKey(auth.isLoggedIn),
      title: 'RosterLoop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: auth.restoring
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : auth.isLoggedIn
              ? const MainShell()
              : const LoginScreen(),
    );
  }
}
