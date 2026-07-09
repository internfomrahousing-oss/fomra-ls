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
      // NOTE: do NOT request permission here. This runs at startup with no user
      // gesture, and browsers then switch the site to "quiet" mode and suppress
      // the popup for good. Permission is requested only from a real gesture
      // (login tap / bell tap) via promptAndSync().
      // Re-register whenever FCM rotates the token.
      messaging.onTokenRefresh.listen(_upsertToken);
      _inited = true;
      debugPrint('🔔PUSH: Firebase init OK');
    } catch (e) {
      // No Firebase on this platform / not configured → push stays off.
      _inited = false;
      debugPrint('🔔PUSH: init FAILED: $e');
    }
  }

  /// Request notification permission from a USER GESTURE (browsers suppress the
  /// auto prompt on page load), then register the token. Call from a tap — e.g.
  /// the notification bell.
  static Future<void> promptAndSync() async {
    try {
      if (!_inited) await init();
      if (!_inited) return;
      await FirebaseMessaging.instance.requestPermission();
      await syncToken();
    } catch (_) {/* push just stays off */}
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
      debugPrint('🔔PUSH: got token = ${token == null ? "null" : "${token.substring(0, 12)}…"}');
      if (token != null && token.isNotEmpty) await _upsertToken(token);
    } catch (e) {
      debugPrint('🔔PUSH: getToken FAILED: $e');
    }
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
      debugPrint('🔔PUSH: token saved to device_tokens ($audience)');
    } catch (e) {
      debugPrint('🔔PUSH: save to device_tokens FAILED: $e');
    }
  }
}
