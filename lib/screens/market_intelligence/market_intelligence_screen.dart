import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import '../../services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
import '../../widgets/fmb_sketch_viewer.dart';
import '../../widgets/patta_document_preview.dart';
import '../../widgets/patta_html_preview.dart';
import '../../services/app_store.dart';
import '../../models/land_lead.dart';

// â”€â”€ POI category definitions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PoiCategory {
  final String name;
  final IconData icon;
  final Color color;
  final String tag;
  final String value;
  const _PoiCategory(this.name, this.icon, this.color, this.tag, this.value);
}

const _kTransportPoiNames = [
  'Railway Stations',
  'Metro Stations',
  'Bus Terminals',
];

enum _MarketMapLayer { standard, transport }

const _kOsmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const _kOsmTransportRailUrl =
    'https://tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png';

const _kCategories = [
  _PoiCategory('Schools', Icons.school_outlined, Color(0xFF1565C0), 'amenity', 'school'),
  _PoiCategory('Hospitals', Icons.local_hospital_outlined, Color(0xFFD32F2F), 'amenity', 'hospital'),
  _PoiCategory('Railway Stations', Icons.train_outlined, Color(0xFF37474F), 'railway', 'station'),
  _PoiCategory('Metro Stations', Icons.subway_outlined, Color(0xFF4527A0), 'station', 'subway'),
  _PoiCategory('Bus Terminals', Icons.directions_bus_outlined, Color(0xFF1B5E20), 'amenity', 'bus_station'),
  _PoiCategory('IT Parks', Icons.computer_outlined, Color(0xFF006064), 'office', 'it'),
  _PoiCategory('Industrial Areas', Icons.factory_outlined, Color(0xFF4E342E), 'landuse', 'industrial'),
  _PoiCategory('Malls', Icons.local_mall_outlined, Color(0xFFAD1457), 'shop', 'mall'),
  _PoiCategory('Banks', Icons.account_balance_outlined, Color(0xFFE65100), 'amenity', 'bank'),
  _PoiCategory('Petrol Stations', Icons.local_gas_station_outlined, Color(0xFF558B2F), 'amenity', 'fuel'),
  _PoiCategory('Govt. Offices', Icons.account_balance_wallet_outlined, Color(0xFF795548), 'amenity', 'townhall'),
  _PoiCategory('Worship Places', Icons.temple_hindu_outlined, Color(0xFF880E4F), 'amenity', 'place_of_worship'),
];

// â”€â”€ Valuation result â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ValuationResult {
  final double recommendedPurchasePrice;
  final double recommendedSellingPrice;
  final double expectedMargin;
  final int investmentScore;
  final int riskScore;
  final String recommendation;

  _ValuationResult({
    required this.recommendedPurchasePrice,
    required this.recommendedSellingPrice,
    required this.expectedMargin,
    required this.investmentScore,
    required this.riskScore,
    required this.recommendation,
  });
}


// â”€â”€ Main Screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class MarketIntelligenceScreen extends StatefulWidget {
  final bool isTab;
  const MarketIntelligenceScreen({super.key, this.isTab = false});

  @override
  State<MarketIntelligenceScreen> createState() =>
      _MarketIntelligenceScreenState();
}

class _MarketIntelligenceScreenState extends State<MarketIntelligenceScreen> {
  // Location â€“ GPS
  Position? _position;
  bool _fetchingLocation = false;
  String? _locationError;
  final MapController _mapController = MapController();
  bool _mapReady = false;
  bool _mapFullScreen = false;
  _MarketMapLayer _mapLayer = _MarketMapLayer.standard;
  LatLng? _tappedPoint;

  // Location â€“ Search
  final bool _searchMode = false;
  LatLng? _searchedLocation;
  bool _searchingLocation = false;
  String? _searchError;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _showSearchResults = false;

  // Lead-based Mode
  bool _isLeadBasedMode = false;
  String? _selectedLeadId;

  // POI
  int _selectedRadius = 2;
  Map<String, int> _poiCounts = {};
  Map<String, List<Map<String, dynamic>>> _poiPlaces = {};
  bool _collectingPois = false;
  String? _poiError;
  bool _poisCollected = false;
  Map<String, double> _infraScoreMap = {};

  // Valuation inputs
  final _roadWidthCtrl = TextEditingController();
  final _landSizeCtrl = TextEditingController();
  String _locationCategory = 'Urban';
  String _developmentPotential = 'Medium';
  _ValuationResult? _valuationResult;

  // Competitor Projects (MagicBricks, 99acres, Housing.com)
  List<Map<String, dynamic>> _mbListings = [];
  bool _fetchingMb = false;
  String? _mbError;
  String? _mbPartialWarning;
  String _mbSource = 'Property Portals';
  String _compFilter = 'All';   // All | Ongoing | Completed | Plot | Old
  int _oldYearsFilter = 5;       // 2 | 5 | 10
  int _mbFetchSeq = 0;

  // EC & Patta – location data passed to the section widget
  String? _detectedDistrict;
  String? _detectedTaluk;
  String? _detectedVillage;
  String? _tngisSurvey;
  String? _tngisSubDiv;
  String? _tngisDc;
  String? _tngisTc;
  String? _tngisVc;
  String? _tngisGiViewerUrl;
  Map<String, dynamic>? _tngisGiServices;
  String? _tngisUlpin;
  String? _tngisCentroid;
  bool _tngisParcelLoading = false;
  String? _tngisParcelError;
  Map<String, String>? _tngisParcelPreview;
  List<_TngisSubdivisionRow> _tngisSubdivisions = [];
  bool _tngisFmbAvailable = false;
  String? _tngisFmbNote;

