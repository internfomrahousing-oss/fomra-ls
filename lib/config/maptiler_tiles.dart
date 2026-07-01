import 'package:flutter_map/flutter_map.dart';

/// MapTiler raster tiles (OpenMapTiles / OMT schema).
class MapTilerTiles {
  MapTilerTiles._();

  static const apiKey = String.fromEnvironment(
    'MAPTILER_API_KEY',
    defaultValue: 'MHsQC3BsvXE332lr3wT7',
  );

  static const _base = 'https://api.maptiler.com/maps';

  /// Clean base map for standard view.
  static const standardStyle = 'basic-v2';

  /// Streets style — highlights roads, rail, and transit (OMT transport layer).
  static const transportStyle = 'streets-v4';

  static bool get isConfigured => apiKey.isNotEmpty;

  static String rasterUrl(String styleId) =>
      '$_base/$styleId/256/{z}/{x}/{y}.png?key=$apiKey';

  static String get standard => rasterUrl(standardStyle);
  static String get transport => rasterUrl(transportStyle);

  static String urlFor({required bool transportLayer}) =>
      transportLayer ? transport : standard;

  static const attribution = '© MapTiler © OpenStreetMap contributors';

  static TileLayer tileLayer({
    required String urlTemplate,
    String packageName = 'in.fomrahousing.fomrals',
  }) {
    return TileLayer(
      urlTemplate: urlTemplate,
      userAgentPackageName: packageName,
    );
  }
}
