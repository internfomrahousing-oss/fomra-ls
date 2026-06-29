import 'package:latlong2/latlong.dart';
import '../services/api_client.dart';

class TngisParcelDetails {
  final String? surveyNumber;
  final String? subDivision;
  final String? village;
  final String? taluk;
  final String? district;

  const TngisParcelDetails({
    this.surveyNumber,
    this.subDivision,
    this.village,
    this.taluk,
    this.district,
  });

  bool get hasSurvey => (surveyNumber ?? '').trim().isNotEmpty;
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

/// Fetches survey no. and sub-division from TNGIS for a map point.
/// Throws [ApiException] on HTTP errors (404, timeout, etc.).
Future<TngisParcelDetails> fetchTngisParcelAt(LatLng loc) async {
  final result = await ApiClient.get(
    '/api/tnlands/tngis/parcel?'
    'lat=${loc.latitude}&lon=${loc.longitude}',
    timeout: const Duration(seconds: 90),
  );

  final fields = (result['fields'] as Map<String, dynamic>? ?? {})
      .map((k, v) => MapEntry(k, v.toString()));
  final survey = _pick(
    result['surveyNumber']?.toString(),
    fields['Survey Number'],
  );
  final kideRaw = result['kide']?.toString() ?? fields['Kide'];

  // Backend resolves subDivision at map tap — prefer that first.
  String? resolvedSub = _pick(
    result['subDivision']?.toString(),
    fields['Sub Division'],
  );
  if (resolvedSub != null && survey != null && resolvedSub == survey) {
    resolvedSub = null;
  }

  final subdivisions = result['subdivisions'] as List<dynamic>? ?? [];
  if (resolvedSub == null) {
    for (final raw in subdivisions) {
      if (raw is! Map<String, dynamic>) continue;
      if (raw['containsPoint'] != true) continue;
      final rowFields = (raw['fields'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v.toString()));
      final rowSurvey =
          raw['surveyNumber']?.toString() ?? rowFields['Survey Number'] ?? '';
      final rowKide = raw['kide']?.toString() ?? rowFields['Kide'];
      final sub = parseTngisSubDivision(
        raw['subDivision']?.toString() ?? rowFields['Sub Division'],
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
    fields['Sub Division'],
    kideRaw,
    survey,
  );

  return TngisParcelDetails(
    surveyNumber: survey,
    subDivision: resolvedSub,
    village: _pick(result['village']?.toString(), fields['Village']),
    taluk: _pick(result['taluk']?.toString(), fields['Taluk']),
    district: _pick(result['district']?.toString(), fields['District']),
  );
}
