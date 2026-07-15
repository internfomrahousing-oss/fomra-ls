import 'package:latlong2/latlong.dart';

import '../utils/lead_auto_notes.dart';
import 'api_client.dart';

/// Nearby map features around a site, from the same Overpass-backed POI service
/// the Market Intelligence infrastructure tab uses — so both read one source.
abstract final class NearbyFeaturesService {
  /// Radius for a lead's automatic notes. The endpoint only accepts 2, 5 or 10.
  static const notesRadiusKm = 2;

  /// Features grouped by the service's category names (`Water Bodies`,
  /// `Schools`, `Cemeteries`, …), ready for [LeadAutoNotes.generate].
  static Future<Map<String, List<NearbyFeature>>> fetch(
    LatLng at, {
    int radiusKm = notesRadiusKm,
  }) async {
    final data = await ApiClient.post(
      '/api/poi/infrastructure',
      {'lat': at.latitude, 'lon': at.longitude, 'radiusKm': radiusKm},
      auth: false,
    ).timeout(const Duration(seconds: 35));

    final places = (data['places'] as Map?)?.cast<String, dynamic>() ?? {};
    final result = <String, List<NearbyFeature>>{};

    places.forEach((category, raw) {
      if (raw is! List) return;
      final features = <NearbyFeature>[
        for (final entry in raw)
          if (entry is Map)
            NearbyFeature(
              name: (entry['name'] ?? '').toString(),
              distanceKm: (entry['distance'] as num?)?.toDouble(),
            ),
      ];
      if (features.isNotEmpty) result[category] = features;
    });

    return result;
  }
}