  // Default center shown before GPS resolves
  static const _kDefaultCenter = LatLng(13.0827, 80.2707);

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_onStoreUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectLocation();
    });
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_onStoreUpdate);
    _roadWidthCtrl.dispose();
    _landSizeCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onStoreUpdate() => setState(() {});

  LatLng? _parseGpsCoordinates(String coords) {
    if (coords.isEmpty) return null;
    try {
      String cleaned = coords
          .replaceAll('Â°', '')
          .replaceAll('N', '')
          .replaceAll('S', '-')
          .replaceAll('E', '')
          .replaceAll('W', '-');
      final parts = cleaned.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lon = double.tryParse(parts[1].trim());
        if (lat != null && lon != null) {
          return LatLng(lat, lon);
        }
      }
      final partsSpace = cleaned.trim().split(RegExp(r'\s+'));
      if (partsSpace.length == 2) {
        final lat = double.tryParse(partsSpace[0].trim());
        final lon = double.tryParse(partsSpace[1].trim());
        if (lat != null && lon != null) {
          return LatLng(lat, lon);
        }
      }
    } catch (_) {}
    return null;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Active location (GPS or searched) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  LatLng? get _activeLatLng =>
      _searchedLocation ??
      (_position != null
          ? LatLng(_position!.latitude, _position!.longitude)
          : null);

  // â”€â”€ GPS Location â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _detectLocation() async {
    setState(() {
      _fetchingLocation = true;
      _locationError = null;
    });
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Enable GPS in device settings.');
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied. Enable it in App Settings.');
      }
      if (perm == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() => _position = pos);
      if (_mapReady) {
        _mapController.move(
            LatLng(pos.latitude, pos.longitude), _zoomForRadius(_selectedRadius));
      }
      _fetchLocationDetails(LatLng(pos.latitude, pos.longitude));
      _collectPois();
      _fetchMagicBricksProjects();
    } catch (e) {
      setState(() =>
          _locationError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _fetchingLocation = false);
    }
  }

  // â”€â”€ Location Search (Nominatim) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _searchingLocation = true;
      _searchError = null;
      _searchResults = [];
      _showSearchResults = false;
    });
    try {
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query.trim())}&limit=5&addressdetails=1'),
        headers: {
          'User-Agent': 'FomraLS/1.0 (in.fomrahousing)',
          'Accept-Language': 'en',
        },
      );
      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List;
        setState(() {
          _searchResults = results.cast<Map<String, dynamic>>();
          _showSearchResults = _searchResults.isNotEmpty;
          if (_searchResults.isEmpty) {
            _searchError = 'No results found. Try a different search.';
          }
        });
      } else {
        setState(() => _searchError = 'Search failed. Check your connection.');
      }
    } catch (_) {
      setState(() => _searchError = 'No internet connection.');
    } finally {
      setState(() => _searchingLocation = false);
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat'] as String? ?? '') ?? 0;
    final lon = double.tryParse(result['lon'] as String? ?? '') ?? 0;
    final name = result['display_name'] as String? ?? 'Searched Location';
    final loc = LatLng(lat, lon);
    setState(() {
      _searchedLocation = loc;
      _showSearchResults = false;
      _searchCtrl.text = name.split(',').first.trim();
      _poisCollected = false;
      _poiCounts = {};
      _poiPlaces = {};
      _infraScoreMap = {};
      _valuationResult = null;
      _tngisSurvey = null;
      _tngisSubDiv = null;
      _tngisDc = null;
      _tngisTc = null;
      _tngisVc = null;
      _tngisGiServices = null;
      _tngisUlpin = null;
      _tngisCentroid = null;
      _tngisParcelPreview = null;
      _tngisSubdivisions = [];
      _tngisFmbAvailable = false;
      _tngisFmbNote = null;
    });
    if (_mapReady) {
      _mapController.move(_searchedLocation!, _zoomForRadius(_selectedRadius));
    }
    _fetchLocationDetails(loc);
    _collectPois();
    _fetchMagicBricksProjects();
  }

  void _handleMapTap(LatLng point) {
    setState(() {
      _searchedLocation = point;
      _tappedPoint = null;
      _poisCollected = false;
      _poiCounts = {};
      _poiPlaces = {};
      _infraScoreMap = {};
      _valuationResult = null;
      _tngisSurvey = null;
      _tngisSubDiv = null;
      _tngisDc = null;
      _tngisTc = null;
      _tngisVc = null;
      _tngisSubdivisions = [];
      _tngisFmbAvailable = false;
      _tngisFmbNote = null;
      _tngisParcelLoading = true;
      _tngisParcelError = null;
    });
    if (_mapReady) {
      _mapController.move(point, _mapController.camera.zoom);
    }
    _fetchLocationDetails(point);
    _fetchTngisParcelDetails(point);
    _collectPois();
    _fetchMagicBricksProjects();
  }

  /// Parse sub-division from TNGIS (often in kide e.g. 394/15C).
  String? _parseTngisSubDivision(String? subDiv, String? kide, String? survey) {
    final s = subDiv?.trim();
    final surveyTrim = survey?.trim() ?? '';
    if (s != null && s.isNotEmpty && s != '-' && s != surveyTrim) return s;
    final k = kide?.trim();
    if (k == null || k.isEmpty || k == '0' || !k.contains('/')) return null;
    final parts = k.split('/');
    if (parts.length < 2) return null;
    final kideSub = parts.sublist(1).join('/').trim();
    if (kideSub.isEmpty || kideSub == '-' || kideSub == surveyTrim) return null;
    final kideSurvey = parts[0].trim();
    if (surveyTrim.isNotEmpty && kideSurvey.isNotEmpty && kideSurvey != surveyTrim) {
      return null;
    }
    return kideSub;
  }

  /// Fetch survey no & sub-division from TNGIS for the tapped map point.
  Future<void> _fetchTngisParcelDetails(LatLng loc) async {
    setState(() {
      _tngisParcelLoading = true;
      _tngisParcelError = null;
    });
    try {
      final params = <String, String>{
        'lat': loc.latitude.toString(),
        'lon': loc.longitude.toString(),
      };

      final query = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final result = await ApiClient.get(
        '/api/tnlands/tngis/parcel?$query',
        timeout: const Duration(seconds: 90),
      );
      final fields = (result['fields'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString()));
      final survey = (result['surveyNumber'] ?? fields['Survey Number'])?.toString();
      final kideRaw = result['kide']?.toString() ?? fields['Kide'];
      final subdivisions = ((result['subdivisions'] as List<dynamic>? ?? [])
          .map((e) => _TngisSubdivisionRow.fromJson(e as Map<String, dynamic>))
          .where((r) => r.surveyNumber.isNotEmpty)
          .toList());

      // Sub at map point — prefer view_fmb subdivision polygon containing the tap.
      String? resolvedSub;
      String? resolvedKide = kideRaw;
      for (final row in subdivisions) {
        if (row.containsPoint && row.effectiveSubDivision != null) {
          resolvedSub = row.effectiveSubDivision;
          resolvedKide = row.kide ?? resolvedKide;
          break;
        }
      }
      resolvedSub ??= _parseTngisSubDivision(
        (result['subDivision'] ?? fields['Sub Division'])?.toString(),
        resolvedKide,
        survey,
      );

      setState(() {
        _tngisGiViewerUrl = result['giViewerUrl'] as String?;
        _tngisGiServices = (result['giServices'] as Map?)?.cast<String, dynamic>();
        _tngisUlpin = result['ulpin']?.toString();
        _tngisCentroid = result['centroid']?.toString();
        _tngisSurvey = survey?.isNotEmpty == true ? survey : null;
        _tngisSubDiv = resolvedSub;
        _tngisDc = fields['District Code'];
        _tngisTc = fields['Taluk Code'];
        _tngisVc = fields['Village Code'];
        _detectedDistrict = (result['district'] as String?)?.trim().isNotEmpty == true
            ? result['district'] as String
            : (fields['District']?.isNotEmpty == true ? fields['District'] : _detectedDistrict);
        _detectedTaluk = (result['taluk'] as String?)?.trim().isNotEmpty == true
            ? result['taluk'] as String
            : (fields['Taluk']?.isNotEmpty == true ? fields['Taluk'] : _detectedTaluk);
        _detectedVillage = (result['village'] as String?)?.trim().isNotEmpty == true
            ? result['village'] as String
            : (fields['Village']?.isNotEmpty == true ? fields['Village'] : _detectedVillage);
        _tngisParcelPreview = fields.isNotEmpty ? fields : null;
        _tngisParcelError = null;
        _tngisFmbAvailable = result['fmbAvailable'] == true;
        _tngisFmbNote = result['fmbNote']?.toString();
        _tngisSubdivisions = subdivisions;
        if (_tngisSubdivisions.isEmpty && _tngisSurvey != null) {
          _tngisSubdivisions = [
            _TngisSubdivisionRow(
              surveyNumber: _tngisSurvey!,
              subDivision: _tngisSubDiv,
              kide: (resolvedKide != null && resolvedKide.isNotEmpty && resolvedKide != '0')
                  ? resolvedKide
                  : null,
              fields: fields,
              containsPoint: result['containsPoint'] == true || _tngisSubDiv != null,
              fmbAvailable: result['fmbAvailable'] == true,
            ),
          ];
        }
      });
    } on ApiException catch (e) {
      setState(() {
        _tngisParcelError = e.message;
        _tngisSurvey = null;
        _tngisSubDiv = null;
        _tngisDc = null;
        _tngisTc = null;
        _tngisVc = null;
        _tngisGiServices = null;
        _tngisUlpin = null;
        _tngisCentroid = null;
        _tngisParcelPreview = null;
        _tngisSubdivisions = [];
      _tngisFmbAvailable = false;
      _tngisFmbNote = null;
      });
    } catch (e) {
      setState(() {
        _tngisParcelError = e.toString().replaceAll('Exception: ', '');
        _tngisGiServices = null;
        _tngisUlpin = null;
        _tngisCentroid = null;
        _tngisParcelPreview = null;
        _tngisSubdivisions = [];
      _tngisFmbAvailable = false;
      _tngisFmbNote = null;
      });
    } finally {
      if (mounted) setState(() => _tngisParcelLoading = false);
    }
  }

  // â”€â”€ POI Collection via Overpass API â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _collectPois() async {
    final loc = _activeLatLng;
    if (loc == null) return;
    setState(() {
      _collectingPois = true;
      _poiError = null;
      _poiCounts = {};
      _poiPlaces = {};
      _infraScoreMap = {};
      _poisCollected = false;
    });

    try {
      final data = await ApiClient.post(
        '/api/poi/infrastructure',
        {
          'lat': loc.latitude,
          'lon': loc.longitude,
          'radiusKm': _selectedRadius,
        },
        auth: false,
      ).timeout(const Duration(seconds: 60));

      final countsRaw = (data['counts'] as Map?)?.cast<String, dynamic>() ?? {};
      final placesRaw = (data['places'] as Map?)?.cast<String, dynamic>() ?? {};
      final scoresRaw = (data['scores'] as Map?)?.cast<String, dynamic>() ?? {};

      final counts = <String, int>{};
      for (final cat in _kCategories) {
        counts[cat.name] = (countsRaw[cat.name] as num?)?.toInt() ?? 0;
      }

      final places = <String, List<Map<String, dynamic>>>{};
      for (final cat in _kCategories) {
        final list = placesRaw[cat.name] as List<dynamic>? ?? [];
        places[cat.name] = list.map((e) {
          final m = (e as Map).cast<String, dynamic>();
          return <String, dynamic>{
            'name': m['name']?.toString() ?? 'Unnamed',
            if (m['lat'] != null) 'lat': (m['lat'] as num).toDouble(),
            if (m['lon'] != null) 'lon': (m['lon'] as num).toDouble(),
            if (m['distance'] != null) 'distance': (m['distance'] as num).toDouble(),
          };
        }).toList();
      }

      final scores = <String, double>{};
      for (final entry in scoresRaw.entries) {
        scores[entry.key] = (entry.value as num).toDouble();
      }

      setState(() {
        _poiCounts = counts;
        _poiPlaces = places;
        _infraScoreMap = scores;
        _poisCollected = scores.isNotEmpty;
      });
    } on ApiException catch (e) {
      final hint = e.statusCode == 404
          ? ' Restart the backend (npm start in backend/) and hard-refresh the page.'
          : '';
      setState(() => _poiError = 'Infrastructure fetch failed: ${e.message}.$hint');
    } catch (e) {
      setState(() => _poiError =
          'Infrastructure fetch failed: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      setState(() => _collectingPois = false);
    }
  }

  Map<String, double> get _infraScores =>
      _poisCollected ? _infraScoreMap : {};

  // â”€â”€ AI Valuation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  double _competitorBenchmarkPrice() {
    final priced = _mbListings
        .map((e) => (e['pricePerSqft'] as num?)?.toDouble() ?? 0)
        .where((p) => p > 0)
        .toList()
      ..sort();
    if (priced.isEmpty) return 5000.0;
    final mid = priced.length ~/ 2;
    return priced.length.isOdd
        ? priced[mid]
        : (priced[mid - 1] + priced[mid]) / 2;
  }

  _ValuationResult _computeValuation() {
    final infraScore = _infraScores['Overall Location'] ?? 50;
    final benchmarkPrice = _competitorBenchmarkPrice();
    final roadWidth = double.tryParse(_roadWidthCtrl.text) ?? 20;
    final landSize = double.tryParse(_landSizeCtrl.text) ?? 1000;

    final locationMultiplier = switch (_locationCategory) {
      'Premium' => 1.35,
      'Urban' => 1.15,
      'Semi-Urban' => 1.0,
      'Rural' => 0.8,
      _ => 1.0,
    };
    final potentialMultiplier = switch (_developmentPotential) {
      'Very High' => 1.25,
      'High' => 1.15,
      'Medium' => 1.0,
      'Low' => 0.85,
      _ => 1.0,
    };

    final roadBonus = (roadWidth / 60).clamp(0.9, 1.2);
    final sizeDiscount = landSize > 10000 ? 0.95 : 1.0;

    final basePrice = benchmarkPrice * locationMultiplier * potentialMultiplier *
        roadBonus * sizeDiscount;
    final purchasePrice = basePrice * (1 - infraScore / 500);
    final sellingPrice = basePrice * 1.18;
    final margin = ((sellingPrice - purchasePrice) / purchasePrice * 100);

    final investmentScore = ((infraScore * 0.55 +
                (potentialMultiplier - 0.8) / 0.45 * 100 * 0.45) *
            1)
        .clamp(0, 100)
        .toInt();

    final riskScore = (100 -
            investmentScore * 0.5 -
            (infraScore * 0.3) -
            10)
        .clamp(0, 100)
        .toInt();

    final recommendation = investmentScore > 70
        ? 'Strong Buy'
        : investmentScore > 50
            ? 'Buy'
            : investmentScore > 35
                ? 'Hold'
                : 'Avoid';

    return _ValuationResult(
      recommendedPurchasePrice: purchasePrice,
      recommendedSellingPrice: sellingPrice,
      expectedMargin: margin,
      investmentScore: investmentScore,
      riskScore: riskScore,
      recommendation: recommendation,
    );
  }

  // â”€â”€ Zoom helper â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  double _zoomForRadius(int km) =>
      km == 2 ? 14.5 : km == 5 ? 13.0 : 12.0;

  // â”€â”€ MagicBricks Competitor Projects â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _fetchMagicBricksProjects() async {
    final city = (_detectedDistrict ?? 'Chennai')
        .replaceAll(RegExp(r'\s*[Dd]istrict\s*$'), '')
        .replaceAll(RegExp(r'\s*[Dd]t\s*$'), '')
        .trim();
    final cityParam = city.isEmpty ? 'Chennai' : city;
    final loc = _activeLatLng;
    if (loc == null) {
      setState(() {
        _mbError = 'Tap the map or enable GPS to load competitor projects in your radius.';
        _fetchingMb = false;
      });
      return;
    }

    final parts = <String>[
      'city=${Uri.encodeComponent(cityParam)}',
      'lat=${loc.latitude}',
      'lng=${loc.longitude}',
      'radius=$_selectedRadius',
    ];
    final params = parts.join('&');
    final fetchSeq = ++_mbFetchSeq;

    setState(() {
      _fetchingMb = true;
      _mbError = null;
      _mbPartialWarning = null;
      _mbListings = [];
    });

    try {
      Map<String, dynamic>? result;
      for (final path in ['/api/competitors?$params', '/api/magicbricks?$params']) {
        try {
          result = await ApiClient.get(path)
              .timeout(const Duration(seconds: 120));
          final count = (result['listings'] as List?)?.length ?? 0;
          if (count > 0) break;
        } catch (_) {
          result = null;
        }
      }

      if (!mounted || fetchSeq != _mbFetchSeq) return;

      if (result == null) {
        throw const ApiException(
          statusCode: 0,
          message: 'Could not load competitor projects. Start the backend: cd backend && npm start',
        );
      }

      var listings = ((result['listings'] as List<dynamic>?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final radiusNote = result['radiusNote'] as String?;

      if (listings.isEmpty) {
        throw ApiException(
          statusCode: 502,
          message: radiusNote ??
              'No priced competitor projects within ${_selectedRadius}km. Try 5km or 10km.',
        );
      }

      if (!mounted || fetchSeq != _mbFetchSeq) return;

      setState(() {
        _mbListings = listings;
        _mbSource = (result!['source'] as String?) ?? 'MagicBricks';
        final partial = result['partial'] is List
            ? (result['partial'] as List).join('; ')
            : result['partial'] as String?;
        _mbPartialWarning = [radiusNote, partial]
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .join(' · ');
        _fetchingMb = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _mbError = e.message;
        _fetchingMb = false;
      });
    } on TimeoutException {
      setState(() {
        _mbError = 'Request timed out. Prices take ~1 min to load — try again.';
        _fetchingMb = false;
      });
    } catch (e) {
      setState(() {
        _mbError = 'Could not reach the server at localhost:3000. Run: cd backend && npm start';
        _fetchingMb = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredMbListings {
    if (_compFilter == 'All') return _mbListings;
    final curYear = DateTime.now().year;
    return _mbListings.where((item) {
      final status      = (item['status'] as String? ?? '').toLowerCase();
      final projectType = (item['projectType'] as String?) ?? 'Building';
      final regYear     = item['registeredYear'] as int?;
      switch (_compFilter) {
        case 'Ongoing':
          return projectType == 'Building' &&
              (status.contains('register') || status.contains('construct') || status.contains('ongoing'));
        case 'Completed':
          return status.contains('complet') || status.contains('ready') || status.contains('move');
        case 'Plot':
          return projectType == 'Layout';
        case 'Old':
          if (regYear == null) return false;
          return (curYear - regYear) >= _oldYearsFilter;
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildMagicBricksSection() {
    const mbColor = Color(0xFFE65100);
    final city = (_detectedDistrict ?? '')
        .replaceAll(RegExp(r'\s*[Dd]istrict\s*$'), '').trim();

    String fmtPricePerSqft(Map<String, dynamic> item) {
      var ppsf = (item['pricePerSqft'] as num?)?.toDouble() ?? 0;
      if (ppsf <= 0) {
        final total = (item['priceRupees'] as num?)?.toDouble() ?? 0;
        final area = (item['area'] as num?)?.toDouble() ?? 0;
        if (total > 0 && area > 0) ppsf = total / area;
      }
      if (ppsf <= 0) return '';
      return '₹${ppsf.toInt()}/sqft';
    }

    String fmtTotalPrice(Map<String, dynamic> item) {
      final total = (item['priceRupees'] as num?)?.toDouble() ?? 0;
      if (total >= 1e7) return '₹${(total / 1e7).toStringAsFixed(2)} Cr';
      if (total > 0) return '₹${(total / 1e5).toStringAsFixed(2)} L';
      return '';
    }

    String fmtPriceLabel(Map<String, dynamic> item) {
      final ppsf = fmtPricePerSqft(item);
      final total = fmtTotalPrice(item);
      if (ppsf.isNotEmpty && total.isNotEmpty) return '$ppsf · $total';
      if (ppsf.isNotEmpty) return ppsf;
      if (total.isNotEmpty) return total;
      return 'Price on request';
    }

    Widget chip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
    );

    return _SectionCard(
      title: 'Competitor Projects',
      icon: Icons.business_center_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sources: $_mbSource',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(
                'Area: ${city.isEmpty ? 'Chennai' : city}'
                '${_activeLatLng != null ? ' · ${_selectedRadius}km radius' : ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ]),
          ),
          ElevatedButton.icon(
            onPressed: _fetchingMb ? null : _fetchMagicBricksProjects,
            icon: _fetchingMb
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.travel_explore, size: 16),
            label: Text(_fetchingMb ? 'Loading prices (~1 min)...' : 'Fetch Projects',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: mbColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ]),

        if (_activeLatLng != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Text('Radius:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(width: 10),
            ...([2, 5, 10]).map((km) {
              final selected = _selectedRadius == km;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    if (selected) return;
                    setState(() => _selectedRadius = km);
                    if (_mapReady && _activeLatLng != null) {
                      _mapController.move(_activeLatLng!, _zoomForRadius(km));
                    }
                    _fetchMagicBricksProjects();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? mbColor : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected ? mbColor : const Color(0xFFD1D5DB)),
                    ),
                    child: Text('${km}km',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : AppColors.textSecondary)),
                  ),
                ),
              );
            }),
          ]),
        ],

        if (_mbPartialWarning != null && _mbPartialWarning!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Color(0xFFD97706), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Some sources unavailable: $_mbPartialWarning',
                  style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                ),
              ),
            ]),
          ),
        ],

        if (_mbError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_mbError!,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFDC2626))),
              ),
            ]),
          ),
        ],

        if (_mbListings.isNotEmpty) ...[
          const SizedBox(height: 12),
          // ── Project type filters ────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final f in ['All', 'Ongoing', 'Completed', 'Plot', 'Old Projects'])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(f, style: const TextStyle(fontSize: 11)),
                    selected: _compFilter == (f == 'Old Projects' ? 'Old' : f),
                    selectedColor: mbColor,
                    labelStyle: TextStyle(
                      color: _compFilter == (f == 'Old Projects' ? 'Old' : f)
                          ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() {
                      _compFilter = f == 'Old Projects' ? 'Old' : f;
                    }),
                  ),
                ),
            ]),
          ),
          if (_compFilter == 'Old') ...[
            const SizedBox(height: 8),
            Row(children: [
              const Text('Max age:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              for (final yrs in [2, 5, 10])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text('< ${yrs}yrs', style: const TextStyle(fontSize: 11)),
                    selected: _oldYearsFilter == yrs,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _oldYearsFilter == yrs ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _oldYearsFilter = yrs),
                  ),
                ),
            ]),
          ],
          const SizedBox(height: 8),
          Text(
            '${_filteredMbListings.length} of ${_mbListings.length} project${_mbListings.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          ..._filteredMbListings.take(30).map((item) {
            final name      = item['projectName'] as String? ?? '';
            final locality  = item['locality']    as String? ?? '';
            final bhk       = item['bhkType']     as String? ?? '';
            final poss      = item['possession']  as String? ?? '';
            final rera      = item['reraNo']      as String? ?? '';
            final developer = item['developer']   as String? ?? '';
            final source    = item['source']      as String? ?? '';
            final ppsfStr   = fmtPricePerSqft(item);
            final totalStr  = fmtTotalPrice(item);
            final priceLabel = fmtPriceLabel(item);
            final hasPrice  = ppsfStr.isNotEmpty || totalStr.isNotEmpty;
            final distKm    = (item['distanceKm'] as num?)?.toDouble();
            final isTnrera  = source == 'TNRERA';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      name.isNotEmpty ? name : locality,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (hasPrice && ppsfStr.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: mbColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(ppsfStr,
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800, color: mbColor)),
                        )
                      else
                        Text(priceLabel,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: hasPrice ? mbColor : AppColors.textSecondary,
                                fontStyle: hasPrice ? FontStyle.normal : FontStyle.italic)),
                      if (totalStr.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(totalStr,
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ]),
                if (distKm != null) ...[
                  const SizedBox(height: 4),
                  Text('${distKm.toStringAsFixed(1)} km away',
                      style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
                if (developer.isNotEmpty && isTnrera) ...[
                  const SizedBox(height: 3),
                  Text(developer,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                if (locality.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 12,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(locality,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
                if (bhk.isNotEmpty || (poss.isNotEmpty && poss != 'N/A') ||
                    rera.isNotEmpty || source.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    if (source.isNotEmpty) chip(source, const Color(0xFF6A1B9A)),
                    if (bhk.isNotEmpty) chip(bhk, const Color(0xFF1565C0)),
                    if (poss.isNotEmpty && poss != 'N/A')
                      chip(poss, AppColors.success),
                    if (rera.isNotEmpty) chip('RERA ✓', AppColors.primary),
                  ]),
                ],
              ]),
            );
          }),
        ] else if (!_fetchingMb && _mbError == null) ...[
          const SizedBox(height: 16),
          Center(
            child: Column(children: [
              Icon(Icons.business_outlined, size: 36,
                  color: mbColor.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              const Text(
                'Tap "Fetch Projects" to load\ncompetitor projects with prices\nfrom MagicBricks, 99acres & Housing.com.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, height: 1.4),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  // â”€â”€ Section: EC & Patta â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildGovtDocsSection() {
    // In lead-based mode the selected lead carries a survey number, which lets
    // EC & Patta auto-fetch end-to-end. Search/GPS mode has no survey number.
    String? surveyNo;
    String? subDiv;
    if (_isLeadBasedMode && _selectedLeadId != null) {
      final leads = AppStore.instance.leads;
      final idx = leads.indexWhere((l) => l.leadId == _selectedLeadId);
      if (idx != -1) {
        final s = leads[idx].surveyNumber.trim();
        if (s.isNotEmpty) surveyNo = s;
      }
    }
    final loc = _activeLatLng;
    return _GovtDocsSection(
      district: _detectedDistrict,
      taluk: _detectedTaluk,
      village: _detectedVillage,
      // Map tap / TNGIS parcel wins over lead survey when both exist.
      surveyNumber: _tngisSurvey ?? surveyNo,
      subDivision: _tngisSubDiv ?? subDiv,
      districtCode: _tngisDc,
      talukCode: _tngisTc,
      villageCode: _tngisVc,
      lat: loc?.latitude,
      lon: loc?.longitude,
      tngisGiViewerUrl: _tngisGiViewerUrl,
      giServices: _tngisGiServices,
      ulpin: _tngisUlpin,
      centroid: _tngisCentroid,
      tngisSubdivisions: _tngisSubdivisions,
      tngisParcelLoading: _tngisParcelLoading,
      fmbAvailable: _tngisFmbAvailable,
      fmbNote: _tngisFmbNote,
    );
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isLeadBasedMode = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isLeadBasedMode ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: !_isLeadBasedMode
                            ? [BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: const Text('Search Mode',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isLeadBasedMode = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isLeadBasedMode ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: _isLeadBasedMode
                            ? [BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: const Text('Lead Based',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            if (_isLeadBasedMode)
              _buildLeadBasedSection()
            else
              _buildSearchSection(),
            const SizedBox(height: 20),
            _buildMapSection(),
            const SizedBox(height: 20),
            _buildPoiSection(),
            if (_poisCollected) ...[
              const SizedBox(height: 20),
              _buildInfraScoreSection(),
            ],
            const SizedBox(height: 20),
            _buildMagicBricksSection(),
            const SizedBox(height: 20),
            _buildGovtDocsSection(),
            const SizedBox(height: 20),
            _buildValuationSection(),
            const SizedBox(height: 40),
          ],
        ),
      );
    if (widget.isTab) {
      return Scaffold(body: _wrapWithFullScreenMap(body));
    }
    return Scaffold(
      appBar: const FomraAppBar(moduleName: 'Market Intelligence'),
      drawer: const AppDrawer(currentRoute: '/market-intelligence'),
      bottomNavigationBar:
          const FomraBottomNav(currentRoute: '/market-intelligence'),
      body: _wrapWithFullScreenMap(body),
    );
  }

  Widget _wrapWithFullScreenMap(Widget body) {
    return Stack(
      fit: StackFit.expand,
      children: [
        body,
        if (_mapFullScreen) Positioned.fill(child: _buildFullScreenMapOverlay()),
      ],
    );
  }


  // â”€â”€ EC & Patta: reverse-geocode district/taluk/village â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _fetchLocationDetails(LatLng loc) async {
    try {
      final res = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${loc.latitude}&lon=${loc.longitude}'),
        headers: {
          'User-Agent': 'FomraLS/1.0 (in.fomrahousing)',
          'Accept-Language': 'en',
        },
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final addr =
            (jsonDecode(res.body)['address'] as Map<String, dynamic>?) ?? {};
        setState(() {
          _detectedDistrict = (addr['county'] as String? ??
                  addr['state_district'] as String? ??
                  addr['city'] as String?)
              ?.replaceAll(RegExp(r'\s+[Dd]istrict$'), '')
              .trim();
          _detectedTaluk = addr['suburb'] as String? ??
              addr['city_district'] as String? ??
              addr['municipality'] as String? ??
              addr['town'] as String?;
          _detectedVillage = addr['village'] as String? ??
              addr['hamlet'] as String? ??
              addr['neighbourhood'] as String?;
        });
      }
    } catch (_) {}
  }

  // â”€â”€ Section: Lead-Based Location Setup â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildLeadBasedSection() {
    final leads = AppStore.instance.leads;
    return _SectionCard(
      title: 'Lead-Based Location Setup',
      icon: Icons.assignment_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leads.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFDC2626), size: 28),
                  const SizedBox(height: 8),
                  const Text(
                    'No Land Leads available.',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Add a lead in Land Lead Management first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF7F1D1D)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/land-lead'),
                    icon: const Icon(Icons.add_location_alt_outlined, size: 16),
                    label: const Text('Go to Land Lead Management'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedLeadId,
              decoration: _inputDec('Select a Land Lead'),
              hint: const Text('Select a Land Lead'),
              isExpanded: true,
              items: leads.map((lead) {
                return DropdownMenuItem<String>(
                  value: lead.leadId,
                  child: Text(
                    '${lead.leadId} - ${lead.ownerName} (${lead.location})',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final lead = leads.firstWhere((l) => l.leadId == val);
                final loc = _parseGpsCoordinates(lead.gpsCoordinates);
                setState(() {
                  _selectedLeadId = val;
                  _searchCtrl.text = ''; // Clear search bar text
                  _searchResults = [];
                  _poisCollected = false;
                  _poiCounts = {};
                  _poiPlaces = {};
                  _valuationResult = null;
                  if (loc != null) {
                    _searchedLocation = loc;
                    _detectedDistrict = lead.district.isNotEmpty ? lead.district : null;
                    _detectedTaluk = lead.taluk.isNotEmpty ? lead.taluk : null;
                    _detectedVillage = lead.village.isNotEmpty ? lead.village : null;
                    if (_mapReady) {
                      _mapController.move(loc, _zoomForRadius(_selectedRadius));
                    }
                    _fetchLocationDetails(loc);
                  }
                });
              },
            ),
            if (_selectedLeadId != null) ...[
              Builder(
                builder: (context) {
                  final lead = leads.firstWhere((l) => l.leadId == _selectedLeadId);
                  return Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lead.leadId,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                lead.status.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('Owner:', lead.ownerName),
                        _buildInfoRow('Location:', lead.location),
                        if (lead.gpsCoordinates.isNotEmpty)
                          _buildInfoRow('GPS Coordinates:', lead.gpsCoordinates),
                        _buildInfoRow('Extent:', lead.landExtent),
                        if (lead.surveyNumber.isNotEmpty)
                          _buildInfoRow('Survey No:', lead.surveyNumber),
                      ],
                    ),
                  );
                }
              ),
            ],
          ],
        ],
      ),
    );
  }

  // â”€â”€ Section: Search Location Setup â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSearchSection() {
    return _SectionCard(
      title: 'Search Location Setup',
      icon: Icons.search,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                decoration: _inputDec('Search city, area, landmark...').copyWith(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 10, right: 6),
                    child: Icon(Icons.search, size: 18,
                        color: AppColors.textSecondary),
                  ),
                  prefixIconConstraints: const BoxConstraints(),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (val) {
                  setState(() {
                    _selectedLeadId = null; // Clear lead selection
                  });
                  _searchLocation(val);
                },
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _searchingLocation
                    ? null
                    : () {
                        setState(() {
                          _selectedLeadId = null; // Clear lead selection
                        });
                        _searchLocation(_searchCtrl.text);
                      },
                style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14)),
                child: _searchingLocation
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.search, size: 18),
              ),
            ),
          ]),
          if (_searchError != null) ...[
            const SizedBox(height: 6),
            _ErrorBanner(_searchError!),
          ],
          if (_showSearchResults && _searchResults.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 40),
                itemBuilder: (_, i) {
                  final r = _searchResults[i];
                  final name = r['display_name'] as String? ?? '';
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedLeadId = null; // Clear lead selection
                      });
                      _selectSearchResult(r);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) => Material(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: _mapReady ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      );

  Widget _buildMapOverlayButton(IconData icon, VoidCallback onTap) => Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
        ),
      );

  void _setMapLayer(_MarketMapLayer layer) {
    setState(() => _mapLayer = layer);
    if (layer == _MarketMapLayer.transport &&
        _activeLatLng != null &&
        !_poisCollected &&
        !_collectingPois) {
      _collectPois();
    }
  }

  Widget _buildMapLayerChip(_MarketMapLayer layer, String label, IconData icon) {
    final selected = _mapLayer == layer;
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      elevation: selected ? 2 : 1,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _setMapLayer(layer),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? Colors.white : AppColors.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Marker> _buildTransportPoiMarkers() {
    if (_mapLayer != _MarketMapLayer.transport) return [];
    final markers = <Marker>[];
    for (final cat in _kCategories) {
      if (!_kTransportPoiNames.contains(cat.name)) continue;
      final places = _poiPlaces[cat.name] ?? [];
      for (final place in places) {
        final lat = place['lat'] as double?;
        final lon = place['lon'] as double?;
        if (lat == null || lon == null) continue;
        final name = place['name']?.toString() ?? cat.name;
        markers.add(Marker(
          point: LatLng(lat, lon),
          width: 32,
          height: 32,
          child: Tooltip(
            message: name,
            child: Container(
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.92),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
              child: Icon(cat.icon, color: Colors.white, size: 16),
            ),
          ),
        ));
      }
    }
    return markers;
  }

  Widget _buildMapStack({bool showMaximize = false, bool showMinimize = false}) {
    final activeLoc = _activeLatLng;
    return Stack(
      children: [
        Positioned.fill(
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: activeLoc ?? _kDefaultCenter,
              initialZoom: _zoomForRadius(_selectedRadius),
              onMapReady: () => setState(() => _mapReady = true),
              onTap: (_, point) => _handleMapTap(point),
            ),
            children: [
              TileLayer(
                urlTemplate: _kOsmTileUrl,
                userAgentPackageName: 'in.fomrahousing.fomrals',
              ),
              if (_mapLayer == _MarketMapLayer.transport)
                TileLayer(
                  urlTemplate: _kOsmTransportRailUrl,
                  userAgentPackageName: 'in.fomrahousing.fomrals',
                  tileDisplay: const TileDisplay.instantaneous(opacity: 0.72),
                ),
              CircleLayer(circles: [
                if (activeLoc != null)
                  CircleMarker(
                    point: activeLoc,
                    radius: _selectedRadius * 1000.0,
                    useRadiusInMeter: true,
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderColor: AppColors.primary,
                    borderStrokeWidth: 2,
                  ),
              ]),
              if (_mapLayer == _MarketMapLayer.transport)
                MarkerLayer(markers: _buildTransportPoiMarkers()),
              MarkerLayer(markers: [
                if (activeLoc != null)
                  Marker(
                    point: activeLoc,
                    width: 40,
                    height: 48,
                    child: Icon(Icons.location_on,
                        color: _searchMode
                            ? const Color(0xFF1565C0)
                            : const Color(0xFFE53935),
                        size: 40),
                  ),
                if (_tappedPoint != null)
                  Marker(
                    point: _tappedPoint!,
                    width: 36,
                    height: 44,
                    child: const Icon(Icons.location_searching,
                        color: Color(0xFF6A1B9A), size: 32),
                  ),
              ]),
            ],
          ),
        ),
        if (_fetchingLocation || _searchingLocation)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            ),
          ),
        if (activeLoc == null && !_fetchingLocation && !_searchingLocation)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Tap to set location',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
        Positioned(
          top: 8,
          left: 8,
          child: Row(
            children: [
              _buildMapLayerChip(
                _MarketMapLayer.standard,
                'Standard',
                Icons.map_outlined,
              ),
              const SizedBox(width: 6),
              _buildMapLayerChip(
                _MarketMapLayer.transport,
                'Transport',
                Icons.directions_transit_outlined,
              ),
            ],
          ),
        ),
        if (showMaximize)
          Positioned(
            top: 8,
            right: 8,
            child: _buildMapOverlayButton(
              Icons.fullscreen,
              () => setState(() => _mapFullScreen = true),
            ),
          ),
        if (showMinimize)
          Positioned(
            top: 8,
            right: 8,
            child: _buildMapOverlayButton(
              Icons.fullscreen_exit,
              () => setState(() => _mapFullScreen = false),
            ),
          ),
      ],
    );
  }

  Widget _buildMapFullscreenPlaceholder() {
    return Container(
      color: const Color(0xFFE8EAF6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 36, color: AppColors.primary),
          const SizedBox(height: 8),
          const Text(
            'Map expanded to full screen',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _mapFullScreen = false),
            icon: const Icon(Icons.fullscreen_exit, size: 18),
            label: const Text('Exit full screen'),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenMapOverlay() {
    final activeLoc = _activeLatLng;
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildMapStack(showMinimize: true),
            ),
            if (activeLoc != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${activeLoc.latitude.toStringAsFixed(5)}° N, '
                    '${activeLoc.longitude.toStringAsFixed(5)}° E · '
                    'Tap plot for TNGIS survey',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Section: Map Visualization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildMapSection() {
    final activeLoc = _activeLatLng;
    return _SectionCard(
      title: 'Map Visualization',
      icon: Icons.map_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 260,
              child: _mapFullScreen
                  ? _buildMapFullscreenPlaceholder()
                  : _buildMapStack(showMaximize: true),
            ),
          ),
          const SizedBox(height: 10),

          if (activeLoc != null) ...[
            Text(
              '📍 ${activeLoc.latitude.toStringAsFixed(5)}° N, ${activeLoc.longitude.toStringAsFixed(5)}° E',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap directly on the land plot — survey & subdivision are read from TNGIS.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            if (_tngisParcelLoading) ...[
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Reading parcel from TNGIS…',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ],
            if (_tngisParcelError != null && !_tngisParcelLoading) ...[
              const SizedBox(height: 6),
              Text(_tngisParcelError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
            ],
            const SizedBox(height: 10),
          ],
          if (_locationError != null) ...[
            _ErrorBanner(_locationError!),
            const SizedBox(height: 10),
          ],

          Row(children: [
            const Text('Layer:',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            _buildMapLayerChip(
              _MarketMapLayer.standard,
              'Standard',
              Icons.map_outlined,
            ),
            const SizedBox(width: 6),
            _buildMapLayerChip(
              _MarketMapLayer.transport,
              'Transport',
              Icons.directions_transit_outlined,
            ),
          ]),
          if (_mapLayer == _MarketMapLayer.transport) ...[
            const SizedBox(height: 6),
            Text(
              _collectingPois
                  ? 'Loading transport POIs from OpenStreetMap…'
                  : 'OpenStreetMap transport layer — railways, stations & bus terminals.',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 10),

        Row(children: [
          const Text('Zoom:',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const Spacer(),
          _buildZoomButton(Icons.remove, () {
            if (_mapReady) {
              _mapController.move(
                _mapController.camera.center,
                (_mapController.camera.zoom - 1).clamp(3.0, 18.0),
              );
            }
          }),
          const SizedBox(width: 8),
          _buildZoomButton(Icons.add, () {
            if (_mapReady) {
              _mapController.move(
                _mapController.camera.center,
                (_mapController.camera.zoom + 1).clamp(3.0, 18.0),
              );
            }
          }),
        ]),
      ]),
    );
  }

  // â”€â”€ Section: POI Collection â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _showPoiList(_PoiCategory cat) {
    final places = _poiPlaces[cat.name] ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PoiListSheet(category: cat, places: places),
    );
  }

  Widget _buildPoiSection() => _SectionCard(
        title: 'Infrastructure Score',
        icon: Icons.place_outlined,
        child: Column(children: [
          Row(children: [
            const Text('Radius:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(width: 10),
            ...([2, 5, 10]).map((km) {
              final selected = _selectedRadius == km;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedRadius = km;
                      _poisCollected = false;
                      _poiCounts = {};
                      _poiPlaces = {};
                      _infraScoreMap = {};
                      if (_activeLatLng != null && _mapReady) {
                        _mapController.move(
                            _activeLatLng!, _zoomForRadius(km));
                      }
                    });
                    if (_activeLatLng != null) _fetchMagicBricksProjects();
                    if (_activeLatLng != null) _collectPois();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF00838F)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: selected
                              ? const Color(0xFF00838F)
                              : const Color(0xFFD1D5DB)),
                    ),
                    child: Text('${km}km',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : AppColors.textSecondary)),
                  ),
                ),
              );
            }),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_activeLatLng == null || _collectingPois)
                  ? null
                  : _collectPois,
              icon: _collectingPois
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.radar, size: 18),
              label: Text(_collectingPois
                  ? 'Loading from Overpass…'
                  : 'Refresh Infrastructure Score'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00838F),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_activeLatLng == null && !_collectingPois) ...[
            const SizedBox(height: 10),
            const Text(
              'Set your location on the map to score nearby infrastructure via OpenStreetMap.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          if (_poisCollected) ...[
            const SizedBox(height: 8),
            const Text(
              'Scores from OpenStreetMap Overpass API (schools, hospitals, transport, roads).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary, height: 1.3),
            ),
          ],
          if (_poiError != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(_poiError!),
          ],
          if (_poisCollected && _poiCounts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kCategories.map((cat) {
                final count = _poiCounts[cat.name] ?? 0;
                return GestureDetector(
                  onTap: () => _showPoiList(cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cat.color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: cat.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(cat.icon, color: cat.color, size: 13),
                      const SizedBox(width: 5),
                      Text('$count',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: cat.color)),
                      const SizedBox(width: 4),
                      Text(cat.name,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary)),
                      const SizedBox(width: 3),
                      Icon(Icons.chevron_right,
                          size: 12,
                          color: cat.color.withValues(alpha: 0.6)),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ],
        ]),
      );

  // â”€â”€ Section: Infrastructure Score â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildInfraScoreSection() {
    final scores = _infraScores;
    final overall = scores['Overall Location'] ?? 0;
    final overallColor = overall > 70
        ? AppColors.success
        : overall > 45
            ? AppColors.warning
            : AppColors.error;

    final barData = scores.entries
        .where((e) => e.key != 'Overall Location')
        .toList();

    return _SectionCard(
      title: 'Infrastructure Score',
      icon: Icons.analytics_outlined,
      child: Column(children: [
        Row(children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: overallColor, width: 4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${overall.toInt()}',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: overallColor)),
                const Text('/100',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Overall Location Score',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: overallColor)),
                const SizedBox(height: 4),
                Text(
                    overall > 70
                        ? 'Excellent infrastructure in this area.'
                        : overall > 45
                            ? 'Moderate infrastructure. Room to grow.'
                            : 'Infrastructure needs development.',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: 100,
              barGroups: barData.asMap().entries.map((e) {
                final score = e.value.value;
                final barColor = score > 70
                    ? AppColors.success
                    : score > 45
                        ? AppColors.warning
                        : AppColors.error;
                return BarChartGroupData(x: e.key, barRods: [
                  BarChartRodData(
                    toY: score,
                    color: barColor,
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: 100,
                      color: barColor.withValues(alpha: 0.08),
                    ),
                  ),
                ]);
              }).toList(),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}',
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textSecondary)),
                    interval: 25,
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= barData.length) {
                        return const SizedBox.shrink();
                      }
                      final label = barData[idx].key.replaceAll(' ', '\n');
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 8, color: AppColors.textSecondary)),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: 25,
                getDrawingHorizontalLine: (_) => const FlLine(
                    color: Color(0xFFE5E7EB), strokeWidth: 1),
                drawVerticalLine: false,
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...barData.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ScoreRow(label: e.key, score: e.value),
            )),
      ]),
    );
  }

  // â”€â”€ Section: AI Valuation Engine â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildValuationSection() => _SectionCard(
        title: 'AI Land Valuation Engine',
        icon: Icons.auto_awesome_outlined,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryDark.withValues(alpha: 0.08),
                  AppColors.primary.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Inputs: Infrastructure Score Â· Market Price Â· Road Width Â· Land Size Â· Development Potential Â· Location Category',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.primary, height: 1.4),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          // Row 1: Road Width + Land Size
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Road Width (ft)'),
                    TextField(
                      controller: _roadWidthCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDec('e.g. 30'),
                    ),
                  ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Land Size (sqft)'),
                    TextField(
                      controller: _landSizeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: _inputDec('e.g. 5000'),
                    ),
                  ]),
            ),
          ]),
          const SizedBox(height: 12),
          // Market price reference
          _AutoChip('Market Reference', () {
            final bench = _competitorBenchmarkPrice();
            final fromCompetitors = _mbListings.any(
              (e) => ((e['pricePerSqft'] as num?)?.toDouble() ?? 0) > 0,
            );
            return fromCompetitors
                ? '₹${bench.toInt()}/sqft  (median from competitor data)'
                : '₹5000/sqft  (default — fetch competitor data to refine)';
          }()),
          const SizedBox(height: 12),
          // Row 3: Location Category + Development Potential
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Location Category'),
                    DropdownButtonFormField<String>(
                      initialValue: _locationCategory,
                      decoration: _inputDec(null),
                      items: ['Premium', 'Urban', 'Semi-Urban', 'Rural']
                          .map((v) =>
                              DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _locationCategory = v!),
                    ),
                  ]),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('Development Potential'),
                    DropdownButtonFormField<String>(
                      initialValue: _developmentPotential,
                      decoration: _inputDec(null),
                      items: ['Very High', 'High', 'Medium', 'Low']
                          .map((v) =>
                              DropdownMenuItem(value: v, child: Text(v)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _developmentPotential = v!),
                    ),
                  ]),
            ),
          ]),
          const SizedBox(height: 8),
          // Auto-filled chip
          if (_poisCollected)
            _AutoChip('Infrastructure Score',
                '${(_infraScores['Overall Location'] ?? 0).toInt()}/100'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () =>
                  setState(() => _valuationResult = _computeValuation()),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Generate Valuation'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 13)),
            ),
          ),
          if (_valuationResult != null) ...[
            const SizedBox(height: 20),
            _buildValuationOutput(_valuationResult!),
          ],
        ]),
      );

  Widget _buildValuationOutput(_ValuationResult v) {
    final recColor = switch (v.recommendation) {
      'Strong Buy' => AppColors.success,
      'Buy' => const Color(0xFF00838F),
      'Hold' => AppColors.warning,
      _ => AppColors.error,
    };

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(),
      const SizedBox(height: 12),
      const Text('Valuation Results',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.95,
        children: [
          _BenchmarkTile('Buy Price',
              'â‚¹${v.recommendedPurchasePrice.toInt()}', AppColors.info),
          _BenchmarkTile('Sell Price',
              'â‚¹${v.recommendedSellingPrice.toInt()}', AppColors.success),
          _BenchmarkTile('Margin',
              '${v.expectedMargin.toStringAsFixed(1)}%', AppColors.warning),
          _BenchmarkTile(
              'Inv. Score', '${v.investmentScore}/100', AppColors.primary),
        ],
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: _OutputCard(
            label: 'Risk Score',
            value: '${v.riskScore}/100',
            color: v.riskScore > 60
                ? AppColors.error
                : v.riskScore > 35
                    ? AppColors.warning
                    : AppColors.success,
            icon: Icons.shield_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OutputCard(
            label: 'Acquisition',
            value: v.recommendation,
            color: recColor,
            icon: Icons.recommend_outlined,
          ),
        ),
      ]),
    ]);
  }

  // â”€â”€ Section: Competitor Intelligence â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

}

