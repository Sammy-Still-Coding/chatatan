import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Registers the current installation for FCM.  It is intentionally inert
/// until Firebase config is added, so local/web development keeps working.
class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  bool _initializing = false;
  bool _ready = false;
  StreamSubscription<String>? _refreshSubscription;

  Future<void> initialize() async {
    if (_ready || _initializing) return;
    _initializing = true;
    try {
      await Firebase.initializeApp();
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
      await _refreshSubscription?.cancel();
      _refreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        _registerToken,
        onError: (error, stackTrace) {},
      );
      _ready = true;
    } catch (_) {
      // Firebase configuration is optional during development. Once
      // flutterfire configure is run this branch is no longer taken.
    } finally {
      _initializing = false;
    }
  }

  Future<void> _registerToken(String token) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null || token.isEmpty) return;
    await client.from('user_devices').upsert({
      'user_id': user.id,
      'push_token': token,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'last_active_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,push_token');
  }
}
