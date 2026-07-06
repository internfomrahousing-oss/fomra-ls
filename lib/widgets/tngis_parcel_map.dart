import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';

import '../services/api_client.dart';

/// Tamil Nilam–style cadastral map: satellite imagery + green survey boundaries.
class TngisParcelMap extends StatefulWidget {
  final LatLng? center;
  final double height;
  final void Function(LatLng point, TngisParcelPick? pick) onTap;

  const TngisParcelMap({
    super.key,
    required this.center,
    required this.onTap,
    this.height = 400,
  });

  @override
  State<TngisParcelMap> createState() => _TngisParcelMapState();
}

class TngisParcelPick {
  final String survey;
  final String? subDivision;
  final String? village;
  final Map<String, String> fields;
  final bool containsPoint;

  const TngisParcelPick({
    required this.survey,
    this.subDivision,
    this.village,
    this.fields = const {},
    this.containsPoint = false,
  });
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

bool _pointInRingStatic(double lon, double lat, List<LatLng> ring) {
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

class _TngisParcel {
  final String id;
  final String survey;
  final String? subDivision;
  final List<List<LatLng>> rings;
  final Map<String, String> fields;

  _TngisParcel({
    required this.id,
    required this.survey,
    required this.rings,
    this.subDivision,
    this.fields = const {},
  });

  List<LatLng> get ring => rings.isNotEmpty ? rings.first : const [];

  LatLng get centroid {
    final r = ring;
    if (r.isEmpty) return const LatLng(0, 0);
    var lat = 0.0;
    var lon = 0.0;
    for (final p in r) {
      lat += p.latitude;
      lon += p.longitude;
    }
    return LatLng(lat / r.length, lon / r.length);
  }

  double get areaDegrees {
    if (rings.isEmpty) return double.infinity;
    return rings.map(_ringArea).reduce((a, b) => a < b ? a : b);
  }

  bool contains(LatLng tap) {
    for (final r in rings) {
      if (_pointInRingStatic(tap.longitude, tap.latitude, r)) return true;
    }
    return false;
  }

  String get label {
    final sub = subDivision?.trim();
    if (sub != null && sub.isNotEmpty && sub != '-') {
      return '$survey/$sub';
    }
    return survey;
  }
}

class _TngisParcelMapState extends State<TngisParcelMap> {
  final MapController _controller = MapController();
  final List<_TngisParcel> _parcels = [];
  String? _selectedId;
  bool _loading = false;
  bool _mapReady = false;
  Timer? _reloadDebounce;
  LatLng? _lastLoadCenter;
  double _lastZoom = 16;

  static const _satelliteUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  @override
  void didUpdateWidget(covariant TngisParcelMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.center != null &&
        (oldWidget.center?.latitude != widget.center?.latitude ||
            oldWidget.center?.longitude != widget.center?.longitude)) {
      _moveTo(widget.center!, animate: true);
      _scheduleParcelLoad();
    }
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    super.dispose();
  }

  void _moveTo(LatLng loc, {bool animate = false}) {
    if (!_mapReady) return;
    final zoom = (_controller.camera.zoom).clamp(15.0, 19.0);
    if (animate) {
      _controller.move(loc, zoom < 16 ? 16 : zoom);
    } else {
      _controller.move(loc, zoom);
    }
  }

  void _scheduleParcelLoad() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 450), _loadParcels);
  }

  Future<void> _loadParcels() async {
    if (!_mapReady) return;
    final c = _controller.camera.center;
    final zoom = _controller.camera.zoom;
    if (_lastLoadCenter != null &&
        _distanceM(c, _lastLoadCenter!) < 30 &&
        (zoom - _lastZoom).abs() < 0.4) {
      return;
    }
    _lastLoadCenter = c;
    _lastZoom = zoom;

    setState(() => _loading = true);
    try {
      final data = await ApiClient.get(
        '/api/tnlands/tngis/parcels?lat=${c.latitude}&lon=${c.longitude}&zoom=$zoom',
        timeout: const Duration(seconds: 45),
      );
      final feats = (data['features'] as List<dynamic>? ?? []);
      final loaded = _parcelsFromFeatures(feats);
      if (!mounted) return;
      setState(() {
        _parcels
          ..clear()
          ..addAll(loaded);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_TngisParcel> _parcelsFromFeatures(List<dynamic> feats) {
    final loaded = <_TngisParcel>[];
    for (var i = 0; i < feats.length; i++) {
      final f = feats[i] as Map<String, dynamic>;
      final rings = _ringsFromGeometry(f['geometry'] as Map<String, dynamic>?);
      if (rings.isEmpty) continue;
      final props = (f['properties'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      final survey = props['survey_number'] ?? '';
      if (survey.isEmpty) continue;
      final sub = props['sub_division'];
      loaded.add(_TngisParcel(
        id: '${survey}_${sub ?? ''}_$i',
        survey: survey,
        subDivision: sub,
        rings: rings,
        fields: {
          if (props['district_name']?.isNotEmpty == true)
            'District': props['district_name']!,
          if (props['taluk_name']?.isNotEmpty == true)
            'Taluk': props['taluk_name']!,
          if (props['village_name']?.isNotEmpty == true)
            'Village': props['village_name']!,
          'Survey Number': survey,
          if (sub != null && sub.isNotEmpty && sub != '-') 'Sub Division': sub,
        },
      ));
    }
    return loaded;
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

  Future<void> _loadParcelsAt(LatLng c) async {
    try {
      final data = await ApiClient.get(
        '/api/tnlands/tngis/parcels?lat=${c.latitude}&lon=${c.longitude}&zoom=18&radius=300',
        timeout: const Duration(seconds: 45),
      );
      final loaded = _parcelsFromFeatures(data['features'] as List<dynamic>? ?? []);
      if (!mounted || loaded.isEmpty) return;
      final merged = <String, _TngisParcel>{
        for (final p in _parcels) p.id: p,
      };
      for (final p in loaded) {
        merged[p.id] = p;
      }
      setState(() {
        _parcels
          ..clear()
          ..addAll(merged.values);
      });
    } catch (_) {}
  }

  TngisParcelPick? _pickAt(LatLng tap) {
    final hits = _parcels.where((p) => p.contains(tap)).toList();
    if (hits.isEmpty) return null;
    hits.sort((a, b) => a.areaDegrees.compareTo(b.areaDegrees));
    final hit = hits.first;
    return TngisParcelPick(
      survey: hit.survey,
      subDivision: hit.subDivision,
      village: hit.fields['Village'],
      fields: hit.fields,
      containsPoint: true,
    );
  }

  double _distanceM(LatLng a, LatLng b) {
    const r = 6371000.0;
    const p = math.pi / 180.0;
    final lat1 = a.latitude * p;
    final lat2 = b.latitude * p;
    final h = math.sin((lat2 - lat1) / 2) * math.sin((lat2 - lat1) / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin((b.longitude - a.longitude) * p / 2) *
            math.sin((b.longitude - a.longitude) * p / 2);
    return 2 * r * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  Future<void> _handleTap(LatLng point) async {
    var local = _pickAt(point);
    if (local == null) {
      await _loadParcelsAt(point);
      local = _pickAt(point);
    }
    if (!mounted) return;
    setState(() => _selectedId = local != null
        ? _parcels
            .firstWhere(
              (p) => p.survey == local!.survey && p.subDivision == local.subDivision,
              orElse: () => _parcels.first,
            )
            .id
        : null);
    widget.onTap(point, local);
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.center ?? const LatLng(13.0827, 80.2707);
    final showLabels = _mapReady && _controller.camera.zoom >= 16;

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 16,
              minZoom: 10,
              maxZoom: 19,
              onMapReady: () {
                setState(() => _mapReady = true);
                if (widget.center != null) _moveTo(widget.center!);
                _scheduleParcelLoad();
              },
              onTap: (_, p) => _handleTap(p),
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) _scheduleParcelLoad();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _satelliteUrl,
                userAgentPackageName: 'in.fomrahousing.fomrals',
                tileProvider: CancellableNetworkTileProvider(),
                keepBuffer: 4,
                panBuffer: 1,
              ),
              PolygonLayer(
                polygons: _parcels.expand((p) {
                  final selected = p.id == _selectedId;
                  return p.rings.map((ring) => Polygon(
                    points: ring,
                    color: selected
                        ? const Color(0xFFFFEB3B).withValues(alpha: 0.35)
                        : const Color(0xFF00E676).withValues(alpha: 0.12),
                    borderColor: selected
                        ? const Color(0xFFFFC107)
                        : const Color(0xFF00E676),
                    borderStrokeWidth: selected ? 3 : 1.5,
                  ));
                }).toList(),
              ),
              if (showLabels)
                MarkerLayer(
                  markers: _parcels.map((p) {
                    return Marker(
                      point: p.centroid,
                      width: 56,
                      height: 20,
                      child: Text(
                        p.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFFF59D),
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 2),
                            Shadow(color: Colors.black, offset: Offset(1, 1)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              if (widget.center != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: widget.center!,
                      width: 24,
                      height: 24,
                      child: const Icon(Icons.place, color: Color(0xFFE53935), size: 28),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Tamil Nilam · TNGIS',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Column(
              children: [
                _mapBtn(Icons.add, () {
                  _controller.move(
                    _controller.camera.center,
                    (_controller.camera.zoom + 1).clamp(10, 19),
                  );
                  _scheduleParcelLoad();
                }),
                const SizedBox(height: 6),
                _mapBtn(Icons.remove, () {
                  _controller.move(
                    _controller.camera.center,
                    (_controller.camera.zoom - 1).clamp(10, 19),
                  );
                  _scheduleParcelLoad();
                }),
              ],
            ),
          ),
          if (_loading)
            const Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text('Loading survey boundaries…', style: TextStyle(fontSize: 11)),
                  ),
                ),
              ),
            ),
          if (!_loading && _parcels.isEmpty && _mapReady)
            const Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      'Zoom in to see survey plots · tap a green boundary',
                      style: TextStyle(fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _mapBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        ),
      ),
    );
  }
}
