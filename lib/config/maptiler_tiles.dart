import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

/// MapTiler raster tiles (OpenMapTiles / OMT schema).
class MapTilerTiles {
  MapTilerTiles._();

  static const apiKey = String.fromEnvironment(
    'MAPTILER_API_KEY',
    defaultValue: 'MHsQC3BsvXE332lr3wT7',
  );

  static const _base = 'https://api.maptiler.com/maps';

  /// Current MapTiler streets style (PNG).
  static const standardStyle = 'streets-v4';

  /// Satellite hybrid imagery (satellite + labels, served as JPG).
  static const satelliteStyle = 'hybrid';

  static bool get isConfigured => apiKey.isNotEmpty;

  static String rasterUrl(
    String styleId, {
    String format = 'png',
  }) =>
      '$_base/$styleId/256/{z}/{x}/{y}.$format?key=$apiKey';

  static String get standard => rasterUrl(standardStyle);
  static String get satellite => rasterUrl(satelliteStyle, format: 'jpg');

  static String urlFor({required bool satelliteLayer}) =>
      satelliteLayer ? satellite : standard;

  static const attribution = '© MapTiler © OpenStreetMap contributors';

  /// Used when MapTiler is unavailable (quota, network, etc.).
  static const standardFallback =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Esri World Imagery — `{z}/{y}/{x}` tile order.
  static const satelliteFallback =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  static TileLayer tileLayer({
    required String urlTemplate,
    bool satelliteLayer = false,
    String packageName = 'in.fomrahousing.fomrals',
  }) {
    return TileLayer(
      key: ValueKey(urlTemplate),
      urlTemplate: urlTemplate,
      fallbackUrl: satelliteLayer ? satelliteFallback : standardFallback,
      userAgentPackageName: packageName,
      maxZoom: 22,
      // Cancel off-screen tile requests so the visible tiles load first — the
      // biggest perceived-speed win for flutter_map (esp. on web).
      tileProvider: CancellableNetworkTileProvider(),
      // Keep more tiles around and preload a ring so panning/first paint is
      // smoother instead of loading tile-by-tile.
      keepBuffer: 4,
      panBuffer: 1,
    );
  }
}