// â”€â”€ Location Details Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€



// â”€â”€ POI List Sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PoiListSheet extends StatelessWidget {
  final _PoiCategory category;
  final List<Map<String, dynamic>> places;
  const _PoiListSheet({required this.category, required this.places});

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            _Handle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(category.icon, color: category.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        Text('${places.length} found nearby',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ]),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: places.isEmpty
                  ? const Center(
                      child: Text('No places found in this category.',
                          style:
                              TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: places.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 52),
                      itemBuilder: (_, i) {
                        final p = places[i];
                        final dist = p['distance'] as double?;
                        return Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: category.color
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(category.icon,
                                  color: category.color, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(p['name'] as String,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                            ),
                            if (dist != null) ...[
                              const SizedBox(width: 8),
                              Text('${dist.toStringAsFixed(1)} km',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary)),
                            ],
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
      );
}

// â”€â”€ Small Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SectionCard(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      );
}


class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.error))),
        ]),
      );
}

class _ScoreRow extends StatelessWidget {
  final String label;
  final double score;
  const _ScoreRow({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score > 70
        ? AppColors.success
        : score > 45
            ? AppColors.warning
            : AppColors.error;
    final isWide = MediaQuery.of(context).size.width > 600;
    return Row(children: [
      Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: isWide ? 15 : 12, color: AppColors.textSecondary))),
      SizedBox(
        width: isWide ? 200 : 120,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: const Color(0xFFE5E7EB),
            color: color,
            minHeight: isWide ? 10 : 6,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('${score.toInt()}',
          style: TextStyle(
              fontSize: isWide ? 15 : 12, color: color, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _BenchmarkTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BenchmarkTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(value,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w800,
                    height: 1.1)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 9,
                    color: color.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w600,
                    height: 1.2)),
          ],
        ),
      );
}

class _OutputCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _OutputCard(
      {required this.label,
      required this.value,
      required this.color,
      required this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 16, color: color, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _AutoChip extends StatelessWidget {
  final String label;
  final String value;
  const _AutoChip(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_outline,
              size: 12, color: AppColors.success),
          const SizedBox(width: 5),
          Text('$label: $value',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );
}

class _Handle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
}

InputDecoration _inputDec(String? hint) => InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 2)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
    );

class _Option {
  final String code;
  final String name;
  const _Option(this.code, this.name);
  @override
  bool operator ==(Object other) => other is _Option && other.code == code;
  @override
  int get hashCode => code.hashCode;
}

