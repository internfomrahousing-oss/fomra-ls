import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/land_lead_site_visit.dart';
import 'auth_service.dart';

class LandLeadSiteVisitService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<LandLeadSiteVisit>> getAllForLead(String leadId) async {
    final rows = await _db
        .from('land_lead_site_visits')
        .select()
        .eq('lead_id', leadId)
        .order('visited_at', ascending: false);
    return (rows as List)
        .map((r) => LandLeadSiteVisit.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<List<LandLeadSiteVisit>> getForLead(
    String leadId, {
    required LandLeadSiteVisitType visitType,
  }) async {
    final rows = await _db
        .from('land_lead_site_visits')
        .select()
        .eq('lead_id', leadId)
        .eq('visit_type', visitType.dbValue)
        .order('visited_at', ascending: false);
    return (rows as List)
        .map((r) => LandLeadSiteVisit.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<LandLeadSiteVisit> markDone({
    required String leadId,
    required DateTime visitedAt,
    required LandLeadSiteVisitType visitType,
  }) async {
    final userId = _db.auth.currentUser?.id;
    final loggedByName = AuthService.instance.currentUser?.fullName ?? '';

    final row = await _db
        .from('land_lead_site_visits')
        .insert({
          'lead_id': leadId,
          'visited_at': visitedAt.toUtc().toIso8601String(),
          'visit_type': visitType.dbValue,
          if (loggedByName.isNotEmpty) 'logged_by_name': loggedByName,
          if (userId != null) 'logged_by': userId,
        })
        .select()
        .single();

    return LandLeadSiteVisit.fromJson(row);
  }
}
