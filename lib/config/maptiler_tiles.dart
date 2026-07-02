import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

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

  /// Satellite imagery (MapTiler serves this tileset as JPG).
  static const satelliteStyle = 'satellite-v2';

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
      keepBuffer: 2,
    );
  }
}
