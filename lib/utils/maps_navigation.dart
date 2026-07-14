import 'package:url_launcher/url_launcher.dart';

import '../models/gps_fix.dart';
import '../utils/lead_location_parser.dart';

/// Opens Google Maps at a property location.
abstract final class MapsNavigation {
  /// Opens Google Maps showing the pinned location at [lat],[lng] (a map pin,
  /// not turn-by-turn navigation).
  static Future<bool> navigateTo({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> navigateFromGpsString(
    String gps, {
    String? label,
  }) async {
    final fix = GpsFix.tryParse(gps);
    if (fix != null) {
      return navigateTo(
        lat: fix.latitude,
        lng: fix.longitude,
        label: label,
      );
    }
    final point = parseLeadGps(gps);
    if (point == null) return false;
    return navigateTo(
      lat: point.latitude,
      lng: point.longitude,
      label: label,
    );
  }
}
