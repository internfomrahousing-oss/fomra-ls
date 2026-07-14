import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/land_lead.dart';
import '../models/land_lead_signed_request.dart';
import '../models/land_lead_site_visit.dart' show SiteVisitApprovalStatus;
import 'app_store.dart';
import 'auth_service.dart';
import 'land_lead_service.dart';
import 'notifications_service.dart';

/// Signed-off approval workflow: an employee submits a lead as "Project Signed"
/// (with supporting photos/documents). The request stays pending until
/// management approves it — only then does the lead stage become Signed.
///
/// Degrades gracefully if the `land_lead_signed_requests` table is missing
/// (callers surface the error / treat pending count as zero).
class LandLeadSignedService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const _table = 'land_lead_signed_requests';

  static Future<LandLeadSignedRequest> submit({
    required String leadId,
    required String note,
    required List<String> photoUrls,
  }) async {
    final userId = _db.auth.currentUser?.id;
    final by = AuthService.instance.currentUser?.fullName ?? '';

    final row = await _db
        .from(_table)
        .insert({
          'lead_id': leadId,
          'requested_by_name': by,
          if (userId != null) 'requested_by': userId,
          'note': note.trim(),
          'photo_urls': photoUrls,
          'status': SiteVisitApprovalStatus.pending.dbValue,
        })
        .select()
        .single();

    final request = LandLeadSignedRequest.fromJson(row);

    final who = by.isNotEmpty ? by : 'An employee';
    try {
      await NotificationsService.create(
        audience: 'management',
        type: 'signed',
        title: 'Project Signed approval requested',
        message: '$who submitted Lead #$leadId to be marked as Signed',
        leadId: leadId,
        referenceId: request.id,
      );
    } catch (_) {
      // Request is saved even if the notification insert fails.
    }

    return request;
  }

  static Future<List<LandLeadSignedRequest>> getPending() async {
    final rows = await _db
        .from(_table)
        .select()
        .eq('status', SiteVisitApprovalStatus.pending.dbValue)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => LandLeadSignedRequest.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<int> countPending() async {
    try {
      return (await getPending()).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<LandLeadSignedRequest> review({
    required String id,
    required bool approve,
    String notes = '',
  }) async {
    final reviewer = AuthService.instance.currentUser?.fullName ?? 'Management';
    final row = await _db
        .from(_table)
        .update({
          'status': approve
              ? SiteVisitApprovalStatus.approved.dbValue
              : SiteVisitApprovalStatus.rejected.dbValue,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'reviewed_by_name': reviewer,
        })
        .eq('id', id)
        .select()
        .single();

    final request = LandLeadSignedRequest.fromJson(row);

    if (approve) {
      // Only now does the lead actually become Signed.
      try {
        await LandLeadService.updateStatus(request.leadId, LeadStatus.signed);
        AppStore.instance.updateLeadStatus(request.leadId, LeadStatus.signed);
      } catch (_) {
        // Status persistence may fail offline; the approval is still recorded.
      }
    }

    NotificationsService.create(
      audience: 'employee',
      type: 'signed',
      title: approve ? 'Project approved & signed' : 'Signed request rejected',
      message: approve
          ? 'Lead #${request.leadId} was approved and marked as Signed'
              '${notes.trim().isNotEmpty ? ' — $notes' : ''}'
          : 'Lead #${request.leadId} signed request was rejected'
              '${notes.trim().isNotEmpty ? ' — $notes' : ''}',
      leadId: request.leadId,
      referenceId: request.id,
    ).catchError((_) {});

    return request;
  }
}
