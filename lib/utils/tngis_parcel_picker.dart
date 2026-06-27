import 'package:latlong2/latlong.dart';

/// Result of picking a TNGIS cadastral parcel at a map point.
class TngisParcelPickResult {
  final String survey;
  final String? subDivision;
  final bool containsPoint;

  const TngisParcelPickResult({
    required this.survey,
    this.subDivision,
    this.containsPoint = false,
  });
}

/// Point-in-polygon pick from TNGIS WFS GeoJSON features (same geometry as GI Viewer).
TngisParcelPickResult? pickTngisParcelFromFeatures(
  LatLng tap,
  List<dynamic> features,
) {
  final hits = <_Hit>[];
  for (final raw in features) {
    if (raw is! Map<String, dynamic>) continue;
    final props = (raw['properties'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    final survey = props['survey_number'] ?? '';
    if (survey.isEmpty) continue;
    final sub = _subFromProps(props);
    final rings = _ringsFromGeometry(raw['geometry'] as Map<String, dynamic>?);
    for (final ring in rings) {
      if (!_pointInRing(tap.longitude, tap.latitude, ring)) continue;
      hits.add(_Hit(
        survey: survey,
        subDivision: sub,
        area: _ringArea(ring),
      ));
      break;
    }
  }
  if (hits.isEmpty) return null;
  hits.sort((a, b) => a.area.compareTo(b.area));
  final best = hits.first;
  return TngisParcelPickResult(
    survey: best.survey,
    subDivision: best.subDivision,
    containsPoint: true,
  );
}

class _Hit {
  final String survey;
  final String? subDivision;
  final double area;

  _Hit({required this.survey, this.subDivision, required this.area});
}

List<List<LatLng>> _ringsFromGeometry(Map<String, dynamic>? geom) {
  if (geom == null) return [];
  final type = geom['type'] as String?;
  final out = <List<LatLng>>[];

  List<LatLng> ringFromCoords(List<dynamic>? coords) {
    if (coords == null || coords.length < 3) return [];
    return coords
        .map((c) {
          final pair = c as List<dynamic>;
          return LatLng(
            (pair[1] as num).toDouble(),
            (pair[0] as num).toDouble(),
          );
        })
        .toList();
  }

  if (type == 'Polygon') {
    final rings = geom['coordinates'] as List<dynamic>?;
    if (rings != null && rings.isNotEmpty) {
      final r = ringFromCoords(rings[0] as List<dynamic>?);
      if (r.isNotEmpty) out.add(r);
    }
  } else if (type == 'MultiPolygon') {
    final polys = geom['coordinates'] as List<dynamic>?;
    if (polys != null) {
      for (final poly in polys) {
        final rings = poly as List<dynamic>?;
        if (rings == null || rings.isEmpty) continue;
        final r = ringFromCoords(rings[0] as List<dynamic>?);
        if (r.isNotEmpty) out.add(r);
      }
    }
  }
  return out;
}

double _ringArea(List<LatLng> ring) {
  if (ring.length < 3) return double.infinity;
  var area = 0.0;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    area += (ring[j].longitude + ring[i].longitude) *
        (ring[j].latitude - ring[i].latitude);
  }
  return area.abs() / 2;
}

bool _pointInRing(double lon, double lat, List<LatLng> ring) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final yi = ring[i].latitude;
    final xi = ring[i].longitude;
    final yj = ring[j].latitude;
    final xj = ring[j].longitude;
    final denom = (yj - yi) == 0 ? 1e-15 : (yj - yi);
    final intersect = ((yi > lat) != (yj > lat)) &&
        (lon < (xj - xi) * (lat - yi) / denom + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

String? _subFromProps(Map<String, String> props) {
  final survey = props['survey_number']?.trim() ?? '';
  final subRaw = props['sub_division']?.trim();
  if (subRaw != null && subRaw.isNotEmpty && subRaw != '-' && subRaw != survey) {
    return subRaw;
  }
  final kide = props['kide']?.trim();
  if (kide == null || kide.isEmpty || kide == '0' || !kide.contains('/')) return null;
  final parts = kide.split('/');
  if (parts.length < 2) return null;
  final kideSub = parts.sublist(1).join('/').trim();
  if (kideSub.isEmpty || kideSub == '-' || kideSub == survey) return null;
  final kideSurvey = parts[0].trim();
  if (survey.isNotEmpty && kideSurvey.isNotEmpty && kideSurvey != survey) return null;
  return kideSub;
}