class _EcPeriod {
  final String id;
  final String label;
  final String fromDate;
  final String toDate;
  const _EcPeriod(this.id, this.label, this.fromDate, this.toDate);

  factory _EcPeriod.fromJson(Map<String, dynamic> j) => _EcPeriod(
        j['id'] as String,
        j['label'] as String,
        j['fromDate'] as String,
        j['toDate'] as String,
      );
}

class _EcEntry {
  final String id;
  final String label;
  const _EcEntry(this.id, this.label);
}

class _TngisSubdivisionRow {
  final String surveyNumber;
  final String? subDivision;
  final String? kide;
  final Map<String, String> fields;
  final bool containsPoint;
  final bool fmbAvailable;

  const _TngisSubdivisionRow({
    required this.surveyNumber,
    this.subDivision,
    this.kide,
    this.fields = const {},
    this.containsPoint = false,
    this.fmbAvailable = false,
  });

  factory _TngisSubdivisionRow.fromJson(Map<String, dynamic> j) {
    final fields = (j['fields'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
    final kideRaw = j['kide']?.toString() ?? fields['Kide'];
    final survey =
        j['surveyNumber']?.toString() ?? fields['Survey Number'] ?? '';
    final sub = _parseTngisSubDivision(
      j['subDivision']?.toString() ?? fields['Sub Division'],
      kideRaw,
      survey,
    );
    return _TngisSubdivisionRow(
      surveyNumber: survey,
      subDivision: sub,
      kide: (kideRaw != null && kideRaw.trim().isNotEmpty) ? kideRaw.trim() : null,
      fields: fields,
      containsPoint: j['containsPoint'] == true,
      fmbAvailable: j['fmbAvailable'] == true,
    );
  }

  String get key => '$surveyNumber|${subDivision ?? kide ?? ''}';

  /// Sub-division for FMB/EC — from sub_division or kide (e.g. 394/15C → 15C).
  String? get effectiveSubDivision =>
      _parseTngisSubDivision(subDivision, kide, surveyNumber);

  String get subLabel {
    return effectiveSubDivision ?? '—';
  }

  static String? _parseTngisSubDivision(String? subDiv, String? kide, String survey) {
    final s = subDiv?.trim();
    if (s != null && s.isNotEmpty && s != '-' && s != survey) return s;
    final k = kide?.trim();
    if (k == null || k.isEmpty || k == '0' || !k.contains('/')) return null;
    final parts = k.split('/');
    if (parts.length < 2) return null;
    final kideSub = parts.sublist(1).join('/').trim();
    if (kideSub.isEmpty || kideSub == '-' || kideSub == survey) return null;
    final kideSurvey = parts[0].trim();
    if (kideSurvey.isNotEmpty && kideSurvey != survey) return null;
    return kideSub;
  }
}

class _SubdivDocBundle {
  Map<String, dynamic>? documents;
  Uint8List? fmbPdf;
  bool loadingPatta = false;
  bool loadingFmb = false;
  String? fmbError;
}

// â”€â”€ EC & Patta: main section widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GovtDocsSection extends StatefulWidget {
  final String? district;
  final String? taluk;
  final String? village;
  final String? surveyNumber;
  final String? subDivision;
  final String? districtCode;
  final String? talukCode;
  final String? villageCode;
  final double? lat; // active map location — enables the TNGIS patta fallback
  final double? lon;
  final String? tngisGiViewerUrl;
  final Map<String, dynamic>? giServices;
  final String? ulpin;
  final String? centroid;
  final List<_TngisSubdivisionRow> tngisSubdivisions;
  final bool tngisParcelLoading;
  final bool fmbAvailable;
  final String? fmbNote;
  const _GovtDocsSection({
    this.district,
    this.taluk,
    this.village,
    this.surveyNumber,
    this.subDivision,
    this.districtCode,
    this.talukCode,
    this.villageCode,
    this.lat,
    this.lon,
    this.tngisGiViewerUrl,
    this.giServices,
    this.ulpin,
    this.centroid,
    this.tngisSubdivisions = const [],
    this.tngisParcelLoading = false,
    this.fmbAvailable = false,
    this.fmbNote,
  });

  @override
  State<_GovtDocsSection> createState() => _GovtDocsSectionState();
}

class _GovtDocsSectionState extends State<_GovtDocsSection> {
  // ── Patta state ──
  bool   _initingPatta = false;
  List<_Option> _districts = _kStaticDistricts;
  _Option? _selDistrict;
  List<_Option> _taluks   = [];
  bool   _loadingTaluks   = false;
  String? _talukError;
  _Option? _selTaluk;
  List<_Option> _villages = [];
  bool   _loadingVillages = false;
  String? _villageError;
  _Option? _selVillage;
  final _surveyCtrl  = TextEditingController();
  final _subDivCtrl  = TextEditingController();
  bool   _fetchingPatta   = false;
  Map<String, String>?      _pattaFields;
  List<Map<String, String>> _pattaOwners = [];
  String? _pattaError;
  String? _pattaSource;
  Map<String, dynamic>? _pattaDocuments;
  final Map<String, _SubdivDocBundle> _subdivBundles = {};
  Uint8List? _fmbPdfBytes;
  String? _fmbLoadError;
  bool _loadingFmb = false;
  int? _fmbViewerShownLen;
  bool   _showManualPatta = false;
  bool   _showManualEc    = false;
  Timer? _pattaDebounce;

  // â”€â”€ EC state â”€â”€
  List<_Option> _ecZones = [
    _Option('1', 'Chennai'),
    _Option('2', 'Coimbatore'),
    _Option('4', 'Madurai'),
  ];

  static const _kStaticEcDistricts = <String, List<_Option>>{
    '1': [ // North Zone
      _Option('2', 'Chennai'), _Option('8', 'Chengalpattu'),
      _Option('9', 'Kancheepuram'), _Option('21', 'Ranipet'),
      _Option('28', 'Tiruvallur'), _Option('29', 'Tiruvannamalai'),
      _Option('30', 'Vellore'), _Option('32', 'Viluppuram'),
      _Option('6', 'Kallakurichi'), _Option('25', 'Tirupattur'),
    ],
    '2': [ // South Zone
      _Option('4', 'Coimbatore'), _Option('7', 'Dharmapuri'),
      _Option('10', 'Erode'), _Option('11', 'Krishnagiri'),
      _Option('14', 'Namakkal'), _Option('15', 'Nilgiris'),
      _Option('20', 'Salem'), _Option('26', 'Tiruppur'),
    ],
    '3': [ // Central Zone
      _Option('1', 'Ariyalur'), _Option('3', 'Cuddalore'),
      _Option('5', 'Dindigul'), _Option('12', 'Kanniyakumari'),
      _Option('13', 'Karur'), _Option('16', 'Madurai'),
      _Option('17', 'Mayiladuthurai'), _Option('18', 'Nagapattinam'),
      _Option('19', 'Perambalur'), _Option('22', 'Pudukkottai'),
      _Option('23', 'Ramanathapuram'), _Option('24', 'Sivagangai'),
      _Option('27', 'Thanjavur'), _Option('31', 'Tenkasi'),
      _Option('33', 'Theni'), _Option('34', 'Tiruchirappalli'),
      _Option('35', 'Tirunelveli'), _Option('36', 'Tiruvarur'),
      _Option('37', 'Thoothukudi'), _Option('38', 'Virudhunagar'),
    ],
  };

  // Keyed by district code. SRO codes are sequential placeholders;
  // real codes are loaded from tnreginet when reachable.
  static const _kStaticEcSros = <String, List<_Option>>{
    '2': [ // Chennai
      _Option('1', 'Adambakkam'), _Option('2', 'Ambattur'), _Option('3', 'Anna Nagar'),
      _Option('4', 'Chromepet'), _Option('5', 'Egmore'), _Option('6', 'Guindy'),
      _Option('7', 'Kodambakkam'), _Option('8', 'Kolathur'), _Option('9', 'Madhavaram'),
      _Option('10', 'Madipakkam'), _Option('11', 'Mylapore'), _Option('12', 'Perambur'),
      _Option('13', 'Poonamallee'), _Option('14', 'Porur'), _Option('15', 'Purasawalkam'),
      _Option('16', 'Saidapet'), _Option('17', 'Sholinganallur'), _Option('18', 'T.Nagar'),
      _Option('19', 'Thiruvottiyur'), _Option('20', 'Velachery'), _Option('21', 'Villivakkam'),
    ],
    '8': [ // Chengalpattu
      _Option('1', 'Chengalpattu'), _Option('2', 'Chrompet'), _Option('3', 'Kancheepuram'),
      _Option('4', 'Tambaram'), _Option('5', 'Vandalur'),
    ],
    '9': [ // Kancheepuram
      _Option('1', 'Kancheepuram'), _Option('2', 'Sriperumbudur'), _Option('3', 'Uthiramerur'),
    ],
    '28': [ // Tiruvallur
      _Option('1', 'Tiruvallur'), _Option('2', 'Avadi'), _Option('3', 'Ponneri'),
      _Option('4', 'Gummidipoondi'), _Option('5', 'Poonamallee'),
    ],
    '30': [ // Vellore
      _Option('1', 'Vellore'), _Option('2', 'Arakkonam'), _Option('3', 'Arcot'),
      _Option('4', 'Gudiyatham'), _Option('5', 'Katpadi'),
    ],
    '4': [ // Coimbatore
      _Option('1', 'Coimbatore North'), _Option('2', 'Coimbatore South'),
      _Option('3', 'Pollachi'), _Option('4', 'Mettupalayam'), _Option('5', 'Valparai'),
    ],
    '16': [ // Madurai
      _Option('1', 'Madurai North'), _Option('2', 'Madurai South'),
      _Option('3', 'Melur'), _Option('4', 'Sholavandan'), _Option('5', 'Usilampatti'),
    ],
    '34': [ // Tiruchirappalli
      _Option('1', 'Tiruchirappalli'), _Option('2', 'Lalgudi'), _Option('3', 'Musiri'),
      _Option('4', 'Srirangam'), _Option('5', 'Thuraiyur'),
    ],
    '20': [ // Salem
      _Option('1', 'Salem'), _Option('2', 'Attur'), _Option('3', 'Mettur'),
      _Option('4', 'Omalur'), _Option('5', 'Rasipuram'),
    ],
    '10': [ // Erode
      _Option('1', 'Erode'), _Option('2', 'Bhavani'), _Option('3', 'Gobichettipalayam'),
      _Option('4', 'Sathyamangalam'), _Option('5', 'Perundurai'),
    ],
    '35': [ // Tirunelveli
      _Option('1', 'Tirunelveli'), _Option('2', 'Palayamkottai'), _Option('3', 'Nanguneri'),
      _Option('4', 'Sankarankovil'), _Option('5', 'Shencottah'),
    ],
  };

  bool   _autoFillingEc = false;
  _Option? _selZone;
  List<_Option> _ecDists = [];
  bool   _loadingEcDists = false;
  _Option? _selEcDist;
  List<_Option> _ecSros  = [];
  bool   _loadingEcSros  = false;
  _Option? _selEcSro;
  final _ecSurveyCtrl = TextEditingController();
  final _ecSubDivCtrl = TextEditingController();
  final _ecFromCtrl   = TextEditingController();
  final _ecToCtrl     = TextEditingController();
  bool   _fetchingEc   = false;
  List<Map<String, String>> _ecResults = [];
  List<Map<String, String>> _ecAllRecords = [];
  List<_EcEntry> _ecEntries = [];
  String? _selEcEntryId;
  String? _ecDocumentHtml;
  Uint8List? _ecPdfBytes;
  String? _ecPdfFileName;
  String? _ecSource;
  Map<String, String> _ecMeta = {};
  List<_EcPeriod> _ecPeriods = [];
  _EcPeriod? _selEcPeriod;
  bool _loadingEcPeriods = false;
  String? _ecError;
  String? _ecCaptchaSession;
  String? _ecCaptchaImage;
  bool _loadingEcCaptcha = false;
  final _ecCaptchaCtrl = TextEditingController();

  String? _selectedGiService;
  bool _loadingGvalue = false;
  bool _loadingCrop = false;
  Map<String, dynamic>? _gvalueData;
  Map<String, dynamic>? _cropData;
  String? _gvalueError;
  String? _cropError;
  String? _selectedCropSeason;

  static const _kGiServices = [
    (id: 'patta', label: 'Patta', icon: Icons.article_outlined, color: Color(0xFF1B5E20)),
    (id: 'fmb', label: 'FMB', icon: Icons.picture_as_pdf_outlined, color: Color(0xFFC62828)),
    (id: 'ec', label: 'EC', icon: Icons.account_balance_outlined, color: Color(0xFF1565C0)),
    (id: 'gvalue', label: 'G-Value', icon: Icons.currency_rupee_outlined, color: Color(0xFFE65100)),
    (id: 'crop', label: 'Crop', icon: Icons.grass_outlined, color: Color(0xFF2E7D32)),
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _ecFromCtrl.text = '01/01/2000';
    _ecToCtrl.text =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    _applySurveyNumber();
    _initDistricts();
    _loadEcPeriods();
    _loadEcZones();
    _loadEcCaptcha();
    if (widget.district != null) _tryAutoEcFill();
    else if (widget.lat != null && widget.lon != null) {
      Future.microtask(() => _resolveEcFromServer());
    }
    _surveyCtrl.addListener(_onSurveyChanged);
    _ecSurveyCtrl.addListener(_onEcSurveyChanged);
  }

  void _onSurveyChanged() {
    _pattaDebounce?.cancel();
    if (_surveyCtrl.text.trim().isEmpty) return;
    _pattaDebounce = Timer(const Duration(milliseconds: 900), _fetchPattaBySurveyNo);
  }

  void _onEcSurveyChanged() {
    _pattaDebounce?.cancel();
    _pattaDebounce = Timer(const Duration(milliseconds: 900), _maybeAutoFetchEc);
  }

  /// Mirrors a lead's survey number / sub-division into the Patta + EC inputs.
  void _applySurveyNumber() {
    final s = widget.surveyNumber?.trim() ?? '';
    if (s.isNotEmpty) {
      if (_surveyCtrl.text != s) _surveyCtrl.text = s;
      if (_ecSurveyCtrl.text != s) _ecSurveyCtrl.text = s;
    }
    final sd = widget.subDivision?.trim() ?? '';
    if (sd.isNotEmpty) {
      if (_subDivCtrl.text != sd) _subDivCtrl.text = sd;
      if (_ecSubDivCtrl.text != sd) _ecSubDivCtrl.text = sd;
    }
  }

  /// Auto-fetches Patta once district/taluk/village are resolved AND a survey
  /// number is available (lead-based mode). No-op otherwise.
  void _maybeAutoFetchPatta() {
    final s = widget.surveyNumber?.trim() ?? '';
    if (s.isEmpty || _fetchingPatta) return;
    if (_selDistrict == null || _selTaluk == null || _selVillage == null) return;
    _surveyCtrl.text = s;
    _fetchPatta();
  }

  /// Auto-fetches EC once zone/district/SRO are resolved AND a survey number is
  /// available (typed or from lead).
  void _maybeAutoFetchEc() {
    final s = _ecSurveyCtrl.text.trim().isNotEmpty
        ? _ecSurveyCtrl.text.trim()
        : (widget.surveyNumber?.trim() ?? '');
    if (s.isEmpty || _fetchingEc) return;
    if (_selZone == null || _selEcDist == null || _selEcSro == null) return;
    if (_ecSurveyCtrl.text != s) _ecSurveyCtrl.text = s;
    _searchEc();
  }

  @override
  void didUpdateWidget(covariant _GovtDocsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Location is resolved asynchronously (GPS + reverse geocode), so the
    // district/taluk/village usually arrive AFTER the first build. Re-run the
    // auto-fill whenever they change so EC & Patta populate with the location.
    final locationChanged = oldWidget.district != widget.district ||
        oldWidget.taluk != widget.taluk ||
        oldWidget.village != widget.village;
    final surveyChanged = oldWidget.surveyNumber != widget.surveyNumber ||
        oldWidget.subDivision != widget.subDivision;
    final codesChanged = oldWidget.districtCode != widget.districtCode ||
        oldWidget.talukCode != widget.talukCode ||
        oldWidget.villageCode != widget.villageCode;

    if (surveyChanged) _applySurveyNumber();

    final coordsChanged = oldWidget.lat != widget.lat || oldWidget.lon != widget.lon;
    if (coordsChanged) {
      _fmbPdfBytes = null;
      _fmbLoadError = null;
      _loadingFmb = false;
      _fmbViewerShownLen = null;
      for (final b in _subdivBundles.values) {
        b.fmbPdf = null;
        b.fmbError = null;
        b.loadingFmb = false;
      }
    }
    if (coordsChanged && surveyChanged) {
      // Parent pushed new TNGIS survey/sub-div from map tap.
      _tryAutoEcFill();
    }

    if (locationChanged && widget.district != null) {
      final match = _matchOption(_districts, widget.district);
      if (match != null && match.code != _selDistrict?.code) {
        _loadTaluks(match, autoFill: true);
      } else if (match != null) {
        // Same district but taluk/village changed — re-match down the chain.
        if (_taluks.isNotEmpty && widget.taluk != null) {
          final tMatch = _matchOption(_taluks, widget.taluk);
          if (tMatch != null && tMatch.code != _selTaluk?.code) {
            _loadVillages(tMatch, autoFill: true);
          }
        }
      }
      _tryAutoEcFill();
    } else if (surveyChanged) {
      // Same location, new survey number → dropdowns already populated, so just
      // fetch the documents directly.
      _maybeAutoFetchPatta();
      _maybeAutoFetchEc();
    }

    if (oldWidget.tngisSubdivisions != widget.tngisSubdivisions &&
        widget.tngisSubdivisions.isNotEmpty) {
      _syncSubdivisions(autoFetch: true);
    }

    final parcelReady = oldWidget.tngisParcelLoading && !widget.tngisParcelLoading;
    if ((parcelReady ||
            surveyChanged ||
            codesChanged ||
            (oldWidget.tngisSubdivisions != widget.tngisSubdivisions &&
                widget.tngisSubdivisions.isNotEmpty)) &&
        _selectedGiService == 'fmb' &&
        !widget.tngisParcelLoading) {
      Future.microtask(() {
        if (!mounted) return;
        _loadFmbForSelectedParcel();
      });
    }

    if (surveyChanged &&
        widget.surveyNumber != null &&
        widget.surveyNumber!.trim().isNotEmpty) {
      Future.microtask(() {
        if (!mounted) return;
        if (_selectedGiService == null) _onSelectGiService('patta');
      });
    }
  }

