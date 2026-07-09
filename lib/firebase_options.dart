// Firebase configuration for FomraLS (web + Android).
//
// These are client-side identifiers (not secrets) — the web/Android API keys
// are meant to ship in the app. iOS is not configured; push there needs an
// Apple Developer account + APNs. See push-notifications-fcm project notes.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        // iOS/macOS/etc. not configured — the caller guards initialization so
        // this simply means "no push on this platform".
        throw UnsupportedError(
          'Firebase is not configured for $defaultTargetPlatform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDZxkdxEO9HwSP0TuMZwAkISIcsAegasDs',
    appId: '1:450345313339:web:996c2ccf40b0b70f21a81e',
    messagingSenderId: '450345313339',
    projectId: 'fomrals',
    authDomain: 'fomrals.firebaseapp.com',
    storageBucket: 'fomrals.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAZDdcAO_Sxo0u3SXhm9G6tjyeF3tiKAYY',
    appId: '1:450345313339:android:4bb0c9c2e11430bc21a81e',
    messagingSenderId: '450345313339',
    projectId: 'fomrals',
    storageBucket: 'fomrals.firebasestorage.app',
  );
}
