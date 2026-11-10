import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/navigation_provider.dart';
import 'api_client.dart';

const _lastFcmTokenKey = 'last_registered_fcm_token';

const _channel = AndroidNotificationChannel(
  'rosterloop_team',
  'Team updates',
  description: 'Coach messages, schedule changes and game reminders',
  importance: Importance.high,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

/// Doesn't need Firebase, so it can run at the same time as Firebase setup.
Future<void> initLocalNotifications() async {
  await _localNotifications.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );

  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_channel);
}

/// Android doesn't show a push banner while the app is open, so we show
/// one ourselves; otherwise an urgent "practice cancelled" could go unseen.
void listenForForegroundMessages(ProviderContainer container) {
  FirebaseMessaging.onMessage.listen((message) {
    container.read(refreshTickProvider.notifier).bump();

    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  });
}

/// Opening the app from a push lands on the Inbox tab.
Future<void> initNotificationTapHandling(ProviderContainer container) async {
  void openInbox(RemoteMessage _) => container.read(selectedTabProvider.notifier).select(AppTab.inbox);

  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) openInbox(initialMessage);

  FirebaseMessaging.onMessageOpenedApp.listen(openInbox);
}

/// Skips sending the token again if it hasn't changed since last time.
/// Best-effort: push must never block or break login, e.g. on an emulator
/// without Google Play, where getToken() can hang.
Future<void> registerPushToken(ApiClient client) async {
  try {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission().timeout(const Duration(seconds: 10));

    final token = await messaging.getToken().timeout(const Duration(seconds: 10));
    if (token == null) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_lastFcmTokenKey) == token) return;

    await client.updateFcmToken(token);
    await prefs.setString(_lastFcmTokenKey, token);
  } catch (_) {
    // Ignore: the app works fine without push, and the inbox still fills up.
  }
}

/// Called on logout so the next account on this phone re-registers the token.
Future<void> forgetPushToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_lastFcmTokenKey);
}
