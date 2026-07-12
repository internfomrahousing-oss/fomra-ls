import 'package:url_launcher/url_launcher.dart';

import '../models/gps_fix.dart';
import '../utils/lead_location_parser.dart';

/// Opens Google Maps navigation to a property location.
abstract final class MapsNavigation {
  /// Turn-by-turn directions to [lat],[lng].
  static Future<bool> navigateTo({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final q = label != null && label.trim().isNotEmpty
        ? Uri.encodeComponent(label.trim())
        : '$lat,$lng';
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=&travelmode=driving&dir_action=navigate',
    );
    // Fallback search if dir fails.
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    final search = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng($q)',
    );
    return launchUrl(search, mode: LaunchMode.externalApplication);
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
