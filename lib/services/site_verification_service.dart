import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/site_verification.dart';

class SiteVerificationService {
  static final _db = Supabase.instance.client;

  static Future<List<SiteVerification>> getAll() async {
    final rows = await _db
        .from('site_verifications')
        .select()
        .order('captured_on', ascending: false);
    return (rows as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
  }

  static Future<void> save(SiteVerification sv) async {
    await _db.from('site_verifications').upsert(_toRow(sv));
  }

  static SiteVerification _fromRow(Map<String, dynamic> r) => SiteVerification(
        id: r['id'] as String,
        leadReference: r['lead_id'] as String,
        geoCoordinates: r['geo_coordinates'] as String? ?? '',
        geoAddress: r['geo_address'] as String? ?? '',
        pincode: r['pincode'] as String? ?? '',
        photographs: [], // file bytes are not stored in DB
        roadAccess: r['road_access'] as String? ?? '',
        nearbyLandmarks: r['nearby_landmarks'] as String? ?? '',
        siteObservations: r['site_observations'] as String? ?? '',
        capturedOn: DateTime.parse(r['captured_on'] as String),
        status: _parseStatus(r['status'] as String? ?? ''),
      );

  static Map<String, dynamic> _toRow(SiteVerification sv) => {
        'id': sv.id,
        'lead_id': sv.leadReference,
        'geo_coordinates': sv.geoCoordinates,
        'geo_address': sv.geoAddress,
        'pincode': sv.pincode,
        'road_access': sv.roadAccess,
        'nearby_landmarks': sv.nearbyLandmarks,
        'site_observations': sv.siteObservations,
        'status': sv.status.name,
        'captured_on': sv.capturedOn.toIso8601String(),
        'photo_count': sv.photographs.length,
        'has_video': sv.video != null,
        'updated_at': DateTime.now().toIso8601String(),
      };

  static VerificationStatus _parseStatus(String s) => switch (s) {
        'completed' => VerificationStatus.completed,
        'inProgress' => VerificationStatus.inProgress,
        'failed' => VerificationStatus.failed,
        _ => VerificationStatus.scheduled,
      };
}
