import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/land_lead_meeting.dart';
import '../models/land_lead_site_visit.dart';
import '../models/lead_call_log.dart';

/// Bulk activity fetch for management BI — three parallel queries, no N+1.
class ManagementBiActivityBundle {
  final List<LeadCallLog> calls;
  final List<LandLeadMeeting> meetings;
  final List<LandLeadSiteVisit> siteVisits;

  const ManagementBiActivityBundle({
    required this.calls,
    required this.meetings,
    required this.siteVisits,
  });

  static const empty = ManagementBiActivityBundle(
    calls: [],
    meetings: [],
    siteVisits: [],
  );
}

class ManagementBiActivityService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Loads call / meeting / site-visit rows in one round-trip batch.
  /// Failures on any table degrade gracefully to empty lists.
  static Future<ManagementBiActivityBundle> loadAll() async {
    final results = await Future.wait([
      _safeCalls(),
      _safeMeetings(),
      _safeVisits(),
    ]);
    return ManagementBiActivityBundle(
      calls: results[0] as List<LeadCallLog>,
      meetings: results[1] as List<LandLeadMeeting>,
      siteVisits: results[2] as List<LandLeadSiteVisit>,
    );
  }

  static Future<List<LeadCallLog>> _safeCalls() async {
    try {
      final rows = await _db
          .from('lead_call_logs')
          .select()
          .order('called_at', ascending: false)
          .limit(5000);
      return (rows as List)
          .map((r) => LeadCallLog.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<LandLeadMeeting>> _safeMeetings() async {
    try {
      final rows = await _db
          .from('land_lead_meetings')
          .select()
          .order('met_at', ascending: false)
          .limit(5000);
      return (rows as List)
          .map((r) => LandLeadMeeting.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<LandLeadSiteVisit>> _safeVisits() async {
    try {
      final rows = await _db
          .from('land_lead_site_visits')
          .select()
          .order('visited_at', ascending: false)
          .limit(5000);
      return (rows as List)
          .map((r) => LandLeadSiteVisit.fromJson(r as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
