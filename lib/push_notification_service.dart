import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers the current installation for FCM.  It is intentionally inert
/// until Firebase config is added, so local/web development keeps working.
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  bool _initializing = false;
  bool _ready = false;
  StreamSubscription<String>? _refreshSubscription;
  final StreamController<Map<String, String>> _openedController =
      StreamController<Map<String, String>>.broadcast();
  Stream<Map<String, String>> get onNotificationOpened =>
      _openedController.stream;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'chatatan_messages',
    'Pesan ChaTatan',
    description: 'Notifikasi untuk chat, grup, dan forum ChaTatan.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_ready || _initializing) return;
    _initializing = true;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      await _initializeForegroundNotifications();

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
      await _refreshSubscription?.cancel();
      _refreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        _registerToken,
        onError: (error, stackTrace) {},
      );
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      FirebaseMessaging.onMessageOpenedApp.listen(_emitOpenedMessage);
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) _emitOpenedMessage(initial);
      _ready = true;
    } catch (error, stackTrace) {
      // Kept visible in `flutter run`: a missing Firebase configuration,
      // notification denial, or RLS policy should never fail silently.
      debugPrint('Push notification setup gagal: $error\n$stackTrace');
    } finally {
      _initializing = false;
    }
  }

  Future<void> _registerToken(String token) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || token.isEmpty) return;
    // A manual lookup works with both old schemas and a new unique index.
    // PostgREST cannot target a partial unique index in an `upsert` conflict.
    final existing = await client
        .from('user_devices')
        .select('id')
        .eq('user_id', user.id)
        .eq('push_token', token)
        .maybeSingle();
    final device = {
      'user_id': user.id,
      'push_token': token,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'last_active_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (existing == null) {
      await client.from('user_devices').insert(device);
    } else {
      await client.from('user_devices').update(device).eq('id', existing['id']);
    }
    debugPrint('Token push ChaTatan berhasil terdaftar.');
  }

  Future<void> _initializeForegroundNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      settings: const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (response) {
        final raw = response.payload;
        if (raw == null || raw.isEmpty) return;
        // The payload is deliberately encoded as simple key/value pairs.
        final data = <String, String>{};
        for (final part in raw.split('&')) {
          final pair = part.split('=');
          if (pair.length == 2)
            data[Uri.decodeComponent(pair[0])] = Uri.decodeComponent(pair[1]);
        }
        if (data.isNotEmpty) _openedController.add(data);
      },
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title ?? 'ChaTatan',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'chatatan_messages',
          'Pesan ChaTatan',
          channelDescription:
              'Notifikasi untuk chat, grup, dan forum ChaTatan.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data.isEmpty
          ? null
          : message.data.entries
                .map(
                  (entry) =>
                      '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
                )
                .join('&'),
    );
  }

  void _emitOpenedMessage(RemoteMessage message) {
    if (message.data.isEmpty) return;
    _openedController.add(
      message.data.map((key, value) => MapEntry(key, value.toString())),
    );
  }
}
