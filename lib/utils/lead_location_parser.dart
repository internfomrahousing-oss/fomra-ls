import 'package:latlong2/latlong.dart';

/// Parses GPS strings saved from add-lead (e.g. `12.345678° N, 80.123456° E`).
LatLng? parseLeadGps(String gps) {
  final trimmed = gps.trim();
  if (trimmed.isEmpty) return null;

  final degMatch = RegExp(
    r'([\d.]+)\s*°?\s*N.*?([\d.]+)\s*°?\s*E',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (degMatch != null) {
    final lat = double.tryParse(degMatch.group(1)!);
    final lng = double.tryParse(degMatch.group(2)!);
    if (lat != null && lng != null) return LatLng(lat, lng);
  }

  final parts = trimmed.split(',');
  if (parts.length >= 2) {
    final lat = double.tryParse(parts[0].replaceAll(RegExp(r'[^\d.\-]'), ''));
    final lng = double.tryParse(parts[1].replaceAll(RegExp(r'[^\d.\-]'), ''));
    if (lat != null && lng != null) return LatLng(lat, lng);
  }
  return null;
}

/// Converts land extent text (acres, cents, sqft) to square feet.
double? parseLandExtentSqft(String extent) {
  final lower = extent.trim().toLowerCase();
  if (lower.isEmpty) return null;

  final numMatch = RegExp(r'([\d.]+)').firstMatch(lower);
  if (numMatch == null) return null;
  final n = double.tryParse(numMatch.group(1)!);
  if (n == null || n <= 0) return null;

  if (lower.contains('acre')) return n * 43560;
  if (lower.contains('hectare') || lower.contains('hect')) return n * 107639;
  if (lower.contains('ground')) return n * 2400;   // TN unit: 1 ground = 2400 sqft
  if (lower.contains('cent')) return n * 435.6;
  if (lower.contains('sq')) return n;
  return n; // bare number → assume already in sqft
}

/// Extracts numeric road width in feet from lead text.
double? parseRoadWidthFt(String roadWidth) {
  final match = RegExp(r'([\d.]+)').firstMatch(roadWidth.trim());
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}
