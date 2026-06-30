import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';

/// Full-screen map picker. Tap to drop a pin (or use current location),
/// then Save to return the chosen [LatLng].
class LeadLocationPickerScreen extends StatefulWidget {
  final LatLng? initial;

  const LeadLocationPickerScreen({super.key, this.initial});

  @override
  State<LeadLocationPickerScreen> createState() =>
      _LeadLocationPickerScreenState();
}

class _LeadLocationPickerScreenState extends State<LeadLocationPickerScreen> {
  static const _kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _kDefaultCenter = LatLng(13.0827, 80.2707); // Chennai

  final MapController _mapController = MapController();
  LatLng? _picked;
  bool _mapReady = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.initial;
  }

  void _centerOn(LatLng point) {
    if (!_mapReady) return;
    _mapController.move(point, _mapController.camera.zoom.clamp(13.0, 18.0));
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _snack('Location services are disabled. Enable GPS.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Location permission denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _picked = loc);
      _centerOn(loc);
    } catch (e) {
      _snack('Could not get location: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    return Scaffold(
      backgroundColor: context.fomraPageBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Set Land Location',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: picked == null
                ? null
                : () => Navigator.pop(context, picked),
            child: Text(
              'Save',
              style: TextStyle(
                color: picked == null ? Colors.white54 : Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: picked ?? _kDefaultCenter,
                    initialZoom: picked != null ? 16 : 11,
                    onMapReady: () => setState(() => _mapReady = true),
                    onTap: (_, point) => setState(() => _picked = point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _kOsmTileUrl,
                      userAgentPackageName: 'in.fomrahousing.fomrals',
                    ),
                    MarkerLayer(markers: [
                      if (picked != null)
                        Marker(
                          point: picked,
                          width: 40,
                          height: 48,
                          child: const Icon(Icons.location_on,
                              color: Color(0xFFE53935), size: 40),
                        ),
                    ]),
                  ],
                ),
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        picked == null
                            ? 'Tap on the map to place the land pin'
                            : '${picked.latitude.toStringAsFixed(5)}° N, ${picked.longitude.toStringAsFixed(5)}° E',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: Text(_locating ? 'Getting location…' : 'Use my current location'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
