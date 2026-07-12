import 'package:latlong2/latlong.dart';

/// Verified live GPS fix. Manual map pins are never accepted as a GpsFix.
class GpsFix {
  final double latitude;
  final double longitude;
  final double accuracyMeters;
  final DateTime timestamp;
  final bool isLive;

  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
    required this.timestamp,
    this.isLive = true,
  });

  LatLng get point => LatLng(latitude, longitude);

  /// Storage format in `land_leads.gps_coordinates`.
  /// `LIVE|<lat>|<lng>|<accuracy_m>|<iso8601>`
  String toStorage() =>
      'LIVE|${latitude.toStringAsFixed(6)}|${longitude.toStringAsFixed(6)}|'
      '${accuracyMeters.toStringAsFixed(1)}|${timestamp.toUtc().toIso8601String()}';

  String get displayCoords =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

  String get summaryLabel =>
      '$displayCoords · ±${accuracyMeters.toStringAsFixed(0)} m · '
      '${timestamp.toLocal().toIso8601String().substring(0, 19)}';

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_meters': accuracyMeters,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'is_live': isLive,
      };

  factory GpsFix.fromJson(Map<String, dynamic> j) => GpsFix(
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        accuracyMeters: (j['accuracy_meters'] as num?)?.toDouble() ?? 0,
        timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ??
            DateTime.now().toUtc(),
        isLive: j['is_live'] as bool? ?? true,
      );

  /// Parse LIVE|… storage, or legacy plain lat/lng (treated as unverified).
  static GpsFix? tryParse(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('LIVE|')) {
      final parts = t.split('|');
      if (parts.length >= 5) {
        final lat = double.tryParse(parts[1]);
        final lng = double.tryParse(parts[2]);
        final acc = double.tryParse(parts[3]) ?? 0;
        final ts = DateTime.tryParse(parts[4]) ?? DateTime.now().toUtc();
        if (lat != null && lng != null) {
          return GpsFix(
            latitude: lat,
            longitude: lng,
            accuracyMeters: acc,
            timestamp: ts.toUtc(),
            isLive: true,
          );
        }
      }
    }
    return null;
  }

  bool get isAcceptableAccuracy =>
      accuracyMeters <= 0 || accuracyMeters <= 150;
}