  void _syncSubdivisions({bool autoFetch = false}) {
    final keys = widget.tngisSubdivisions.map((r) => r.key).toSet();
    _subdivBundles.removeWhere((k, _) => !keys.contains(k));
    for (final row in widget.tngisSubdivisions) {
      _subdivBundles.putIfAbsent(row.key, () => _SubdivDocBundle());
      if (autoFetch && row.containsPoint) {
        _fetchPattaForSubdivision(row);
      }
      if (autoFetch && _isSelectedFmbRow(row) && _hasFmbSubdivision(row)) {
        if (_selectedGiService == 'fmb') _fetchFmbForSubdivision(row);
      }
    }
  }

  /// Sub-division at the map tap — prefer view_fmb row containing the point.
  String? _resolvedMapSub() {
    for (final row in widget.tngisSubdivisions) {
      if (row.containsPoint && row.effectiveSubDivision != null) {
        return row.effectiveSubDivision;
      }
    }
    final sd = widget.subDivision?.trim();
    if (sd != null && sd.isNotEmpty && sd != '-' && sd != widget.surveyNumber?.trim()) {
      return sd;
    }
    return null;
  }

  _TngisSubdivisionRow? _containingSubdivisionRow() {
    for (final row in widget.tngisSubdivisions) {
      if (_isSelectedFmbRow(row) && _hasFmbSubdivision(row)) return row;
    }
    return null;
  }

  _TngisSubdivisionRow? _subdivisionRowForSub(String sub) {
    final norm = sub.trim().toUpperCase();
    for (final row in widget.tngisSubdivisions) {
      final rowSub = row.effectiveSubDivision?.trim().toUpperCase();
      if (rowSub != null && rowSub == norm) return row;
    }
    return null;
  }

  /// Selected parcel survey + optional sub + TNGIS revenue codes for sketch_fmb.
  ({String survey, String? sub, String dc, String tc, String vc})? _selectedParcelForFmb() {
    final survey = widget.surveyNumber?.trim();
    if (survey == null || survey.isEmpty) return null;
    final sub = _resolvedMapSub();

    String? dc = _nonEmptyCode(widget.districtCode);
    String? tc = _nonEmptyCode(widget.talukCode);
    String? vc = _nonEmptyCode(widget.villageCode);

    for (final row in widget.tngisSubdivisions) {
      if (sub != null && row.effectiveSubDivision != sub && !_isSelectedFmbRow(row)) continue;
      dc ??= _nonEmptyCode(row.fields['District Code']);
      tc ??= _nonEmptyCode(row.fields['Taluk Code']);
      vc ??= _nonEmptyCode(row.fields['Village Code']);
      if (dc != null && tc != null && vc != null) break;
    }

    if (dc == null || tc == null || vc == null) {
      return null;
    }
    return (survey: survey, sub: sub, dc: dc, tc: tc, vc: vc);
  }

  Future<void> _loadFmbForSelectedParcel() async {
    if (widget.tngisParcelLoading) {
      setState(() {
        _loadingFmb = true;
        _fmbLoadError = null;
      });
      return;
    }

    final parcel = _selectedParcelForFmb();
    if (parcel == null) {
      setState(() {
        _loadingFmb = false;
        final survey = widget.surveyNumber?.trim();
        if (survey == null || survey.isEmpty) {
          _fmbLoadError = 'Tap the map to select a land parcel.';
        } else {
          _fmbLoadError =
              'Revenue codes not ready. Wait for parcel details to finish loading.';
        }
      });
      return;
    }

    final row = parcel.sub != null
        ? (_subdivisionRowForSub(parcel.sub!) ?? _containingSubdivisionRow())
        : _containingSubdivisionRow();
    if (row != null && row.effectiveSubDivision != null) {
      await _fetchFmbForSubdivision(row);
      return;
    }
    await _fetchFmbDirect(
      survey: parcel.survey,
      sub: parcel.sub,
      dc: parcel.dc,
      tc: parcel.tc,
      vc: parcel.vc,
      kide: row?.kide,
    );
  }

