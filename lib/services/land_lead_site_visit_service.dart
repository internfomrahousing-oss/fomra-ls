import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/land_lead_site_visit.dart';
import 'auth_service.dart';
import 'notifications_service.dart';

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

  static Future<LandLeadSiteVisit?> getById(String id) async {
    final row = await _db
        .from('land_lead_site_visits')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return LandLeadSiteVisit.fromJson(row);
  }

  static Future<LandLeadSiteVisit> markDone({
    required String leadId,
    required DateTime visitedAt,
    required LandLeadSiteVisitType visitType,
  }) async {
    final userId = _db.auth.currentUser?.id;
    final loggedByName = AuthService.instance.currentUser?.fullName ?? '';
    final isEmployee = AuthService.instance.isEmployee;
    final needsApproval =
        visitType == LandLeadSiteVisitType.management && isEmployee;

    final row = await _db
        .from('land_lead_site_visits')
        .insert({
          'lead_id': leadId,
          'visited_at': visitedAt.toUtc().toIso8601String(),
          'visit_type': visitType.dbValue,
          'approval_status': needsApproval ? 'pending' : 'approved',
          if (loggedByName.isNotEmpty) 'logged_by_name': loggedByName,
          if (userId != null) 'logged_by': userId,
        })
        .select()
        .single();

    final visit = LandLeadSiteVisit.fromJson(row);

    if (needsApproval) {
      final who = loggedByName.isNotEmpty ? loggedByName : 'An employee';
      NotificationsService.create(
        audience: 'management',
        type: 'site_visit',
        title: 'Management site visit requested',
        message: '$who requested a management site visit for Lead #$leadId',
        leadId: leadId,
        referenceId: visit.id,
      ).catchError((_) {});
    }

    return visit;
  }

  static Future<LandLeadSiteVisit> review({
    required String visitId,
    required SiteVisitApprovalStatus status,
    required String notes,
  }) async {
    final reviewer = AuthService.instance.currentUser?.fullName ?? 'Management';
    final row = await _db
        .from('land_lead_site_visits')
        .update({
          'approval_status': status.dbValue,
          'management_notes': notes.trim(),
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'reviewed_by_name': reviewer,
        })
        .eq('id', visitId)
        .select()
        .single();

    final visit = LandLeadSiteVisit.fromJson(row);
    final approved = status == SiteVisitApprovalStatus.approved;
    NotificationsService.create(
      audience: 'employee',
      type: 'site_visit',
      title: approved
          ? 'Management visit approved'
          : 'Management visit rejected',
      message: approved
          ? 'Lead #${visit.leadId} management site visit was approved'
              '${notes.trim().isNotEmpty ? ' — $notes' : ''}'
          : 'Lead #${visit.leadId} management site visit was rejected'
              '${notes.trim().isNotEmpty ? ' — $notes' : ''}',
      leadId: visit.leadId,
      referenceId: visit.id,
    ).catchError((_) {});

    return visit;
  }
}
