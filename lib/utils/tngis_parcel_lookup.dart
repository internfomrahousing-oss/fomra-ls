import 'package:latlong2/latlong.dart';
import '../services/api_client.dart';

class TngisParcelDetails {
  final String? surveyNumber;
  final String? subDivision;
  final String? village;
  final String? taluk;
  final String? district;
  final String? districtCode;
  final String? talukCode;
  final String? villageCode;
  final String? ulpin;
  final String? centroid;
  final String? ruralUrban;
  final String? kide;
  final String? pattaNumber;
  final String? giViewerUrl;
  final bool fmbAvailable;
  final bool containsPoint;
  final Map<String, String> fields;

  const TngisParcelDetails({
    this.surveyNumber,
    this.subDivision,
    this.village,
    this.taluk,
    this.district,
    this.districtCode,
    this.talukCode,
    this.villageCode,
    this.ulpin,
    this.centroid,
    this.ruralUrban,
    this.kide,
    this.pattaNumber,
    this.giViewerUrl,
    this.fmbAvailable = false,
    this.containsPoint = false,
    this.fields = const {},
  });

  bool get hasSurvey => (surveyNumber ?? '').trim().isNotEmpty;

  bool get hasAdminData =>
      _hasText(district) || _hasText(taluk) || _hasText(village);

  bool get hasParcelIdentifiers =>
      hasSurvey ||
      _hasText(ulpin) ||
      _hasText(centroid) ||
      _hasText(villageCode);

  bool get isUrban {
    final ru = (ruralUrban ?? '').toLowerCase();
    return ru.contains('urban') || ru == 'u';
  }

  String get surveyLabel => isUrban ? 'T.S. Number' : 'Survey Number';

  String get subLabel => isUrban ? 'Block / Sub-div' : 'Sub Division';

  String? get villageLgdDisplay {
    final code = villageCode?.trim();
    if (code == null || code.isEmpty) return null;
    if ((ruralUrban ?? '').trim().isEmpty) return code;
    return '$code (${ruralUrban!.trim()})';
  }

  /// Land extent from TNGIS parcel attributes (Ares).
  String? get landExtentDisplay {
    final aresRaw = _field(fields, 'Extent (Ares)');
    if (aresRaw == null) return null;
    final ares = double.tryParse(aresRaw.replaceAll(',', ''));
    if (ares == null || ares <= 0) return '$aresRaw ares';
    // 1 acre ≈ 40.4686 ares (standard TN cadastral conversion).
    final acres = ares / 40.4686;
    if (acres >= 0.05) {
      final acresText = acres >= 10
          ? acres.toStringAsFixed(1)
          : acres.toStringAsFixed(2);
      return '$acresText acres ($aresRaw ares)';
    }
    return '$aresRaw ares';
  }

  static bool _hasText(String? value) => (value ?? '').trim().isNotEmpty;
}

String? parseTngisSubDivision(String? subDiv, String? kide, String? survey) {
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

String? _pick(String? primary, String? fallback) {
  final p = primary?.trim();
  if (p != null && p.isNotEmpty && p != '-') return p;
  final f = fallback?.trim();
  if (f != null && f.isNotEmpty && f != '-') return f;
  return null;
}

String? _field(Map<String, String> fields, String key) {
  final value = fields[key]?.trim();
  if (value == null || value.isEmpty || value == '-') return null;
  return value;
}

TngisParcelDetails parseTngisParcelResponse(
  Map<String, dynamic> data, {
  required double lat,
  required double lon,
}) {
  final fields = (data['fields'] as Map<String, dynamic>? ?? {})
      .map((k, v) => MapEntry(k, v.toString()));

  final survey = _pick(
    data['surveyNumber']?.toString(),
    _field(fields, 'Survey Number'),
  );
  final kideRaw = data['kide']?.toString() ?? _field(fields, 'Kide');

  String? resolvedSub = _pick(
    data['subDivision']?.toString(),
    _field(fields, 'Sub Division'),
  );
  if (resolvedSub != null && survey != null && resolvedSub == survey) {
    resolvedSub = null;
  }

  final subdivisions = data['subdivisions'] as List<dynamic>? ?? [];
  if (resolvedSub == null) {
    for (final raw in subdivisions) {
      if (raw is! Map<String, dynamic>) continue;
      if (raw['containsPoint'] != true) continue;
      final rowFields = (raw['fields'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString()));
      final rowSurvey = raw['surveyNumber']?.toString() ??
          _field(rowFields, 'Survey Number') ??
          '';
      final rowKide = raw['kide']?.toString() ?? _field(rowFields, 'Kide');
      final sub = parseTngisSubDivision(
        raw['subDivision']?.toString() ?? _field(rowFields, 'Sub Division'),
        rowKide,
        rowSurvey.isNotEmpty ? rowSurvey : survey,
      );
      if (sub != null) {
        resolvedSub = sub;
        break;
      }
    }
  }

  resolvedSub ??= parseTngisSubDivision(
    _field(fields, 'Sub Division'),
    kideRaw,
    survey,
  );

  return TngisParcelDetails(
    surveyNumber: survey,
    subDivision: resolvedSub,
    village: _pick(data['village']?.toString(), _field(fields, 'Village')),
    taluk: _pick(data['taluk']?.toString(), _field(fields, 'Taluk')),
    district: _pick(data['district']?.toString(), _field(fields, 'District')),
    districtCode: _field(fields, 'District Code'),
    talukCode: _field(fields, 'Taluk Code'),
    villageCode: _field(fields, 'Village Code'),
    ulpin: data['ulpin']?.toString(),
    centroid: _pick(
      data['centroid']?.toString(),
      '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}',
    ),
    ruralUrban: data['ruralUrban']?.toString(),
    kide: kideRaw,
    pattaNumber: _field(fields, 'Patta Number'),
    giViewerUrl: data['giViewerUrl']?.toString(),
    fmbAvailable: data['fmbAvailable'] == true,
    containsPoint: data['containsPoint'] == true || resolvedSub != null,
    fields: fields,
  );
}

/// Fetches full parcel + village metadata from TNGIS for a map point.
/// Throws [ApiException] on HTTP errors (404, timeout, etc.).
Future<TngisParcelDetails> fetchTngisParcelAt(LatLng loc) async {
  final result = await ApiClient.get(
    '/api/tnlands/tngis/parcel?'
    'lat=${loc.latitude}&lon=${loc.longitude}',
    timeout: const Duration(seconds: 90),
  );

  return parseTngisParcelResponse(
    result,
    lat: loc.latitude,
    lon: loc.longitude,
  );
}
