import 'dart:async';
import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import '../../services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
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

  // Valuation inputs
  final _roadWidthCtrl = TextEditingController();
  final _landSizeCtrl = TextEditingController();
  String _locationCategory = 'Urban';
  String _developmentPotential = 'Medium';
  _ValuationResult? _valuationResult;

  // Competitor Projects (MagicBricks or TNRERA fallback)
  List<Map<String, dynamic>> _mbListings = [];
  bool _fetchingMb = false;
  String? _mbError;
  String _mbSource = 'MagicBricks';
  String _compFilter = 'All';   // All | Ongoing | Completed | Plot | Old
  int _oldYearsFilter = 5;       // 2 | 5 | 10

  // EC & Patta â€“ location data passed to the section widget
  String? _detectedDistrict;
  String? _detectedTaluk;
  String? _detectedVillage;

  // Default center shown before GPS resolves
  static const _kDefaultCenter = LatLng(13.0827, 80.2707);

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_onStoreUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) => _detectLocation());
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
      _valuationResult = null;
    });
    if (_mapReady) {
      _mapController.move(_searchedLocation!, _zoomForRadius(_selectedRadius));
    }
    _fetchLocationDetails(loc);
  }

  // â”€â”€ Map tap â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _handleMapTap(LatLng point) {
    setState(() {
      _searchedLocation = point;
      _tappedPoint = null;
      _poisCollected = false;
      _poiCounts = {};
      _poiPlaces = {};
      _valuationResult = null;
    });
    if (_mapReady) _mapController.move(point, _mapController.camera.zoom);
    _fetchLocationDetails(point);
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
      _poisCollected = false;
    });

    final lat = loc.latitude;
    final lon = loc.longitude;
    final radius = _selectedRadius * 1000;

    try {
      final parts = <String>[];
      for (final cat in _kCategories) {
        final area   = '(around:$radius,$lat,$lon)';
        final isWay  = cat.tag == 'landuse';
        final filter = '["${cat.tag}"="${cat.value}"]';
        if (!isWay) {
          parts.add('node$filter$area;');
          parts.add('relation$filter$area;');
        }
        parts.add('way$filter$area;');
      }
      // Separate query for metro: railway=station + station=subway
      parts.add('node["railway"="station"]["station"="subway"](around:$radius,$lat,$lon);');
      parts.add('way["railway"="station"]["station"="subway"](around:$radius,$lat,$lon);');

      final query = '[out:json][timeout:50];\n(\n${parts.join('\n')}\n);\nout tags center;';

      // Route through backend proxy â€” avoids CORS issues on Vercel.
      final data = await ApiClient.post(
        '/api/poi',
        {'query': query},
        auth: false,
      ).timeout(const Duration(seconds: 58));

      final elements = (data['elements'] as List?) ?? [];

      if (data['remark'] != null && elements.isEmpty) {
        throw Exception(data['remark'].toString());
      }

      final counts = <String, int>{};
      final places = <String, List<Map<String, dynamic>>>{};
      for (final cat in _kCategories) {
        counts[cat.name] = 0;
        places[cat.name] = [];
      }

      for (final el in elements) {
        final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? {};

        // Determine which category this element belongs to
        for (final cat in _kCategories) {
          if (tags[cat.tag] != cat.value) continue;
          if (cat.name == 'Metro Stations' && tags['station'] != 'subway') continue;
          if (cat.name == 'Railway Stations' && tags['station'] == 'subway') continue;

          counts[cat.name] = (counts[cat.name] ?? 0) + 1;
          final name = (tags['name'] as String? ?? '').trim();

          double? eLat, eLon;
          if (el['lat'] != null) {
            eLat = (el['lat'] as num).toDouble();
            eLon  = (el['lon'] as num).toDouble();
          } else if (el['center'] != null) {
            final c = (el['center'] as Map).cast<String, dynamic>();
            eLat = (c['lat'] as num).toDouble();
            eLon  = (c['lon'] as num).toDouble();
          }

          places[cat.name]!.add({
            'name': name.isEmpty ? 'Unnamed' : name,
            if (eLat != null) 'distance':
                Geolocator.distanceBetween(lat, lon, eLat, eLon!) / 1000,
          });
        }
      }

      setState(() {
        _poiCounts = counts;
        _poiPlaces = places;
        _poisCollected = true;
      });
    } catch (e) {
      setState(() => _poiError = 'POI fetch failed: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      setState(() => _collectingPois = false);
    }
  }

  // â”€â”€ Infrastructure Score â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Map<String, double> get _infraScores {
    if (!_poisCollected) return {};
    final r = _selectedRadius;
    final maxEdu = r == 2 ? 15 : r == 5 ? 30 : 60;
    final maxHealth = r == 2 ? 5 : r == 5 ? 15 : 30;
    final maxCommercial = r == 2 ? 10 : r == 5 ? 25 : 50;
    final maxTransport = r == 2 ? 8 : r == 5 ? 20 : 40;

    final edu = ((_poiCounts['Schools'] ?? 0) / maxEdu * 100).clamp(0, 100).toDouble();
    final health = ((_poiCounts['Hospitals'] ?? 0) / maxHealth * 100).clamp(0, 100).toDouble();
    final transport = (((_poiCounts['Railway Stations'] ?? 0) +
                (_poiCounts['Metro Stations'] ?? 0) +
                (_poiCounts['Bus Terminals'] ?? 0)) /
            maxTransport * 100)
        .clamp(0, 100)
        .toDouble();
    final commercial = (((_poiCounts['Malls'] ?? 0) +
                (_poiCounts['Banks'] ?? 0) +
                (_poiCounts['IT Parks'] ?? 0)) /
            maxCommercial * 100)
        .clamp(0, 100)
        .toDouble();
    final road = (((_poiCounts['Petrol Stations'] ?? 0) +
                (_poiCounts['Govt. Offices'] ?? 0)) /
            (r == 2 ? 6 : r == 5 ? 15 : 30) * 100)
        .clamp(0, 100)
        .toDouble();
    final overall =
        (edu * 0.25 + health * 0.25 + transport * 0.20 + commercial * 0.20 + road * 0.10)
            .clamp(0, 100)
            .toDouble();

    return {
      'Education': edu,
      'Healthcare': health,
      'Road Connectivity': road,
      'Commercial': commercial,
      'Transport': transport,
      'Overall Location': overall,
    };
  }

  // â”€â”€ AI Valuation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  _ValuationResult _computeValuation() {
    final infraScore = _infraScores['Overall Location'] ?? 50;
    const benchmarkPrice = 5000.0;
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

    setState(() {
      _fetchingMb = true;
      _mbError = null;
      _mbListings = [];
    });

    try {
      final result = await ApiClient.get(
          '/api/magicbricks?city=${Uri.encodeComponent(city)}');
      final listings = (result['listings'] as List<dynamic>?) ?? [];
      setState(() {
        _mbListings = listings.cast<Map<String, dynamic>>();
        _mbSource = (result['source'] as String?) ?? 'Projects';
        _fetchingMb = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _mbError = e.message;
        _fetchingMb = false;
      });
    } catch (_) {
      setState(() {
        _mbError = 'Could not reach the server. Check your connection and try again.';
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

    String fmtPrice(Map<String, dynamic> item) {
      final ppsf = (item['pricePerSqft'] as num?)?.toDouble() ?? 0;
      final total = (item['priceRupees'] as num?)?.toDouble() ?? 0;
      if (ppsf > 0) return 'â‚¹${ppsf.toInt()}/sqft';
      if (total >= 1e7) return 'â‚¹${(total / 1e7).toStringAsFixed(2)} Cr';
      if (total > 0) return 'â‚¹${(total / 1e5).toStringAsFixed(2)} L';
      return '';
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
              Text('Source: $_mbSource',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text('Area: ${city.isEmpty ? 'Chennai' : city}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
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
            label: Text(_fetchingMb ? 'Fetching...' : 'Fetch Projects',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: mbColor,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ]),

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
            final price     = fmtPrice(item);
            final isTnrera  = _mbSource == 'TNRERA';
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
                  if (price.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: mbColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(price,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700, color: mbColor)),
                    ),
                  ],
                ]),
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
                    rera.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
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
                'Tap "Fetch Projects" to load\ncompetitor projects for this area.',
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
      surveyNumber: surveyNo,
      subDivision: subDiv,
      lat: loc?.latitude,
      lon: loc?.longitude,
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
    if (widget.isTab) return Scaffold(body: body);
    return Scaffold(
      appBar: const FomraAppBar(moduleName: 'Market Intelligence'),
      drawer: const AppDrawer(currentRoute: '/market-intelligence'),
      bottomNavigationBar:
          const FomraBottomNav(currentRoute: '/market-intelligence'),
      body: body,
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fetchingLocation
                  ? null
                  : () {
                      setState(() {
                        _selectedLeadId = null; // Clear lead selection
                      });
                      _detectLocation();
                    },
              icon: _fetchingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.gps_fixed, size: 18),
              label: Text(_position == null
                  ? 'Detect My Location'
                  : 'Refresh Location'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
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

  // â”€â”€ Section: Map Visualization â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildMapSection() {
    final activeLoc = _activeLatLng;
    return _SectionCard(
      title: 'Location Visualization',
      icon: Icons.map_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 260,
              child: activeLoc != null || _fetchingLocation
                  ? FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: activeLoc ?? _kDefaultCenter,
                        initialZoom: _zoomForRadius(_selectedRadius),
                        onMapReady: () => setState(() => _mapReady = true),
                        onTap: (_, point) => _handleMapTap(point),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                        ),
                        // Circle Layer
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
                    )
                  : Container(
                      color: const Color(0xFFE8EEF8),
                      child: Center(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _fetchingLocation || _searchingLocation
                                  ? const CircularProgressIndicator(
                                      color: AppColors.primary,
                                      strokeWidth: 2.5)
                                  : const Icon(Icons.map_outlined,
                                      size: 52, color: AppColors.primary),
                              const SizedBox(height: 10),
                              Text(
                                _fetchingLocation
                                    ? 'Getting your location...'
                                    : 'Search above or tap the map to set location',
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                              ),
                            ]),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),

          if (activeLoc != null) ...[
            Text(
              'ðŸ“ ${activeLoc.latitude.toStringAsFixed(5)}Â° N, ${activeLoc.longitude.toStringAsFixed(5)}Â° E',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
          ],
          if (_locationError != null) ...[
            _ErrorBanner(_locationError!),
            const SizedBox(height: 10),
          ],

        // â”€â”€ Radius selector â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
        const SizedBox(height: 12),

        // â”€â”€ Detect location button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _fetchingLocation ? null : _detectLocation,
              icon: _fetchingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.gps_fixed, size: 18),
              label: Text(_position == null
                  ? 'Detect My Location'
                  : 'Refresh Location'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
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
        title: 'POI Discovery',
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
                  onTap: () => setState(() {
                    _selectedRadius = km;
                    _poisCollected = false;
                    _poiCounts = {};
                    _poiPlaces = {};
                    if (_activeLatLng != null && _mapReady) {
                      _mapController.move(
                          _activeLatLng!, _zoomForRadius(km));
                    }
                  }),
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
                  ? 'Collecting...'
                  : 'Collect Nearby Places'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00838F),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (_activeLatLng == null && !_collectingPois) ...[
            const SizedBox(height: 10),
            const Text(
              'Set your location first to collect nearby places.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
          const _AutoChip('Market Reference',
              '₹5000/sqft  (default — fetch competitor data to refine)'),
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

// â”€â”€ EC & Patta: main section widget â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GovtDocsSection extends StatefulWidget {
  final String? district;
  final String? taluk;
  final String? village;
  final String? surveyNumber;
  final String? subDivision;
  final double? lat; // active map location — enables the TNGIS patta fallback
  final double? lon;
  const _GovtDocsSection({
    this.district,
    this.taluk,
    this.village,
    this.surveyNumber,
    this.subDivision,
    this.lat,
    this.lon,
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

  // â”€â”€ EC state â”€â”€
  final List<_Option> _ecZones = const [
    _Option('1', 'North'), _Option('2', 'South'), _Option('3', 'Central'),
  ];
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
  String? _ecError;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _ecFromCtrl.text = '01/01/2000';
    _ecToCtrl.text =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    _applySurveyNumber();
    _initDistricts();
    if (widget.district != null) _tryAutoEcFill();
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
  /// available (lead-based mode). No-op otherwise.
  void _maybeAutoFetchEc() {
    final s = widget.surveyNumber?.trim() ?? '';
    if (s.isEmpty || _fetchingEc) return;
    if (_selZone == null || _selEcDist == null || _selEcSro == null) return;
    _ecSurveyCtrl.text = s;
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

    if (surveyChanged) _applySurveyNumber();

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
  }

  @override
  void dispose() {
    _surveyCtrl.dispose(); _subDivCtrl.dispose();
    _ecSurveyCtrl.dispose(); _ecSubDivCtrl.dispose();
    _ecFromCtrl.dispose(); _ecToCtrl.dispose();
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

  Future<void> _fetchPatta() async {
    if (_selDistrict == null || _selTaluk == null ||
        _selVillage == null || _surveyCtrl.text.trim().isEmpty) { return; }
    setState(() {
      _fetchingPatta = true; _pattaFields = null;
      _pattaOwners = []; _pattaError = null;
    });
    try {
      var params = 'dc=${_selDistrict!.code}'
          '&tc=${_selTaluk!.code}'
          '&vc=${_selVillage!.code}'
          '&surveyNo=${Uri.encodeComponent(_surveyCtrl.text.trim())}'
          '&subDiv=${Uri.encodeComponent(_subDivCtrl.text.trim())}';
      // Pass the active map location so the backend can fall back to the TNGIS
      // cadastral layer (queried by survey number near this point) when the
      // eservices portal is unavailable.
      if (widget.lat != null && widget.lon != null) {
        params += '&lat=${widget.lat}&lon=${widget.lon}';
      }
      final result = await ApiClient.get('/api/tnlands/patta?$params');
      final fields = (result['fields'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString()));
      final owners = (result['owners'] as List<dynamic>? ?? []).map((o) {
        return (o as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()));
      }).toList();
      setState(() { _pattaFields = fields; _pattaOwners = owners; });
    } on ApiException catch (e) {
      setState(() => _pattaError = e.message);
    } catch (e) {
      setState(() => _pattaError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _fetchingPatta = false);
    }
  }

  // â”€â”€ EC methods â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _tryAutoEcFill() async {
    if (widget.district == null) return;
    setState(() => _autoFillingEc = true);
    try {
      for (final zone in _ecZones) {
        try {
          final data = await ApiClient.getList(
              '/api/tnlands/ec/districts?zone=${zone.code}');
          final dists = _toOptions(data);
          final matchDist = _matchOption(dists, widget.district);
          if (matchDist != null) {
            setState(() {
              _selZone = zone; _ecDists = dists; _selEcDist = matchDist;
            });
            await _loadEcSros(matchDist, autoFirst: true);
            break;
          }
        } catch (_) {
          // try next zone
        }
      }
    } finally {
      setState(() => _autoFillingEc = false);
    }
  }

  Future<void> _loadEcDistricts(_Option zone) async {
    setState(() {
      _selZone = zone; _ecDists = []; _selEcDist = null;
      _ecSros = []; _selEcSro = null; _loadingEcDists = true;
    });
    try {
      final data = await ApiClient.getList(
          '/api/tnlands/ec/districts?zone=${zone.code}');
      setState(() { _ecDists = _toOptions(data); _loadingEcDists = false; });
    } catch (_) {
      setState(() => _loadingEcDists = false);
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
        _ecSros = loaded;
        if (autoFirst && loaded.isNotEmpty) _selEcSro = loaded.first;
        _loadingEcSros = false;
      });
      if (autoFirst) _maybeAutoFetchEc();
    } catch (_) {
      setState(() => _loadingEcSros = false);
    }
  }

  Future<void> _searchEc() async {
    if (_selZone == null || _selEcDist == null || _selEcSro == null ||
        _ecSurveyCtrl.text.trim().isEmpty ||
        _ecFromCtrl.text.trim().isEmpty || _ecToCtrl.text.trim().isEmpty) {
      setState(() => _ecError = 'Fill all fields before searching.');
      return;
    }
    setState(() { _fetchingEc = true; _ecResults = []; _ecError = null; });
    try {
      final params = 'zone=${_selZone!.code}'
          '&dc=${_selEcDist!.code}'
          '&sro=${_selEcSro!.code}'
          '&surveyNo=${Uri.encodeComponent(_ecSurveyCtrl.text.trim())}'
          '&subDiv=${Uri.encodeComponent(_ecSubDivCtrl.text.trim())}'
          '&fromDate=${Uri.encodeComponent(_ecFromCtrl.text.trim())}'
          '&toDate=${Uri.encodeComponent(_ecToCtrl.text.trim())}';
      final result = await ApiClient.get('/api/tnlands/ec/search?$params');
      final records = (result['records'] as List<dynamic>? ?? []).map((r) {
        return (r as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString()));
      }).toList();
      if (records.isEmpty) {
        setState(() => _ecError = 'No EC records found. Try a wider date range.');
      } else {
        setState(() => _ecResults = records);
      }
    } on ApiException catch (e) {
      setState(() => _ecError = e.message);
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
      title: 'EC & Patta Documents',
      icon: Icons.description_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPattaSection(),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 14),
        _buildEcSection(),
      ]),
    );
  }

  // â”€â”€ Patta UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildPattaSection() {
    const color = Color(0xFF1B5E20);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.article_outlined, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Patta / Chitta / FMB',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            Text('eservices.tn.gov.in', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ),
        if (_initingPatta)
          const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color)),
      ]),
      const SizedBox(height: 14),

      // District
      const _FieldLabel('District'),
      _dropdown('Select District', _districts, _selDistrict, color,
          loading: _initingPatta,
          onChanged: (opt) => _loadTaluks(opt)),
      const SizedBox(height: 10),

      // Taluk
      const _FieldLabel('Taluk'),
      _dropdown('Select Taluk', _taluks, _selTaluk, color,
          loading: _loadingTaluks,
          hint: _selDistrict == null ? 'Select district first' : 'Select Taluk',
          onChanged: (opt) => _loadVillages(opt)),
      if (_talukError != null) ...[
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _selDistrict == null ? null : () => _loadTaluks(_selDistrict!),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.refresh, size: 14, color: AppColors.error),
              SizedBox(width: 6),
              Text('Failed to load taluks — tap to retry',
                  style: TextStyle(fontSize: 11, color: AppColors.error)),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 10),

      // Village
      const _FieldLabel('Village'),
      _dropdown('Select Village', _villages, _selVillage, color,
          loading: _loadingVillages,
          hint: _selTaluk == null ? 'Select taluk first' : 'Select Village',
          onChanged: (opt) => setState(() => _selVillage = opt)),
      if (_villageError != null) ...[
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _selTaluk == null ? null : () => _loadVillages(_selTaluk!),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.refresh, size: 14, color: AppColors.error),
              SizedBox(width: 6),
              Text('Failed to load villages — tap to retry',
                  style: TextStyle(fontSize: 11, color: AppColors.error)),
            ]),
          ),
        ),
      ],
      const SizedBox(height: 10),

      // Survey No + Sub Div
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FieldLabel('Survey No *'),
          TextField(controller: _surveyCtrl, decoration: _inputDec('e.g. 123/2A')),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FieldLabel('Sub Division'),
          TextField(controller: _subDivCtrl, decoration: _inputDec('Optional')),
        ])),
      ]),
      const SizedBox(height: 14),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: (_fetchingPatta ||
                  _selDistrict == null ||
                  _selTaluk == null ||
                  _selVillage == null)
              ? null
              : _fetchPatta,
          icon: _fetchingPatta
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.download_outlined, size: 16),
          label: Text(_fetchingPatta ? 'Fetching...' : 'Fetch Patta',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),

      if (_pattaError != null) ...[
        const SizedBox(height: 10),
        _ErrorBanner(_pattaError!),
      ],
      if (_pattaFields != null || _pattaOwners.isNotEmpty) ...[
        const SizedBox(height: 14),
        _buildPattaResult(),
      ],
    ]);
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
      ]),
    );
  }

  // â”€â”€ EC UI â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildEcSection() {
    const color = Color(0xFFC62828);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(Icons.account_balance_outlined, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Encumbrance Certificate (EC)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            Text('tnreginet.gov.in', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ),
        if (_autoFillingEc)
          const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color)),
        if (_autoFillingEc) ...[
          const SizedBox(width: 6),
          const Text('Auto-fillingâ€¦',
              style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ]),
      const SizedBox(height: 14),

      // Zone
      const _FieldLabel('Zone'),
      _dropdown('Select Zone', _ecZones, _selZone, color,
          loading: _autoFillingEc,
          onChanged: (opt) => _loadEcDistricts(opt)),
      const SizedBox(height: 10),

      // District
      const _FieldLabel('District'),
      _dropdown('Select District', _ecDists, _selEcDist, color,
          loading: _loadingEcDists,
          hint: _selZone == null ? 'Select zone first' : 'Select District',
          onChanged: (opt) => _loadEcSros(opt)),
      const SizedBox(height: 10),

      // SRO
      const _FieldLabel('Sub Registrar Office (SRO)'),
      _dropdown('Select SRO', _ecSros, _selEcSro, color,
          loading: _loadingEcSros,
          hint: _selEcDist == null ? 'Select district first' : 'Select SRO',
          onChanged: (opt) => setState(() => _selEcSro = opt)),
      const SizedBox(height: 10),

      // Survey + SubDiv
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FieldLabel('Survey No *'),
          TextField(controller: _ecSurveyCtrl, decoration: _inputDec('e.g. 123')),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FieldLabel('Sub Division'),
          TextField(controller: _ecSubDivCtrl, decoration: _inputDec('Optional')),
        ])),
      ]),
      const SizedBox(height: 10),

      // Date range
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FieldLabel('From Date *'),
          TextField(controller: _ecFromCtrl, decoration: _inputDec('DD/MM/YYYY')),
        ])),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FieldLabel('To Date *'),
          TextField(controller: _ecToCtrl, decoration: _inputDec('DD/MM/YYYY')),
        ])),
      ]),
      const SizedBox(height: 14),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _fetchingEc ? null : _searchEc,
          icon: _fetchingEc
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.search, size: 16),
          label: Text(_fetchingEc ? 'Searching...' : 'Search EC',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),

      if (_ecError != null) ...[
        const SizedBox(height: 10),
        _ErrorBanner(_ecError!),
      ],
      if (_ecResults.isNotEmpty) ...[
        const SizedBox(height: 14),
        _buildEcResults(),
      ],
    ]);
  }

  Widget _buildEcResults() {
    const color = Color(0xFFC62828);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.check_circle_outline, color: color, size: 16),
        const SizedBox(width: 6),
        Text('${_ecResults.length} EC Record${_ecResults.length == 1 ? '' : 's'} Found',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
      const SizedBox(height: 10),
      ..._ecResults.asMap().entries.map((entry) {
        final rec = entry.value;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Record ${entry.key + 1}',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.7))),
            const SizedBox(height: 6),
            ...rec.entries.map((e) => _kv(e.key, e.value)),
          ]),
        );
      }),
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

