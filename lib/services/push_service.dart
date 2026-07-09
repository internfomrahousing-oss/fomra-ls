import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';
import 'auth_service.dart';

/// OS push notifications via Firebase Cloud Messaging (web + Android).
///
/// Every method is wrapped so a missing/failed Firebase setup can never crash
/// the app — push simply stays off. Notifications delivered while the app is
/// backgrounded/closed are shown by the OS (Android tray) or the web service
/// worker; foreground delivery is already covered by the in-app realtime toast.
class PushService {
  PushService._();

  // Web Push (VAPID) public key from Firebase → Cloud Messaging.
  static const String _vapidKey =
      'BOuKd-BjvUc4cQO0tNMO_X9RLN55h4jCBY47QcD915E7z75JhtsFELZ7A3rqM7GSbibV3LMxhwQzYt8ifZpRoRE';

  static bool _inited = false;

  /// Initialize Firebase + request notification permission once at startup.
  static Future<void> init() async {
    if (_inited) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      // Re-register whenever FCM rotates the token.
      messaging.onTokenRefresh.listen(_upsertToken);
      _inited = true;
    } catch (_) {
      // No Firebase on this platform / not configured → push stays off.
      _inited = false;
    }
  }

  /// Register this device's token for the currently signed-in audience. Call
  /// after login (e.g. when the home screen mounts).
  static Future<void> syncToken() async {
    if (!_inited) await init();
    if (!_inited) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final token = kIsWeb
          ? await messaging.getToken(vapidKey: _vapidKey)
          : await messaging.getToken();
      if (token != null && token.isNotEmpty) await _upsertToken(token);
    } catch (_) {/* ignore — push just won't reach this device */}
  }

  static Future<void> _upsertToken(String token) async {
    try {
      final audience =
          AuthService.instance.isManagement ? 'management' : 'employee';
      final name = AuthService.instance.currentUser?.fullName;
      final platform = kIsWeb
          ? 'web'
          : (defaultTargetPlatform == TargetPlatform.android
              ? 'android'
              : 'other');
      await Supabase.instance.client.from('device_tokens').upsert(
        {
          'token': token,
          'audience': audience,
          'user_name': name,
          'platform': platform,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (_) {/* table may not exist yet, or offline — ignore */}
  }
}
