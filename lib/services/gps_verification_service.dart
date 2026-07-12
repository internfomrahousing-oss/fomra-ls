import 'package:geolocator/geolocator.dart';

import '../models/gps_fix.dart';

/// Live-GPS-only capture. Rejects manual pins / typed coordinates.
abstract final class GpsVerificationService {
  /// Throws [GpsVerificationException] when live GPS cannot be obtained.
  static Future<GpsFix> captureLive({
    Duration timeLimit = const Duration(seconds: 20),
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const GpsVerificationException(
        'Location services are disabled. Enable GPS and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const GpsVerificationException('Location permission denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const GpsVerificationException(
        'Location permission permanently denied. Enable it in settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.best,
        timeLimit: timeLimit,
        // Prefer a fresh reading over a cached last-known fix.
        distanceFilter: 0,
      ),
    );

    // Reject mock locations when the platform reports them.
    try {
      if (position.isMocked) {
        throw const GpsVerificationException(
          'Mock / manually pinned locations are not allowed. Use live GPS.',
        );
      }
    } catch (e) {
      if (e is GpsVerificationException) rethrow;
      // isMocked unsupported on some platforms — continue.
    }

    final fix = GpsFix(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      timestamp: position.timestamp.toUtc(),
      isLive: true,
    );

    if (!fix.isAcceptableAccuracy) {
      throw GpsVerificationException(
        'GPS accuracy too low (±${fix.accuracyMeters.toStringAsFixed(0)} m). '
        'Move outdoors and try again.',
      );
    }

    return fix;
  }
}

class GpsVerificationException implements Exception {
  final String message;
  const GpsVerificationException(this.message);

  @override
  String toString() => message;
}
