import 'dart:convert';

import 'package:http/http.dart' as http;

class GeocodedAddress {
  final String location;
  final String village;
  final String taluk;
  final String district;
  final String pincode;

  const GeocodedAddress({
    this.location = '',
    this.village = '',
    this.taluk = '',
    this.district = '',
    this.pincode = '',
  });
}

const _geoHeaders = {
  'Accept-Language': 'en',
  'User-Agent': 'FomraLS/1.0 (in.fomrahousing)',
};

/// Normalizes raw values to a valid 6-digit Indian pincode, or null.
String? normalizeIndianPincode(dynamic raw) {
  if (raw == null) return null;
  final digits = raw.toString().replaceAll(RegExp(r'\D'), '');
  if (digits.length == 6 && RegExp(r'^[1-9]').hasMatch(digits)) {
    return digits;
  }
  return null;
}

/// Pulls the first 6-digit Indian pincode from free text (e.g. display_name).
String? extractIndianPincodeFromText(String text) {
  final match = RegExp(r'\b([1-9][0-9]{5})\b').firstMatch(text.trim());
  return match?.group(1);
}

String _firstNonEmpty(Map<String, dynamic> addr, List<String> keys) {
  for (final key in keys) {
    final value = addr[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _cleanDistrict(String raw) {
  return raw.replaceAll(RegExp(r'\s+[Dd]istrict$'), '').trim();
}

String _cleanAdminLabel(String raw) {
  return raw
      .replaceAll(RegExp(r'^Zone\s+\d+\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'^CMWSSB Division\s+\d+\s*', caseSensitive: false), '')
      .replaceAll(RegExp(r'^Ward\s*\d+\s*', caseSensitive: false), '')
      .trim();
}

GeocodedAddress parseNominatimReverse(Map<String, dynamic> data) {
  final addr = (data['address'] as Map<String, dynamic>?) ?? {};
  final displayName = data['display_name']?.toString() ?? '';

  final pincode =
      normalizeIndianPincode(addr['postcode']) ??
      extractIndianPincodeFromText(displayName);

  final village = _firstNonEmpty(addr, ['village', 'hamlet', 'town']);
  final suburb = _cleanAdminLabel(
    _firstNonEmpty(addr, ['suburb', 'neighbourhood', 'quarter']),
  );

  // Tamil Nadu: taluk is usually in `county`; district in `state_district`.
  final taluk = _cleanAdminLabel(_firstNonEmpty(addr, [
    'county',
    'city_district',
    'municipality',
    'suburb',
  ]));
  final district = _cleanDistrict(_firstNonEmpty(addr, [
    'state_district',
    'district',
  ]));

  final location = _cleanAdminLabel(_firstNonEmpty(addr, [
    'suburb',
    'neighbourhood',
    'quarter',
    'road',
    'city',
    'town',
    'village',
  ]));

  return GeocodedAddress(
    location: location.isNotEmpty ? location : (village.isNotEmpty ? village : suburb),
    village: village.isNotEmpty ? village : suburb,
    taluk: taluk,
    district: district,
    pincode: pincode ?? '',
  );
}

GeocodedAddress? parseNominatimSearchHit(Map<String, dynamic> hit) {
  final addr = (hit['address'] as Map<String, dynamic>?) ?? {};
  final displayName = hit['display_name']?.toString() ?? '';
  final pincode =
      normalizeIndianPincode(addr['postcode']) ??
      extractIndianPincodeFromText(displayName);
  if (pincode == null) return null;

  return GeocodedAddress(
    location: _cleanAdminLabel(_firstNonEmpty(addr, ['suburb', 'village', 'city'])),
    village: _firstNonEmpty(addr, ['village', 'hamlet', 'town']),
    taluk: _cleanAdminLabel(_firstNonEmpty(addr, ['county', 'city_district', 'municipality'])),
    district: _cleanDistrict(_firstNonEmpty(addr, ['state_district', 'district'])),
    pincode: pincode,
  );
}

/// Reverse-geocodes GPS to village/taluk/district/pincode (address-level zoom).
Future<GeocodedAddress?> fetchReverseGeocode(double lat, double lng) async {
  final uri = Uri.parse(
    'https://nominatim.openstreetmap.org/reverse'
    '?format=jsonv2&lat=$lat&lon=$lng&addressdetails=1&zoom=18&countrycodes=in',
  );

  final response = await http
      .get(uri, headers: _geoHeaders)
      .timeout(const Duration(seconds: 12));

  if (response.statusCode != 200) return null;

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return parseNominatimReverse(data);
}

/// Looks up pincode from admin names (prefer after TNGIS village/taluk/district).
Future<String?> fetchPincodeForAdminArea({
  String? village,
  String? taluk,
  String? district,
}) async {
  final parts = <String>[
    if ((village ?? '').trim().isNotEmpty) village!.trim(),
    if ((taluk ?? '').trim().isNotEmpty) taluk!.trim(),
    if ((district ?? '').trim().isNotEmpty) district!.trim(),
    'Tamil Nadu',
    'India',
  ];
  if (parts.length < 3) return null;

  final uri = Uri.parse(
    'https://nominatim.openstreetmap.org/search'
    '?format=jsonv2&limit=1&addressdetails=1&countrycodes=in'
    '&q=${Uri.encodeComponent(parts.join(', '))}',
  );

  final response = await http
      .get(uri, headers: _geoHeaders)
      .timeout(const Duration(seconds: 12));

  if (response.statusCode != 200) return null;

  final results = jsonDecode(response.body) as List<dynamic>;
  if (results.isEmpty) return null;

  final hit = results.first as Map<String, dynamic>;
  final parsed = parseNominatimSearchHit(hit);
  return parsed?.pincode;
}

class LocationSearchHit {
  final double lat;
  final double lng;
  final String displayName;

  const LocationSearchHit({
    required this.lat,
    required this.lng,
    required this.displayName,
  });
}

/// Forward-geocodes a place name to coordinates (Nominatim, India-biased).
Future<List<LocationSearchHit>> searchLocations(
  String query, {
  int limit = 5,
}) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return [];

  final uri = Uri.parse(
    'https://nominatim.openstreetmap.org/search'
    '?format=jsonv2&limit=$limit&addressdetails=1&countrycodes=in'
    '&q=${Uri.encodeComponent('$trimmed, Tamil Nadu, India')}',
  );

  final response = await http
      .get(uri, headers: _geoHeaders)
      .timeout(const Duration(seconds: 12));

  if (response.statusCode != 200) return [];

  final results = jsonDecode(response.body) as List<dynamic>;
  return results.map((raw) {
    final hit = raw as Map<String, dynamic>;
    final lat = double.tryParse(hit['lat']?.toString() ?? '');
    final lng = double.tryParse(hit['lon']?.toString() ?? '');
    if (lat == null || lng == null) return null;
    return LocationSearchHit(
      lat: lat,
      lng: lng,
      displayName: hit['display_name']?.toString() ?? trimmed,
    );
  }).whereType<LocationSearchHit>().toList();
}