  Future<void> _fetchPattaForSubdivision(_TngisSubdivisionRow row) async {
    final bundle = _subdivBundles[row.key] ??= _SubdivDocBundle();
    if (bundle.loadingPatta) return;
    setState(() => bundle.loadingPatta = true);
    try {
      final parts = <String>[];
      if (widget.lat != null && widget.lon != null) {
        parts.add('lat=${widget.lat}');
        parts.add('lon=${widget.lon}');
      }
      parts.add('surveyNo=${Uri.encodeComponent(row.surveyNumber)}');
      final sub = row.effectiveSubDivision;
      if (sub != null && sub.isNotEmpty && sub != '-') {
        parts.add('subDiv=${Uri.encodeComponent(sub)}');
      }
      final result = await ApiClient.get(
        '/api/tnlands/patta?${parts.join('&')}',
        timeout: const Duration(seconds: 120),
      );
      bundle.documents = result['documents'] as Map<String, dynamic>?;
      if (row.containsPoint) _applyPattaResult(result);
    } on ApiException catch (e) {
      if (row.containsPoint) setState(() => _pattaError = e.message);
    } catch (e) {
      if (row.containsPoint) {
        setState(() => _pattaError = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => bundle.loadingPatta = false);
    }
  }

  bool _hasFmbSubdivision(_TngisSubdivisionRow row) =>
      row.effectiveSubDivision != null;

  void _showFmbSketchViewer(Uint8List pdfBytes, {String? fileName}) {
    final survey = widget.surveyNumber?.trim();
    final sub = _resolvedMapSub() ?? widget.subDivision?.trim();
    final name = fileName ??
        'FMB${survey != null ? '-$survey' : ''}${sub != null ? '-Sub-$sub' : ''}.pdf';
    FmbSketchViewer.show(
      context,
      pdfBytes: pdfBytes,
      fileName: name,
      survey: survey,
      subDivision: sub,
    );
  }

  void _maybeAutoOpenFmbViewer(Uint8List pdfBytes, {String? fileName}) {
    if (_selectedGiService != 'fmb') return;
    if (_fmbViewerShownLen == pdfBytes.length) return;
    _fmbViewerShownLen = pdfBytes.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedGiService != 'fmb') return;
      _showFmbSketchViewer(pdfBytes, fileName: fileName);
    });
  }

  static String? _nonEmptyCode(String? value) {
    final t = value?.trim();
    return (t != null && t.isNotEmpty) ? t : null;
  }

  /// Row matches the parcel the user selected on the map (not only strict polygon hit).
  bool _isSelectedFmbRow(_TngisSubdivisionRow row) {
    if (row.containsPoint) return true;
    final sub = _resolvedMapSub();
    if (sub != null &&
        row.effectiveSubDivision?.trim().toUpperCase() == sub.trim().toUpperCase()) {
      return true;
    }
    if (widget.tngisSubdivisions.length == 1) return true;
    return false;
  }

  String? _fmbApiPath({
    String? survey,
    String? sub,
    String? dc,
    String? tc,
    String? vc,
    String? kide,
  }) {
    final parts = <String>[];
    if (widget.lat != null && widget.lon != null) {
      parts.add('lat=${widget.lat}');
      parts.add('lon=${widget.lon}');
    }

    final surveyNo = (survey ?? widget.surveyNumber)?.trim();
    if (surveyNo == null || surveyNo.isEmpty) return null;

    final subDiv = (sub ?? _resolvedMapSub())?.trim();
    final validSub = subDiv != null &&
        subDiv.isNotEmpty &&
        subDiv != '-' &&
        subDiv != surveyNo;

    String? dcVal = _nonEmptyCode(dc) ?? _nonEmptyCode(widget.districtCode);
    String? tcVal = _nonEmptyCode(tc) ?? _nonEmptyCode(widget.talukCode);
    String? vcVal = _nonEmptyCode(vc) ?? _nonEmptyCode(widget.villageCode);
    if (dcVal == null || tcVal == null || vcVal == null) {
      for (final row in widget.tngisSubdivisions) {
        if (validSub && row.effectiveSubDivision != subDiv && !_isSelectedFmbRow(row)) {
          continue;
        }
        dcVal ??= _nonEmptyCode(row.fields['District Code']);
        tcVal ??= _nonEmptyCode(row.fields['Taluk Code']);
        vcVal ??= _nonEmptyCode(row.fields['Village Code']);
        if (dcVal != null && tcVal != null && vcVal != null) break;
      }
    }
    if (dcVal == null || tcVal == null || vcVal == null) {
      return null;
    }

    parts.add('surveyNo=${Uri.encodeComponent(surveyNo)}');
    if (validSub) {
      parts.add('subDiv=${Uri.encodeComponent(subDiv)}');
    }
    parts.add('dc=${Uri.encodeComponent(dcVal)}');
    parts.add('tc=${Uri.encodeComponent(tcVal)}');
    parts.add('vc=${Uri.encodeComponent(vcVal)}');
    final kideVal = kide?.trim();
    if (kideVal != null && kideVal.isNotEmpty && kideVal.contains('/')) {
      parts.add('kide=${Uri.encodeComponent(kideVal)}');
    }
    return '/api/tnlands/fmb?${parts.join('&')}';
  }

  Future<void> _fetchFmbDirect({
    String? survey,
    String? sub,
    String? dc,
    String? tc,
    String? vc,
    String? kide,
  }) async {
    final path = _fmbApiPath(
      survey: survey,
      sub: sub,
      dc: dc,
      tc: tc,
      vc: vc,
      kide: kide,
    );
    if (path == null) {
      setState(() => _fmbLoadError =
          'Survey and revenue codes required. Tap the map and wait for parcel details.');
      return;
    }
    setState(() {
      _loadingFmb = true;
      _fmbLoadError = null;
    });
    try {
      final bytes = await ApiClient.getBytes(path);
      if (!mounted) return;
      setState(() {
        _fmbPdfBytes = Uint8List.fromList(bytes);
        _loadingFmb = false;
      });
      _maybeAutoOpenFmbViewer(_fmbPdfBytes!);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _fmbLoadError = e.message;
        _loadingFmb = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fmbLoadError = e.toString().replaceAll('Exception: ', '');
        _loadingFmb = false;
      });
    }
  }

  Future<void> _fetchFmbForSubdivision(_TngisSubdivisionRow row) async {
    final bundle = _subdivBundles[row.key] ??= _SubdivDocBundle();
    if (bundle.loadingFmb) return;
    final selected = _isSelectedFmbRow(row);
    setState(() {
      bundle.loadingFmb = true;
      bundle.fmbError = null;
      if (selected) {
        _loadingFmb = true;
        _fmbLoadError = null;
      }
    });
    try {
      final sub = row.effectiveSubDivision;
      final path = _fmbApiPath(
        survey: row.surveyNumber,
        sub: sub,
        dc: _nonEmptyCode(row.fields['District Code']) ?? widget.districtCode,
        tc: _nonEmptyCode(row.fields['Taluk Code']) ?? widget.talukCode,
        vc: _nonEmptyCode(row.fields['Village Code']) ?? widget.villageCode,
        kide: row.kide,
      );
      if (path == null) {
        throw const ApiException(
          statusCode: 400,
          message: 'Survey, sub-division, and revenue codes required for FMB.',
        );
      }
      final bytes = await ApiClient.getBytes(path);
      bundle.fmbPdf = Uint8List.fromList(bytes);
      if (selected) {
        setState(() {
          _fmbPdfBytes = bundle.fmbPdf;
          _fmbLoadError = null;
        });
        _maybeAutoOpenFmbViewer(
          bundle.fmbPdf!,
          fileName: 'FMB Survey ${row.surveyNumber} Sub ${row.subLabel}.pdf',
        );
      }
    } on ApiException catch (e) {
      bundle.fmbError = e.message;
      if (selected) setState(() => _fmbLoadError = e.message);
    } catch (e) {
      bundle.fmbError = e.toString().replaceAll('Exception: ', '');
      if (selected) setState(() => _fmbLoadError = bundle.fmbError);
    } finally {
      if (mounted) {
        setState(() {
          bundle.loadingFmb = false;
          if (selected) _loadingFmb = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pattaDebounce?.cancel();
    _surveyCtrl.dispose(); _subDivCtrl.dispose();
    _ecSurveyCtrl.dispose(); _ecSubDivCtrl.dispose();
    _ecFromCtrl.dispose(); _ecToCtrl.dispose();
    _ecCaptchaCtrl.dispose();
    super.dispose();
  }

  // â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  List<_Option> _toOptions(List<dynamic> data) => data.map((d) {
        final m = d as Map<String, dynamic>;
        return _Option(m['code'] as String, m['name'] as String);
      }).toList();

  /// Fuzzy-match a GPS name string against a dropdown option list.
  _Option? _matchOption(List<_Option> options, String? query) {
    if (query == null || query.isEmpty) return null;
    final q = query.toLowerCase().trim();
    for (final o in options) {
      if (o.name.toLowerCase() == q) return o;
    }
    for (final o in options) {
      final n = o.name.toLowerCase();
      if (n.contains(q) || q.contains(n)) return o;
    }
    final tokens = q.split(RegExp(r'[\s\-,/]+')).where((t) => t.length > 2).toList();
    for (final o in options) {
      final n = o.name.toLowerCase();
      if (tokens.any((t) => n.contains(t))) return o;
    }
    return null;
  }

  // â”€â”€ Patta methods â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _applyPattaResult(Map<String, dynamic> result, {String? requestedSurvey}) {
    final fields = (result['fields'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, v.toString()));
    final owners = (result['owners'] as List<dynamic>? ?? []).map((o) {
      return (o as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()));
    }).toList();

    final surveyNo = fields['Survey Number'];
    final reqSurvey = requestedSurvey?.trim();
    if (surveyNo != null && surveyNo.isNotEmpty) {
      if (reqSurvey == null || reqSurvey.isEmpty || surveyNo == reqSurvey) {
        _surveyCtrl.text = surveyNo;
        _ecSurveyCtrl.text = surveyNo;
      }
    }
    final subDiv = fields['Sub Division'];
    if (subDiv != null && subDiv.isNotEmpty && subDiv != '-') {
      _subDivCtrl.text = subDiv;
      _ecSubDivCtrl.text = subDiv;
    }

    setState(() {
      _pattaSource = result['source'] as String?;
      _pattaFields = fields.isEmpty ? null : fields;
      _pattaOwners = owners;
      _pattaDocuments = result['documents'] as Map<String, dynamic>?;
      _fmbPdfBytes = null;
      _fmbLoadError = null;
      final patta = _pattaDocuments?['patta'] as Map<String, dynamic>?;
      if (patta != null && patta['official'] == true) {
        final docFields = patta['fields'] as Map<String, dynamic>?;
        if (docFields != null && docFields.isNotEmpty) {
          _pattaFields = docFields.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
        final docOwners = (patta['owners'] as List<dynamic>? ?? []).map((o) {
          return (o as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()));
        }).toList();
        if (docOwners.isNotEmpty) _pattaOwners = docOwners;
      }
      final pattaErr = patta?['error'] as String?;
      final hasPattaDoc = patta != null && patta['available'] == true
          && ((patta['html'] as String?)?.isNotEmpty == true
              || (patta['pdfBase64'] as String?)?.isNotEmpty == true);
      if (fields.isEmpty && owners.isEmpty && !hasPattaDoc
          && (patta == null || patta['available'] != true)) {
        _pattaError = pattaErr ?? (result['error'] as String?) ??
            'No patta parcel found at this location in TNGIS.';
      } else {
        _pattaError = hasPattaDoc ? null : (pattaErr ?? _pattaError);
      }
    });
  }

  Future<void> _loadFmbPdfIfNeeded() async => _loadFmbForSelectedParcel();

  /// Fetch patta from TNGIS for the active map location (or device GPS).
  Future<void> _fetchPattaForLocation({bool useDeviceGps = false}) async {
    double? lat = useDeviceGps ? null : widget.lat;
    double? lon = useDeviceGps ? null : widget.lon;

    setState(() {
      _fetchingPatta = true;
      _pattaFields = null;
      _pattaOwners = [];
      _pattaError = null;
      _pattaSource = null;
      _pattaDocuments = null;
      _fmbPdfBytes = null;
      _fmbLoadError = null;
    });

    if (lat == null || lon == null) {
      try {
        final svcOn = await Geolocator.isLocationServiceEnabled();
        if (!svcOn) {
          setState(() {
            _pattaError =
                'Tap the map to set a location, or enable GPS on your device.';
            _fetchingPatta = false;
          });
          return;
        }
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm == LocationPermission.denied ||
            perm == LocationPermission.deniedForever) {
          setState(() {
            _pattaError = 'Tap the map to set a location, or allow GPS permission.';
            _fetchingPatta = false;
          });
          return;
        }
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        lat = pos.latitude;
        lon = pos.longitude;
      } catch (e) {
        setState(() {
          _pattaError =
              'Set a location on the map (tap the map), then tap Fetch Patta.';
          _fetchingPatta = false;
        });
        return;
      }
    }

    try {
      var params = 'lat=$lat&lon=$lon';
      final surveyNo = _surveyCtrl.text.trim();
      final subDiv = _subDivCtrl.text.trim();
      if (surveyNo.isNotEmpty) {
        params += '&surveyNo=${Uri.encodeComponent(surveyNo)}';
      }
      if (subDiv.isNotEmpty) {
        params += '&subDiv=${Uri.encodeComponent(subDiv)}';
      }
      final result = await ApiClient.get(
        '/api/tnlands/patta?$params',
        timeout: const Duration(seconds: 180),
      );
      _applyPattaResult(result, requestedSurvey: surveyNo);
    } on ApiException catch (e) {
      setState(() => _pattaError = e.message);
    } on TimeoutException {
      setState(() => _pattaError =
          'Government servers are slow (can take 1–2 min). Try again.');
    } catch (e) {
      setState(() =>
          _pattaError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _fetchingPatta = false);
    }
  }

  Future<void> _initDistricts() async {
    setState(() => _initingPatta = true);
    try {
      final data = await ApiClient.getList('/api/tnlands/districts');
      final loaded = _toOptions(data);
      setState(() {
        _districts = loaded.isNotEmpty ? loaded : _kStaticDistricts;
        if (widget.district != null) {
          _selDistrict = _matchOption(_districts, widget.district);
          if (_selDistrict != null) {
            Future.microtask(() => _loadTaluks(_selDistrict!, autoFill: true));
          }
        }
      });
    } catch (_) {
      // Fall back to static list but still try to auto-match the district
      setState(() {
        _districts = _kStaticDistricts;
        if (widget.district != null) {
          _selDistrict = _matchOption(_kStaticDistricts, widget.district);
          if (_selDistrict != null) {
            Future.microtask(() => _loadTaluks(_selDistrict!, autoFill: true));
          }
        }
      });
    } finally {
      setState(() => _initingPatta = false);
    }
  }

  Future<void> _loadTaluks(_Option district, {bool autoFill = false}) async {
    setState(() {
      _selDistrict = district;
      _taluks = []; _selTaluk = null;
      _villages = []; _selVillage = null;
      _loadingTaluks = true; _talukError = null;
    });
    try {
      final data = await ApiClient.getList('/api/tnlands/taluks?dc=${district.code}');
      final loaded = _toOptions(data);
      setState(() { _taluks = loaded; _loadingTaluks = false; });
      if (autoFill && widget.taluk != null && loaded.isNotEmpty) {
        final match = _matchOption(loaded, widget.taluk);
        if (match != null) await _loadVillages(match, autoFill: true);
      }
    } catch (e) {
      setState(() {
        _loadingTaluks = false;
        _talukError = 'Failed to load taluks. Tap to retry.';
      });
    }
  }

  Future<void> _loadVillages(_Option taluk, {bool autoFill = false}) async {
    setState(() {
      _selTaluk = taluk;
      _villages = []; _selVillage = null;
      _loadingVillages = true; _villageError = null;
    });
    try {
      final data = await ApiClient.getList(
          '/api/tnlands/villages?dc=${_selDistrict!.code}&tc=${taluk.code}');
      final loaded = _toOptions(data);
      setState(() {
        _villages = loaded;
        if (autoFill && widget.village != null && loaded.isNotEmpty) {
          _selVillage = _matchOption(loaded, widget.village);
        }
        _loadingVillages = false;
      });
      if (autoFill) _maybeAutoFetchPatta();
    } catch (e) {
      setState(() {
        _loadingVillages = false;
        _villageError = 'Failed to load villages. Tap to retry.';
      });
    }
  }

  /// TNGIS lookup by survey number — uses map location when available.
  Future<void> _fetchPattaBySurveyNo() async {
    final surveyNo = _surveyCtrl.text.trim();
    if (surveyNo.isEmpty) return;

    setState(() {
      _fetchingPatta = true;
      _pattaFields = null;
      _pattaOwners = [];
      _pattaError = null;
      _pattaSource = null;
      _pattaDocuments = null;
      _fmbPdfBytes = null;
      _fmbLoadError = null;
    });
    try {
      final subDiv = _subDivCtrl.text.trim();
      var params = 'surveyNo=${Uri.encodeComponent(surveyNo)}';
      if (subDiv.isNotEmpty) params += '&subDiv=${Uri.encodeComponent(subDiv)}';
      if (widget.lat != null && widget.lon != null) {
        params += '&lat=${widget.lat}&lon=${widget.lon}';
      }
      final result = await ApiClient.get(
        '/api/tnlands/patta?$params',
        timeout: const Duration(seconds: 180),
      );
      _applyPattaResult(result, requestedSurvey: surveyNo);
    } on ApiException catch (e) {
      setState(() => _pattaError = e.message);
    } on TimeoutException {
      setState(() => _pattaError =
          'Government servers are slow (can take 1–2 min). Try again.');
    } catch (e) {
      setState(() => _pattaError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _fetchingPatta = false);
    }
  }

  Future<void> _fetchPatta() async {
    if (_selDistrict == null || _selTaluk == null ||
        _selVillage == null || _surveyCtrl.text.trim().isEmpty) { return; }
    setState(() {
      _fetchingPatta = true;
      _pattaFields = null;
      _pattaOwners = [];
      _pattaError = null;
      _pattaSource = null;
      _pattaDocuments = null;
      _fmbPdfBytes = null;
      _fmbLoadError = null;
    });
    try {
      var params = 'dc=${_selDistrict!.code}'
          '&tc=${_selTaluk!.code}'
          '&vc=${_selVillage!.code}'
          '&surveyNo=${Uri.encodeComponent(_surveyCtrl.text.trim())}'
          '&subDiv=${Uri.encodeComponent(_subDivCtrl.text.trim())}';
      if (widget.lat != null && widget.lon != null) {
        params += '&lat=${widget.lat}&lon=${widget.lon}';
      }
      final result = await ApiClient.get(
        '/api/tnlands/patta?$params',
        timeout: const Duration(seconds: 180),
      );
      _applyPattaResult(result);
    } on ApiException catch (e) {
      setState(() => _pattaError = e.message);
    } on TimeoutException {
      setState(() => _pattaError =
          'Government servers are slow (can take 1–2 min). Try again.');
    } catch (e) {
      setState(() => _pattaError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _fetchingPatta = false);
    }
  }

  // â”€â”€ EC methods â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _loadEcZones() async {
    try {
      final data = await ApiClient.getList('/api/tnlands/ec/zones');
      final loaded = _toOptions(data);
      if (loaded.isNotEmpty) setState(() => _ecZones = loaded);
    } catch (_) {}
  }

  Future<void> _loadEcCaptcha() async {
    setState(() => _loadingEcCaptcha = true);
    try {
      final result = await ApiClient.get('/api/tnlands/ec/captcha');
      setState(() {
        _ecCaptchaSession = result['sessionId'] as String?;
        _ecCaptchaImage = result['captchaImage'] as String?;
        _ecCaptchaCtrl.clear();
      });
    } catch (e) {
      setState(() => _ecError = 'Could not load EC captcha. Tap refresh to retry.');
    } finally {
      setState(() => _loadingEcCaptcha = false);
    }
  }

  // ── EC methods ─────────────────────────────────────────────────────────────

  Future<void> _loadEcPeriods() async {
    setState(() => _loadingEcPeriods = true);
    try {
      final data = await ApiClient.getList('/api/tnlands/ec/periods');
      final loaded = data.map((d) => _EcPeriod.fromJson(d as Map<String, dynamic>)).toList();
      setState(() {
        _ecPeriods = loaded;
        _selEcPeriod ??= loaded.isNotEmpty ? loaded.first : null;
      });
    } catch (_) {
      final now = DateTime.now();
      final y = now.year;
      setState(() {
        _ecPeriods = [
          _EcPeriod('$y', '$y', '01/01/$y', '31/12/$y'),
          const _EcPeriod('full', 'Full period (2000–today)', '01/01/2000', ''),
        ];
        if (_ecPeriods.last.toDate.isEmpty) {
          final t = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/$y';
          _ecPeriods = [
            _EcPeriod('$y', '$y ($t)', '01/01/$y', '31/12/$y'),
            _EcPeriod('full', 'Full period', '01/01/2000', t),
          ];
        }
        _selEcPeriod ??= _ecPeriods.first;
      });
    } finally {
      setState(() => _loadingEcPeriods = false);
    }
  }

  void _applyEcSearchResult(Map<String, dynamic> result) {
    final records = (result['records'] as List<dynamic>? ?? []).map((r) {
      return (r as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()));
    }).toList();
    final entries = (result['entries'] as List<dynamic>? ?? []).map((e) {
      final m = e as Map<String, dynamic>;
      return _EcEntry(m['id'] as String, m['label'] as String);
    }).toList();
    final doc = result['document'] as Map<String, dynamic>?;
    final meta = (result['meta'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, v.toString()));
    final pdfB64 = doc?['pdfBase64'] as String?;
    Uint8List? pdfBytes;
    if (pdfB64 != null && pdfB64.isNotEmpty) {
      try {
        pdfBytes = Uint8List.fromList(base64.decode(pdfB64));
      } catch (_) {}
    }

    setState(() {
      _ecSource = result['source'] as String?;
      _ecAllRecords = records;
      _ecResults = records;
      _ecEntries = entries;
      _selEcEntryId = entries.length == 1 ? entries.first.id : 'all';
      _ecMeta = meta;
      _ecDocumentHtml = doc?['html'] as String?;
      _ecPdfBytes = pdfBytes;
      _ecPdfFileName = doc?['pdfFileName'] as String?;
      final msg = result['message'] as String?;
      final hasPdf = pdfBytes != null && pdfBytes.isNotEmpty;
      final hasHtml = (_ecDocumentHtml?.length ?? 0) > 200;
      _ecError = (records.isEmpty && !hasPdf && !hasHtml)
          ? (msg ?? 'No EC records for this period.')
          : null;
    });
    _refreshEcEntryPreview();
  }

  String _buildEcHtmlForRecords(List<Map<String, String>> records) {
    if (records.isEmpty) return '<p>No records</p>';
    final headers = records.first.keys.toList();
    final esc = (String s) => s
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final metaRows = _ecMeta.entries
        .map((e) => '<tr><th>${esc(e.key)}</th><td>${esc(e.value)}</td></tr>')
        .join();
    final headerRow = headers.map((h) => '<th>${esc(h)}</th>').join();
    final bodyRows = records.map((r) {
      return '<tr>${headers.map((h) => '<td>${esc(r[h] ?? '')}</td>').join()}</tr>';
    }).join();
    return '''<!DOCTYPE html><html><head><meta charset="utf-8"><style>
      body{font-family:Georgia,serif;margin:20px;color:#111}
      h1{font-size:18px;color:#C62828}
      table{border-collapse:collapse;width:100%;margin:12px 0;font-size:12px}
      th,td{border:1px solid #ccc;padding:6px 8px;text-align:left}
      th{background:#ffebee}
    </style></head><body>
    <h1>Encumbrance Certificate (EC)</h1>
    <p style="font-size:11px;color:#555">Source: tnreginet.gov.in</p>
    <table>$metaRows</table>
    <table><thead><tr>$headerRow</tr></thead><tbody>$bodyRows</tbody></table>
    </body></html>''';
  }

  void _refreshEcEntryPreview() {
    if (_ecAllRecords.isEmpty) return;
    List<Map<String, String>> show = _ecAllRecords;
    if (_selEcEntryId != null && _selEcEntryId != 'all') {
      final idx = int.tryParse(_selEcEntryId!);
      if (idx != null && idx >= 0 && idx < _ecAllRecords.length) {
        show = [_ecAllRecords[idx]];
      }
    }
    setState(() => _ecDocumentHtml = _buildEcHtmlForRecords(show));
  }

  Future<bool> _resolveEcFromServer({
    String? district,
    String? taluk,
    String? village,
  }) async {
    setState(() { _autoFillingEc = true; _ecError = null; });

    var params = '';
    if (widget.lat != null && widget.lon != null) {
      params = 'lat=${widget.lat}&lon=${widget.lon}';
    }
    final dist = district ?? widget.district ?? _pattaFields?['District'];
    final tk = taluk ?? widget.taluk ?? _pattaFields?['Taluk'];
    final vill = village ?? widget.village ?? _pattaFields?['Village'];
    if (dist != null && dist.isNotEmpty) {
      params += '${params.isEmpty ? '' : '&'}district=${Uri.encodeComponent(dist)}';
    }
    if (tk != null && tk.isNotEmpty) {
      params += '&taluk=${Uri.encodeComponent(tk)}';
    }
    if (vill != null && vill.isNotEmpty) {
      params += '&village=${Uri.encodeComponent(vill)}';
    }

    if (params.isEmpty) {
      setState(() {
        _autoFillingEc = false;
        _ecError = 'Set a map location first (tap the map).';
      });
      return false;
    }

    try {
      final result = await ApiClient.get(
        '/api/tnlands/ec/resolve?$params',
        timeout: const Duration(seconds: 45),
      );
      final zone = result['zone'] as Map<String, dynamic>?;
      final distObj = result['district'] as Map<String, dynamic>?;
      final sros = (result['sros'] as List<dynamic>? ?? [])
          .map((s) => _Option(s['code'] as String, s['name'] as String))
          .toList();
      final suggested = result['suggestedSro'] as Map<String, dynamic>?;

      if (zone == null || distObj == null || sros.isEmpty) {
        setState(() {
          _ecError = 'Could not load SRO list for this district.';
          _showManualEc = true;
        });
        return false;
      }

      setState(() {
        _selZone = _Option(zone['code'] as String, zone['name'] as String);
        _selEcDist = _Option(distObj['code'] as String, distObj['name'] as String);
        _ecDists = [_selEcDist!];
        _ecSros = sros;
        _selEcSro = suggested != null
            ? _Option(suggested['code'] as String, suggested['name'] as String)
            : sros.first;
        _ecError = null;
      });
      return true;
    } on ApiException catch (e) {
      setState(() {
        _ecError = e.message;
        _showManualEc = true;
      });
      return false;
    } catch (e) {
      setState(() {
        _ecError = e.toString().replaceAll('Exception: ', '');
        _showManualEc = true;
      });
      return false;
    } finally {
      setState(() => _autoFillingEc = false);
    }
  }

  Future<void> _fetchEcForLocation() async {
    if (_selEcPeriod == null) {
      setState(() => _ecError = 'Select an EC period first.');
      return;
    }
    if (_ecCaptchaSession == null || _ecCaptchaCtrl.text.trim().isEmpty) {
      setState(() => _ecError = 'Enter the captcha code from the image below.');
      if (_ecCaptchaImage == null) await _loadEcCaptcha();
      return;
    }

    setState(() {
      _fetchingEc = true;
      _ecError = null;
      _ecDocumentHtml = null;
      _ecPdfBytes = null;
      _ecPdfFileName = null;
      _ecAllRecords = [];
      _ecEntries = [];
      _ecResults = [];
    });

    if (_ecSurveyCtrl.text.trim().isEmpty) {
      final fromPatta = _pattaFields?['Survey Number'];
      if (fromPatta != null && fromPatta.isNotEmpty) {
        _ecSurveyCtrl.text = fromPatta;
      } else if (widget.surveyNumber != null && widget.surveyNumber!.isNotEmpty) {
        _ecSurveyCtrl.text = widget.surveyNumber!;
      }
    }

    if (_selZone == null || _selEcDist == null || _selEcSro == null) {
      final ok = await _resolveEcFromServer();
      if (!ok) {
        setState(() => _fetchingEc = false);
        return;
      }
    }

    if (_selZone == null || _selEcDist == null || _selEcSro == null) {
      setState(() {
        _ecError = 'Could not resolve Zone/District/SRO. Use manual selection below.';
        _showManualEc = true;
        _fetchingEc = false;
      });
      return;
    }

    await _searchEcWithPeriod(_selEcPeriod!);
  }

  Future<void> _searchEcWithPeriod(_EcPeriod period, {bool tryAlternateSros = true}) async {
    _ecFromCtrl.text = period.fromDate;
    _ecToCtrl.text = period.toDate;
    if (_selZone == null || _selEcDist == null || _selEcSro == null ||
        _ecSurveyCtrl.text.trim().isEmpty) {
      setState(() {
        _ecError = 'Survey number and SRO are required. Fetch patta first or enter survey no.';
        _fetchingEc = false;
      });
      return;
    }
    setState(() { _fetchingEc = true; _ecError = null; });
    try {
      if (_ecCaptchaSession == null || _ecCaptchaCtrl.text.trim().isEmpty) {
        setState(() {
          _ecError = 'Enter the captcha code from the image below.';
          _fetchingEc = false;
        });
        return;
      }
      var params = 'zone=${_selZone!.code}'
          '&dc=${_selEcDist!.code}'
          '&sro=${Uri.encodeComponent(_selEcSro!.code)}'
          '&surveyNo=${Uri.encodeComponent(_ecSurveyCtrl.text.trim())}'
          '&subDiv=${Uri.encodeComponent(_ecSubDivCtrl.text.trim())}'
          '&fromDate=${Uri.encodeComponent(period.fromDate)}'
          '&toDate=${Uri.encodeComponent(period.toDate)}'
          '&districtName=${Uri.encodeComponent(_selEcDist!.name)}'
          '&sroName=${Uri.encodeComponent(_selEcSro!.name)}'
          '&ecSession=${Uri.encodeComponent(_ecCaptchaSession!)}'
          '&captcha=${Uri.encodeComponent(_ecCaptchaCtrl.text.trim())}';
      if (widget.village != null && widget.village!.isNotEmpty) {
        params += '&villageName=${Uri.encodeComponent(widget.village!)}';
      } else if (_pattaFields?['Village'] != null) {
        params += '&villageName=${Uri.encodeComponent(_pattaFields!['Village']!)}';
      }
      final result = await ApiClient.get(
        '/api/tnlands/ec/search?$params',
        timeout: const Duration(seconds: 90),
      );
      final count = result['count'] as int? ?? 0;
      final doc = result['document'] as Map<String, dynamic>?;
      final hasPdf = (doc?['pdfBase64'] as String?)?.isNotEmpty == true;
      if (tryAlternateSros &&
          count == 0 &&
          !hasPdf &&
          _ecSros.length > 1) {
        final startIdx = _ecSros.indexWhere((s) => s.code == _selEcSro?.code);
        for (var i = 0; i < _ecSros.length && i < 10; i++) {
          if (i == startIdx) continue;
          final altSro = _ecSros[i];
          setState(() => _selEcSro = altSro);
          var altParams = 'zone=${_selZone!.code}'
              '&dc=${_selEcDist!.code}'
              '&sro=${Uri.encodeComponent(altSro.code)}'
              '&surveyNo=${Uri.encodeComponent(_ecSurveyCtrl.text.trim())}'
              '&subDiv=${Uri.encodeComponent(_ecSubDivCtrl.text.trim())}'
              '&fromDate=${Uri.encodeComponent(period.fromDate)}'
              '&toDate=${Uri.encodeComponent(period.toDate)}'
              '&districtName=${Uri.encodeComponent(_selEcDist!.name)}'
              '&sroName=${Uri.encodeComponent(altSro.name)}'
              '&ecSession=${Uri.encodeComponent(_ecCaptchaSession!)}'
              '&captcha=${Uri.encodeComponent(_ecCaptchaCtrl.text.trim())}';
          if (widget.village != null && widget.village!.isNotEmpty) {
            altParams += '&villageName=${Uri.encodeComponent(widget.village!)}';
          } else if (_pattaFields?['Village'] != null) {
            altParams += '&villageName=${Uri.encodeComponent(_pattaFields!['Village']!)}';
          }
          try {
            final altResult = await ApiClient.get(
              '/api/tnlands/ec/search?$altParams',
              timeout: const Duration(seconds: 90),
            );
            final altCount = altResult['count'] as int? ?? 0;
            final altDoc = altResult['document'] as Map<String, dynamic>?;
            if (altCount > 0 || (altDoc?['pdfBase64'] as String?)?.isNotEmpty == true) {
              _applyEcSearchResult(altResult);
              await _loadEcCaptcha();
              return;
            }
          } on ApiException catch (_) {}
        }
      }
      _applyEcSearchResult(result);
      await _loadEcCaptcha();
    } on ApiException catch (e) {
      if (tryAlternateSros &&
          e.statusCode == 404 &&
          _ecSros.length > 1) {
        final startIdx = _ecSros.indexWhere((s) => s.code == _selEcSro?.code);
        for (var i = 0; i < _ecSros.length && i < 10; i++) {
          if (i == startIdx) continue;
          setState(() => _selEcSro = _ecSros[i]);
          try {
            await _searchEcWithPeriod(period, tryAlternateSros: false);
            return;
          } on ApiException catch (_) {}
        }
      }
      setState(() => _ecError = e.message);
      if (e.statusCode == 400) await _loadEcCaptcha();
    } catch (e) {
      setState(() => _ecError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _fetchingEc = false);
    }
  }

  Future<void> _tryAutoEcFill() async {
    if (widget.district == null && widget.lat == null) return;
    await _resolveEcFromServer();
  }

  /// GPS-based EC auto-fill — uses map pin + resolve API.
  Future<void> _fetchEcByGps() async {
    await _resolveEcFromServer();
  }

  Future<void> _loadEcDistricts(_Option zone) async {
    setState(() {
      _selZone = zone; _ecDists = []; _selEcDist = null;
      _ecSros = []; _selEcSro = null; _loadingEcDists = true;
    });
    try {
      final data = await ApiClient.getList(
          '/api/tnlands/ec/districts?zone=${zone.code}');
      final loaded = _toOptions(data);
      setState(() {
        _ecDists = loaded.isNotEmpty
            ? loaded
            : (_kStaticEcDistricts[zone.code] ?? []);
        _loadingEcDists = false;
      });
    } catch (_) {
      setState(() {
        _ecDists = _kStaticEcDistricts[zone.code] ?? [];
        _loadingEcDists = false;
      });
    }
  }

  Future<void> _loadEcSros(_Option district, {bool autoFirst = false}) async {
    setState(() {
      _selEcDist = district; _ecSros = []; _selEcSro = null;
      _loadingEcSros = true;
    });
    try {
      final data = await ApiClient.getList(
          '/api/tnlands/ec/sros?zone=${_selZone!.code}&dc=${district.code}');
      final loaded = _toOptions(data);
      setState(() {
        _ecSros = loaded.isNotEmpty ? loaded : (_kStaticEcSros[district.code] ?? []);
        if (autoFirst && _ecSros.isNotEmpty) _selEcSro = _ecSros.first;
        _loadingEcSros = false;
      });
      if (autoFirst) _maybeAutoFetchEc();
    } catch (_) {
      final fallback = _kStaticEcSros[district.code] ?? [];
      setState(() {
        _ecSros = fallback;
        if (autoFirst && fallback.isNotEmpty) _selEcSro = fallback.first;
        _loadingEcSros = false;
      });
      if (autoFirst) _maybeAutoFetchEc();
    }
  }

  Future<void> _searchEc() async {
    if (_selEcPeriod != null) {
      await _searchEcWithPeriod(_selEcPeriod!);
      return;
    }
    if (_selZone == null || _selEcDist == null || _selEcSro == null ||
        _ecSurveyCtrl.text.trim().isEmpty ||
        _ecFromCtrl.text.trim().isEmpty || _ecToCtrl.text.trim().isEmpty) {
      setState(() => _ecError = 'Fill all fields before searching.');
      return;
    }
    setState(() { _fetchingEc = true; _ecResults = []; _ecError = null; });
    try {
      if (_ecCaptchaSession == null || _ecCaptchaCtrl.text.trim().isEmpty) {
        setState(() {
          _ecError = 'Enter the captcha code from the image below.';
          _fetchingEc = false;
        });
        return;
      }
      final params = 'zone=${_selZone!.code}'
          '&dc=${_selEcDist!.code}'
          '&sro=${Uri.encodeComponent(_selEcSro!.code)}'
          '&surveyNo=${Uri.encodeComponent(_ecSurveyCtrl.text.trim())}'
          '&subDiv=${Uri.encodeComponent(_ecSubDivCtrl.text.trim())}'
          '&fromDate=${Uri.encodeComponent(_ecFromCtrl.text.trim())}'
          '&toDate=${Uri.encodeComponent(_ecToCtrl.text.trim())}'
          '&districtName=${Uri.encodeComponent(_selEcDist!.name)}'
          '&sroName=${Uri.encodeComponent(_selEcSro!.name)}'
          '&ecSession=${Uri.encodeComponent(_ecCaptchaSession!)}'
          '&captcha=${Uri.encodeComponent(_ecCaptchaCtrl.text.trim())}';
      final result = await ApiClient.get(
        '/api/tnlands/ec/search?$params',
        timeout: const Duration(seconds: 90),
      );
      _applyEcSearchResult(result);
      await _loadEcCaptcha();
    } on ApiException catch (e) {
      setState(() => _ecError = e.message);
      if (e.statusCode == 400) await _loadEcCaptcha();
    } catch (e) {
      setState(() => _ecError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _fetchingEc = false);
    }
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Tamil Nilam — Land Records',
      icon: Icons.layers_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildGiParcelHeader(),
        const SizedBox(height: 10),
        const Text(
          'Click on the below icons to view more details',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFC62828)),
        ),
        const SizedBox(height: 10),
        _buildGiServiceBoxes(),
        if (_selectedGiService != null) ...[
          const SizedBox(height: 14),
          _buildGiServiceDetail(_selectedGiService!),
        ] else ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              'Tap Patta, FMB, EC, G-Value, or Crop above to load details from Tamil Nilam.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _buildGiParcelHeader() {
    final survey = widget.surveyNumber?.trim();
    final sub = widget.subDivision?.trim();
    final hasPlot = widget.lat != null && widget.lon != null;
    final centroid = widget.centroid?.trim().isNotEmpty == true
        ? widget.centroid!
        : (hasPlot ? '${widget.lat}, ${widget.lon}' : '-');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Land Parcel Information',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1565C0))),
        const SizedBox(height: 10),
        _buildGiHeaderRow('ULPIN', widget.ulpin?.isNotEmpty == true ? widget.ulpin! : '-'),
        _buildGiHeaderRow('Centroid', centroid),
        _buildGiHeaderRow('Survey Number', survey?.isNotEmpty == true ? survey! : '-'),
        _buildGiHeaderRow('Sub Division', sub != null && sub.isNotEmpty && sub != '-' ? sub : '-'),
        if (widget.village != null && widget.village!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${widget.village}${widget.taluk != null ? ', ${widget.taluk}' : ''}',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
        if (widget.tngisGiViewerUrl != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(widget.tngisGiViewerUrl!),
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('Open in Tamil Nilam GI Viewer', style: TextStyle(fontSize: 11)),
          ),
        ],
      ]),
    );
  }

  Widget _buildGiHeaderRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.35),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildGiServiceBoxes() {
    return LayoutBuilder(builder: (context, constraints) {
      Widget boxFor(({
        String id,
        String label,
        IconData icon,
        Color color,
      }) svc, {bool isLast = false}) {
        final selected = _selectedGiService == svc.id;
        final card = widget.giServices?[svc.id] as Map?;
        final summary = card?['summary']?.toString().trim();
        final available = card?['available'] != false;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 6),
            child: Material(
              color: selected ? svc.color.withValues(alpha: 0.14) : Colors.white,
              elevation: selected ? 2 : 0,
              shadowColor: svc.color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => _onSelectGiService(svc.id),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? svc.color : svc.color.withValues(alpha: 0.4),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(svc.icon, color: svc.color, size: 28),
                    const SizedBox(height: 6),
                    Text(svc.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: svc.color,
                        )),
                    if (summary != null && summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 8,
                              height: 1.2,
                              color: svc.color.withValues(alpha: 0.8))),
                    ] else if (!available) ...[
                      const SizedBox(height: 4),
                      Text('N/A',
                          style: TextStyle(
                              fontSize: 8, color: Colors.grey.shade500)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        );
      }

      if (constraints.maxWidth >= 520) {
        return Row(
          children: [
            for (var i = 0; i < _kGiServices.length; i++)
              boxFor(_kGiServices[i], isLast: i == _kGiServices.length - 1),
          ],
        );
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _kGiServices.map((svc) {
            final selected = _selectedGiService == svc.id;
            final card = widget.giServices?[svc.id] as Map?;
            final summary = card?['summary']?.toString().trim();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 88,
                child: Material(
                  color: selected ? svc.color.withValues(alpha: 0.14) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () => _onSelectGiService(svc.id),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? svc.color : svc.color.withValues(alpha: 0.4),
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Column(children: [
                        Icon(svc.icon, color: svc.color, size: 26),
                        const SizedBox(height: 4),
                        Text(svc.label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: svc.color)),
                        if (summary != null && summary.isNotEmpty)
                          Text(summary,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 8, color: svc.color.withValues(alpha: 0.8))),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  Future<void> _onSelectGiService(String id) async {
    if (_selectedGiService == id) {
      setState(() => _selectedGiService = null);
      return;
    }
    setState(() {
      _selectedGiService = id;
      if (id != 'crop') _selectedCropSeason = null;
    });
    await _loadGiService(id);
  }

  Future<void> _loadGiService(String id) async {
    switch (id) {
      case 'patta':
        if (widget.tngisSubdivisions.isNotEmpty) {
          _syncSubdivisions(autoFetch: true);
        } else if (widget.lat != null && widget.lon != null) {
          await _fetchPattaForLocation();
        }
        break;
      case 'fmb':
        await _loadFmbForSelectedParcel();
        break;
      case 'ec':
        await _fetchGiEcFromTngis();
        break;
      case 'gvalue':
        await _fetchGiDetail('gvalue');
        break;
      case 'crop':
        await _fetchGiDetail('crop');
        break;
    }
  }

  Future<void> _fetchGiDetail(String type) async {
    if (widget.lat == null || widget.lon == null) {
      setState(() {
        if (type == 'gvalue') _gvalueError = 'Tap the map to set a plot location.';
        if (type == 'crop') _cropError = 'Tap the map to set a plot location.';
      });
      return;
    }
    setState(() {
      if (type == 'gvalue') {
        _loadingGvalue = true;
        _gvalueError = null;
      } else {
        _loadingCrop = true;
        _cropError = null;
      }
    });
    try {
      final parts = <String>[
        'lat=${widget.lat}',
        'lon=${widget.lon}',
        'type=$type',
      ];
      final survey = widget.surveyNumber?.trim();
      final sub = widget.subDivision?.trim();
      if (survey != null && survey.isNotEmpty) {
        parts.add('surveyNo=${Uri.encodeComponent(survey)}');
      }
      if (sub != null && sub.isNotEmpty && sub != '-') {
        parts.add('subDiv=${Uri.encodeComponent(sub)}');
      }
      final data = await ApiClient.get('/api/tnlands/tngis/gi-detail?${parts.join('&')}');
      setState(() {
        if (type == 'gvalue') {
          _gvalueData = data;
          _gvalueError = null;
        } else {
          _cropData = data;
          _cropError = null;
        }
      });
    } on ApiException catch (e) {
      setState(() {
        if (type == 'gvalue') _gvalueError = e.message;
        if (type == 'crop') _cropError = e.message;
      });
    } catch (e) {
      setState(() {
        final msg = e.toString().replaceAll('Exception: ', '');
        if (type == 'gvalue') _gvalueError = msg;
        if (type == 'crop') _cropError = msg;
      });
    } finally {
      setState(() {
        if (type == 'gvalue') _loadingGvalue = false;
        if (type == 'crop') _loadingCrop = false;
      });
    }
  }

  Widget _buildGiServiceDetail(String id) {
    final svc = _kGiServices.firstWhere((s) => s.id == id);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: svc.color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: svc.color.withValues(alpha: 0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${svc.label} details',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: svc.color)),
        const SizedBox(height: 10),
        switch (id) {
          'patta' => _buildGiPattaDetail(),
          'fmb' => _buildGiFmbDetail(),
          'ec' => _buildGiEcDetail(),
          'gvalue' => _buildGiGvalueDetail(),
          'crop' => _buildGiCropDetail(),
          _ => const SizedBox.shrink(),
        },
      ]),
    );
  }

  Widget _buildGiPattaDetail() {
    if (_fetchingPatta) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      ));
    }
    if (widget.tngisSubdivisions.isNotEmpty) {
      return Column(
        children: widget.tngisSubdivisions.map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildGiSubdivisionPreview(row),
        )).toList(),
      );
    }
    final patta = _pattaDocuments?['patta'] as Map<String, dynamic>?;
    if (_hasPattaPdf(patta)) {
      return _buildPattaDocPreview(patta, title: 'Patta / Chitta', pdfOnly: true);
    }
    if (_pattaError != null) {
      return Text(_pattaError!, style: TextStyle(fontSize: 11, color: Colors.orange.shade900));
    }
    return _buildGiNoResult();
  }

  bool _hasPattaPdf(Map<String, dynamic>? patta) {
    final pdf = patta?['pdfBase64'] as String?;
    return patta?['available'] == true && pdf != null && pdf.isNotEmpty;
  }

  Widget _buildGiNoResult([String message = 'No result found for this plot.']) {
    return Text(message, style: TextStyle(fontSize: 11, color: Colors.grey.shade600));
  }

  Widget _buildGiFmbDetail() {
    if (widget.tngisParcelLoading) {
      return Column(children: [
        const Center(child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        )),
        const SizedBox(height: 6),
        Text(
          'Resolving plot at tap point…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ]);
    }
    final loading = widget.tngisSubdivisions.any((r) => (_subdivBundles[r.key]?.loadingFmb ?? false))
        || _loadingFmb;
    if (loading) {
      return Column(children: [
        const Center(child: Padding(
          padding: EdgeInsets.all(16),
          child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        )),
        const SizedBox(height: 6),
        Text(
          'Fetching FMB for Survey ${widget.surveyNumber ?? '—'} · Sub ${_resolvedMapSub() ?? widget.subDivision ?? '—'}…',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ]);
    }

    Uint8List? pdfBytes = _fmbPdfBytes;
    String fileName = 'FMB Sketch.pdf';
    if (pdfBytes == null && widget.tngisSubdivisions.isNotEmpty) {
      for (final row in widget.tngisSubdivisions) {
        if (!_isSelectedFmbRow(row)) continue;
        final bundle = _subdivBundles[row.key];
        if (bundle?.fmbPdf != null) {
          pdfBytes = bundle!.fmbPdf;
          fileName = 'FMB Survey ${row.surveyNumber} Sub ${row.subLabel}.pdf';
          break;
        }
      }
      pdfBytes ??= widget.tngisSubdivisions
          .where(_isSelectedFmbRow)
          .map((r) => _subdivBundles[r.key]?.fmbPdf)
          .firstWhere((b) => b != null, orElse: () => null);
      if (pdfBytes != null && fileName == 'FMB Sketch.pdf') {
        for (final row in widget.tngisSubdivisions) {
          if (_subdivBundles[row.key]?.fmbPdf == pdfBytes) {
            fileName = 'FMB Survey ${row.surveyNumber} Sub ${row.subLabel}.pdf';
            break;
          }
        }
      }
    }

    if (pdfBytes != null && pdfBytes.isNotEmpty) {
      final sub = _resolvedMapSub() ?? widget.subDivision?.trim();
      final survey = widget.surveyNumber?.trim();
      final fileName = 'FMB${survey != null ? '-$survey' : ''}${sub != null ? '-Sub-$sub' : ''}.pdf';
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EAF6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF3949AB).withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF1A237E), size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub != null && sub.isNotEmpty && sub != '-'
                          ? 'FMB Sketch · Survey ${survey ?? ''} · Sub $sub'
                          : 'FMB Sketch · Survey ${survey ?? ''} (general)',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sub != null && sub.isNotEmpty && sub != '-'
                          ? 'Official TSLR/FMB sketch with government seal · ${(pdfBytes.length / 1024).round()} KB'
                          : 'General survey FMB (no sub-division) · ${(pdfBytes.length / 1024).round()} KB',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _showFmbSketchViewer(pdfBytes!, fileName: fileName),
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: const Text('View FMB Sketch', style: TextStyle(fontSize: 12)),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showFmbSketchViewer(pdfBytes!, fileName: fileName),
          icon: const Icon(Icons.fullscreen, size: 16),
          label: const Text('Open fullscreen viewer', style: TextStyle(fontSize: 11)),
        ),
      ]);
    }

    if (_fmbLoadError != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_fmbLoadError!, style: TextStyle(fontSize: 11, color: Colors.orange.shade900)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loadFmbForSelectedParcel,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry FMB', style: TextStyle(fontSize: 11)),
        ),
      ]);
    }

    for (final row in widget.tngisSubdivisions) {
      final err = _subdivBundles[row.key]?.fmbError;
      if (err != null) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(err, style: TextStyle(fontSize: 11, color: Colors.orange.shade900)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _fetchFmbForSubdivision(row),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry FMB', style: TextStyle(fontSize: 11)),
          ),
        ]);
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!widget.fmbAvailable && widget.fmbNote != null) ...[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Text(
            widget.fmbNote!,
            style: TextStyle(fontSize: 10, color: Colors.amber.shade900, height: 1.35),
          ),
        ),
      ],
      Text(
        widget.surveyNumber != null
            ? _resolvedMapSub() != null
                ? 'Survey ${widget.surveyNumber} · Sub ${_resolvedMapSub()} — tap Load FMB to fetch sketch.'
                : 'Survey ${widget.surveyNumber} — no sub-division; will load general survey FMB.'
            : widget.lat == null
                ? 'Tap the map to select a land parcel, then open FMB.'
                : 'Waiting for survey and sub-division. Tap directly on your plot.',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      ),
      if (widget.surveyNumber != null) ...[
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loadFmbForSelectedParcel,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: const Text('Load FMB', style: TextStyle(fontSize: 11)),
        ),
      ],
    ]);
  }

  Future<void> _fetchGiEcFromTngis() async {
    if (widget.lat == null || widget.lon == null) {
      setState(() => _ecError = 'Tap the map to set a plot location.');
      return;
    }
    setState(() {
      _fetchingEc = true;
      _ecError = null;
      _ecDocumentHtml = null;
      _ecPdfBytes = null;
      _ecAllRecords = [];
      _ecResults = [];
    });
    try {
      final parts = <String>[
        'lat=${widget.lat}',
        'lon=${widget.lon}',
      ];
      final survey = widget.surveyNumber?.trim();
      final sub = widget.subDivision?.trim();
      if (survey != null && survey.isNotEmpty) {
        parts.add('surveyNo=${Uri.encodeComponent(survey)}');
      }
      if (sub != null && sub.isNotEmpty && sub != '-') {
        parts.add('subDiv=${Uri.encodeComponent(sub)}');
      }
      final result = await ApiClient.get(
        '/api/tnlands/tngis/ec?${parts.join('&')}',
        timeout: const Duration(seconds: 90),
      );
      final doc = result['document'] as Map<String, dynamic>?;
      final pdfB64 = doc?['pdfBase64'] as String?;
      if (pdfB64 != null && pdfB64.isNotEmpty) {
        setState(() {
          _ecSource = result['source']?.toString() ?? 'TNGIS GI Viewer';
          _ecPdfBytes = Uint8List.fromList(base64.decode(pdfB64));
          _ecPdfFileName = doc?['pdfFileName']?.toString() ?? 'Encumbrance Certificate.pdf';
          _ecError = null;
        });
      } else {
        setState(() => _ecError = result['error']?.toString()
            ?? 'No Encumbrance Certificate found for this survey.');
      }
    } on ApiException catch (e) {
      setState(() => _ecError = e.message);
    } catch (e) {
      setState(() => _ecError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _fetchingEc = false);
    }
  }

  Widget _buildPattaDocPreview(Map<String, dynamic>? patta, {String? title, bool pdfOnly = false}) {
    if (patta == null) return pdfOnly ? _buildGiNoResult() : const SizedBox.shrink();
    final pdfB64 = patta['pdfBase64'] as String?;
    if (patta['available'] == true && pdfB64 != null && pdfB64.isNotEmpty) {
      try {
        return PattaDocumentPreview(
          pdfBytes: Uint8List.fromList(base64.decode(pdfB64)),
          fileName: patta['fileName']?.toString() ?? 'Patta.pdf',
        );
      } catch (_) {}
    }
    if (pdfOnly) {
      if (patta['error'] != null) {
        return Text(patta['error'].toString(),
            style: TextStyle(fontSize: 11, color: Colors.orange.shade900));
      }
      return _buildGiNoResult();
    }
    final html = patta['html'] as String?;
    if (patta['available'] == true && html != null && html.isNotEmpty) {
      return PattaHtmlPreview(
        key: ValueKey('patta-html-${html.hashCode}'),
        html: html,
        title: title ?? 'Patta / Chitta (TNGIS Tamil Nilam)',
      );
    }
    if (patta['error'] != null) {
      return Text(patta['error'].toString(),
          style: TextStyle(fontSize: 11, color: Colors.orange.shade900));
    }
    return Text(
      'Patta not available from TNGIS for this plot.',
      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
    );
  }

  Widget _buildGiEcDetail() {
    if (_fetchingEc) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      ));
    }
    if (_ecError != null) {
      return Text(_ecError!, style: TextStyle(fontSize: 11, color: Colors.orange.shade900));
    }
    if (_ecPdfBytes != null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Encumbrance Certificate',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(_ecSource ?? 'TNGIS GI Viewer',
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        PattaDocumentPreview(
          pdfBytes: _ecPdfBytes,
          fileName: _ecPdfFileName ?? 'Encumbrance Certificate.pdf',
        ),
      ]);
    }
    return Text(
      'Tap EC again after selecting a plot on the map.',
      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
    );
  }

  String? get _ecResolvedLabel {
    if (_selZone == null || _selEcDist == null) return null;
    final sro = _selEcSro?.name ?? '';
    return 'Resolved: ${_selZone!.name} · ${_selEcDist!.name}${sro.isNotEmpty ? ' · $sro' : ''}';
  }

  Widget _buildGiEcPeriodPicker() {
    return DropdownButtonFormField<_EcPeriod>(
      value: _selEcPeriod,
      decoration: _inputDec('EC period'),
      items: _ecPeriods.map((p) => DropdownMenuItem(value: p, child: Text(p.label, style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: (p) => setState(() => _selEcPeriod = p),
    );
  }

  Widget _buildGiInfoCard(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ]),
    );
  }

  Widget _buildGiGvalueDetail() {
    if (_loadingGvalue) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      ));
    }
    if (_gvalueError != null) {
      return Text(_gvalueError!, style: TextStyle(fontSize: 11, color: Colors.orange.shade900));
    }
    if (_gvalueData == null) return const SizedBox.shrink();

    final items = (_gvalueData!['items'] as List<dynamic>? ?? []);
    if (items.isEmpty) {
      return Text(
        _gvalueData!['error']?.toString() ?? 'Guideline Value not found for the selected Land',
        style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        _gvalueData!['title']?.toString() ?? 'Guide Line Value from Registration Department',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      for (final raw in items) ...[
        if (raw is Map) ...[
          if (raw['landType'] != null)
            _buildGiInfoCard('Land Type', raw['landType'].toString()),
          if (raw['classification'] != null)
            _buildGiInfoCard('Classification of Land Type', raw['classification'].toString()),
          if (raw['metricRate'] != null)
            _buildGiInfoCard('Metric Rate', raw['metricRate'].toString()),
          if (raw['pricePerHectare'] != null)
            _buildGiInfoCard('Price per Hectare', raw['pricePerHectare'].toString()),
        ],
      ],
    ]);
  }

  Widget _buildGiCropSeasonBlock(String title, Map<String, dynamic>? season) {
    if (season == null) return const SizedBox.shrink();
    if (season['ok'] != true) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            season['error']?.toString() ?? 'No crop data available for this season.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ]),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (season['cropName'] != null)
          _buildGiInfoCard('Crop Name', season['cropName'].toString()),
        if (season['classification'] != null)
          _buildGiInfoCard('Classification', season['classification'].toString()),
        if (season['cropArea'] != null)
          _buildGiInfoCard('Crop Area', season['cropArea'].toString()),
        if (season['landArea'] != null)
          _buildGiInfoCard('Land Area', season['landArea'].toString()),
        if (season['cropCount'] != null)
          _buildGiInfoCard('Crop Count', season['cropCount'].toString()),
        if (season['govtPriority'] != null)
          _buildGiInfoCard('Govt Priority', season['govtPriority'].toString()),
      ]),
    );
  }

  Widget _buildGiCropSeasonTab(String id, String label, Map<String, dynamic>? season) {
    final selected = _selectedCropSeason == id;
    return Expanded(
      child: Material(
        color: selected ? const Color(0xFF2E7D32).withValues(alpha: 0.14) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () => setState(() => _selectedCropSeason = id),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? const Color(0xFF2E7D32) : const Color(0xFF2E7D32).withValues(alpha: 0.4),
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? const Color(0xFF2E7D32) : const Color(0xFF2E7D32).withValues(alpha: 0.85),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGiCropDetail() {
    if (_loadingCrop) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      ));
    }
    if (_cropError != null) {
      return Text(_cropError!, style: TextStyle(fontSize: 11, color: Colors.orange.shade900));
    }
    if (_cropData == null) return const SizedBox.shrink();

    final seasons = (_cropData!['seasons'] as Map?)?.cast<String, dynamic>() ?? {};
    final rabi = (seasons['rabi'] as Map?)?.cast<String, dynamic>();
    final kharif = (seasons['kharif'] as Map?)?.cast<String, dynamic>();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        _cropData!['title']?.toString() ?? 'Crop Information',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          _buildGiCropSeasonTab('rabi', 'RABI', rabi),
          const SizedBox(width: 8),
          _buildGiCropSeasonTab('kharif', 'KHARIF', kharif),
        ],
      ),
      if (_selectedCropSeason != null) ...[
        const SizedBox(height: 12),
        _buildGiCropSeasonBlock(
          _selectedCropSeason == 'rabi' ? 'RABI' : 'KHARIF',
          _selectedCropSeason == 'rabi' ? rabi : kharif,
        ),
      ],
    ]);
  }

  Widget _buildGiSubdivisionPreview(_TngisSubdivisionRow row) {
    const color = Color(0xFF1B5E20);
    final bundle = _subdivBundles[row.key] ??= _SubdivDocBundle();
    final patta = bundle.documents?['patta'] as Map<String, dynamic>?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: row.containsPoint
              ? const Color(0xFF1565C0).withValues(alpha: 0.5)
              : color.withValues(alpha: 0.25),
          width: row.containsPoint ? 2 : 1,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (row.containsPoint)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Selected plot',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1565C0))),
          ),
        _kv('Survey Number', row.surveyNumber),
        _kv('Sub Division', row.subLabel),
        if (row.fields['Patta Number']?.isNotEmpty == true)
          _kv('Patta Number', row.fields['Patta Number']!),
        const SizedBox(height: 8),
        if (bundle.loadingPatta)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else if (_pattaError != null && row.containsPoint)
          Text(_pattaError!, style: TextStyle(fontSize: 11, color: Colors.orange.shade900))
        else if (_hasPattaPdf(patta))
          _buildPattaDocPreview(patta, title: 'Patta / Chitta', pdfOnly: true)
        else
          _buildGiNoResult(),
      ]),
    );
  }

  Widget _buildSubdivisionCard(_TngisSubdivisionRow row, Color color) {
    final bundle = _subdivBundles[row.key] ??= _SubdivDocBundle();
    final patta = bundle.documents?['patta'] as Map<String, dynamic>?;
    final fmb = bundle.documents?['fmb'] as Map<String, dynamic>?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: row.containsPoint
              ? const Color(0xFF1565C0).withValues(alpha: 0.45)
              : color.withValues(alpha: 0.25),
          width: row.containsPoint ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (row.containsPoint)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('Selected plot',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1565C0))),
          ),
        _kv('Survey Number', row.surveyNumber),
        _kv('Sub Division', row.subLabel),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: bundle.loadingPatta
                    ? null
                    : () => _fetchPattaForSubdivision(row),
                icon: bundle.loadingPatta
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.article_outlined, size: 16),
                label: Text(bundle.loadingPatta ? 'Loading…' : 'Load Patta'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: bundle.loadingFmb
                    ? null
                    : () => _fetchFmbForSubdivision(row),
                icon: bundle.loadingFmb
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_outlined, size: 16),
                label: Text(bundle.loadingFmb ? 'Loading…' : 'Load FMB'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Patta / Chitta',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20))),
            const SizedBox(height: 6),
            if (bundle.loadingPatta)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ))
            else if (patta != null && patta['available'] == true && (patta['html'] as String?)?.isNotEmpty == true)
              PattaHtmlPreview(
                key: ValueKey('patta-${row.key}-${(patta['html'] as String).hashCode}'),
                html: patta['html'] as String,
                title: 'Survey ${row.surveyNumber} · Sub ${row.subLabel}',
              )
            else if (patta?['error'] != null)
              Text(patta!['error'].toString(),
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade900))
            else
              Text(
                'Tap Load Patta for this subdivision.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFC62828).withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.25)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('FMB Sketch',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFC62828))),
            const SizedBox(height: 6),
            if (bundle.loadingFmb)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ))
            else if (bundle.fmbPdf != null)
              FilledButton.icon(
                onPressed: () => _showFmbSketchViewer(
                  bundle.fmbPdf!,
                  fileName: 'FMB Survey ${row.surveyNumber} Sub ${row.subLabel}.pdf',
                ),
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('View FMB Sketch', style: TextStyle(fontSize: 11)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A237E),
                  minimumSize: const Size(double.infinity, 40),
                ),
              )
            else if (bundle.fmbError != null)
              Text(bundle.fmbError!,
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade900))
            else if (fmb?['error'] != null)
              Text(fmb!['error'].toString(),
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade900))
            else
              Text(
                row.fmbAvailable
                    ? 'Loading FMB from TNGIS…'
                    : 'FMB may not be digitized for this subdivision.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildPattaResult() {
    const color = Color(0xFF1B5E20);
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.check_circle_outline, color: color, size: 16),
          SizedBox(width: 6),
          Text('Patta Details',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        ]),
        if (_pattaSource != null) ...[
          const SizedBox(height: 4),
          Text('Source: $_pattaSource',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 10),
        if (_pattaFields != null)
          ...(_pattaFields!.entries.map((e) => _kv(e.key, e.value))),
        if (_pattaOwners.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Owners',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          ..._pattaOwners.map((owner) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(children: owner.entries.map((e) => _kv(e.key, e.value)).toList()),
                ),
              )),
        ],
        if (_pattaDocuments != null) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          const Text('Official Documents',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 8),
          ..._buildPattaDocumentActions(color),
        ],
      ]),
    );
  }

  List<Widget> _buildPattaDocumentActions(Color color) {
    final docs = _pattaDocuments!;
    final patta = docs['patta'] as Map<String, dynamic>?;
    final fmb = docs['fmb'] as Map<String, dynamic>?;
    final widgets = <Widget>[];

    if (patta != null) {
      final available = patta['available'] == true;
      final html = patta['html'] as String?;
      final pattaChildren = <Widget>[
        const Text('Patta / Chitta',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1B5E20))),
        const SizedBox(height: 6),
      ];
      if (available && (html != null && html.isNotEmpty || (patta['pdfBase64'] as String?)?.isNotEmpty == true)) {
        pattaChildren.add(_buildPattaDocPreview(patta));
        if (patta['note'] != null) {
          pattaChildren.add(const SizedBox(height: 4));
          pattaChildren.add(Text(patta['note'].toString(),
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)));
        }
      } else if (patta['error'] != null) {
        pattaChildren.add(Text(patta['error'].toString(),
            style: TextStyle(fontSize: 11, color: Colors.orange.shade900)));
      }
      widgets.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: pattaChildren,
        ),
      ));
      widgets.add(const SizedBox(height: 12));
    }

    if (fmb != null) {
      final hasProbe = fmb['downloadUrl'] != null;
      final confirmedAvailable = fmb['available'] == true;
      final fmbChildren = <Widget>[
        const Text('FMB Sketch',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFC62828))),
        const SizedBox(height: 6),
      ];
      if (_loadingFmb) {
        fmbChildren.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC62828)),
            ),
          ),
        ));
      } else if (_fmbPdfBytes != null) {
        fmbChildren.add(PattaDocumentPreview(
          pdfBytes: _fmbPdfBytes,
          fileName: (fmb['fileName'] as String?) ?? 'FMB Sketch.pdf',
        ));
      } else if (_fmbLoadError != null) {
        fmbChildren.add(Text(_fmbLoadError!,
            style: TextStyle(fontSize: 11, color: Colors.orange.shade900)));
      } else if (hasProbe) {
        fmbChildren.add(OutlinedButton.icon(
          onPressed: _loadingFmb ? null : _loadFmbPdfIfNeeded,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
          label: const Text('Load FMB sketch PDF'),
        ));
      } else if (!confirmedAvailable) {
        fmbChildren.add(Text(
          fmb['error']?.toString() ?? 'FMB not digitized for this subdivision.',
          style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
        ));
      }
      widgets.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFC62828).withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: fmbChildren,
        ),
      ));
    }

    return widgets;
  }

  // â”€â”€ EC UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _ecPeriodDropdown(Color color) {
    if (_loadingEcPeriods) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC62828))),
          SizedBox(width: 10),
          Text('Loading periods…', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<_EcPeriod>(
          value: _selEcPeriod,
          isExpanded: true,
          hint: const Text('Select year / period',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          items: _ecPeriods
              .map((p) => DropdownMenuItem(
                    value: p,
                    child: Text(p.label, style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
          onChanged: _ecPeriods.isEmpty
              ? null
              : (p) {
                  if (p == null) return;
                  setState(() => _selEcPeriod = p);
                  if (_selZone != null && _ecSurveyCtrl.text.trim().isNotEmpty) {
                    _searchEcWithPeriod(p);
                  }
                },
          icon: Icon(Icons.keyboard_arrow_down, size: 18, color: color),
        ),
      ),
    );
  }

  Widget _buildEcResults() {
    const color = Color(0xFFC62828);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.check_circle_outline, color: color, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${_ecAllRecords.length} EC record${_ecAllRecords.length == 1 ? '' : 's'} · ${_selEcPeriod?.label ?? 'selected period'}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ]),
      if (_ecSource != null) ...[
        const SizedBox(height: 4),
        Text('Source: $_ecSource',
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
      if (_ecEntries.length > 1) ...[
        const SizedBox(height: 10),
        const Text('View by registration date',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selEcEntryId ?? 'all',
              isExpanded: true,
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('All records in period', style: TextStyle(fontSize: 12)),
                ),
                ..._ecEntries.map((e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(e.label, style: const TextStyle(fontSize: 12)),
                    )),
              ],
              onChanged: (id) {
                if (id == null) return;
                setState(() => _selEcEntryId = id);
                _refreshEcEntryPreview();
              },
            ),
          ),
        ),
      ],
      if (_ecPdfBytes != null) ...[
        const SizedBox(height: 10),
        PattaDocumentPreview(
          key: ValueKey('ec-pdf-${_ecPdfBytes!.length}'),
          pdfBytes: _ecPdfBytes,
          fileName: _ecPdfFileName ?? 'Encumbrance Certificate.pdf',
        ),
      ],
      if (_ecDocumentHtml != null && _ecPdfBytes == null) ...[
        const SizedBox(height: 10),
        PattaHtmlPreview(
          key: ValueKey('ec-html-${_ecDocumentHtml!.hashCode}'),
          html: _ecDocumentHtml!,
          title: 'Encumbrance Certificate (EC)',
        ),
      ],
    ]);
  }

  // â”€â”€ Shared UI helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _dropdown(
    String label,
    List<_Option> options,
    _Option? selected,
    Color color, {
    bool loading = false,
    String? hint,
    required Function(_Option) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected != null ? color.withValues(alpha: 0.5) : const Color(0xFFE5E7EB)),
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                SizedBox(width: 10),
                Text('Loading...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ]),
            )
          : DropdownButtonHideUnderline(
              child: DropdownButton<_Option>(
                value: selected,
                isExpanded: true,
                hint: Text(hint ?? label,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                items: options
                    .map((o) => DropdownMenuItem(
                          value: o,
                          child: Text(o.name,
                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                        ))
                    .toList(),
                onChanged: options.isEmpty
                    ? null
                    : (v) { if (v != null) onChanged(v); },
                icon: Icon(Icons.keyboard_arrow_down,
                    size: 18,
                    color: selected != null ? color : AppColors.textSecondary),
              ),
            ),
    );
  }

  Widget _kv(String key, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 120,
            child: Text(key,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  // â”€â”€ Static district fallback â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  static const _kStaticDistricts = [
    _Option('001', 'Ariyalur'),       _Option('002', 'Chengalpattu'),
    _Option('003', 'Chennai'),        _Option('004', 'Coimbatore'),
    _Option('005', 'Cuddalore'),      _Option('006', 'Dharmapuri'),
    _Option('007', 'Dindigul'),       _Option('008', 'Erode'),
    _Option('009', 'Kallakurichi'),   _Option('010', 'Kancheepuram'),
    _Option('011', 'Kanniyakumari'), _Option('012', 'Karur'),
    _Option('013', 'Krishnagiri'),    _Option('014', 'Madurai'),
    _Option('015', 'Mayiladuthurai'),_Option('016', 'Nagapattinam'),
    _Option('017', 'Namakkal'),       _Option('018', 'Nilgiris'),
    _Option('019', 'Perambalur'),     _Option('020', 'Pudukkottai'),
    _Option('021', 'Ramanathapuram'),_Option('022', 'Ranipet'),
    _Option('023', 'Salem'),          _Option('024', 'Sivagangai'),
    _Option('025', 'Tenkasi'),        _Option('026', 'Thanjavur'),
    _Option('027', 'Theni'),          _Option('028', 'Thoothukudi'),
    _Option('029', 'Tiruchirappalli'),_Option('030', 'Tirunelveli'),
    _Option('031', 'Tirupathur'),     _Option('032', 'Tiruppur'),
    _Option('033', 'Tiruvallur'),     _Option('034', 'Tiruvannamalai'),
    _Option('035', 'Tiruvarur'),      _Option('036', 'Vellore'),
    _Option('037', 'Viluppuram'),     _Option('038', 'Virudhunagar'),
  ];
}

