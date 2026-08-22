import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/land_lead_rename_request.dart';
import 'audit_log_service.dart';
import 'auth_service.dart';
import 'notifications_service.dart';

/// Renaming a lead is free the first time, then requires management
/// approval for every rename after that — per direct product decision.
/// A lead's name (or its fallback: owner name, or "Lead #id") is the
/// canonical label people refer to it by across reports and
/// conversations, so repeated casual renaming is deliberately made a
/// little harder after the first correction, rather than left wide open.
class LandLeadRenameService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Applies [newName] directly if this lead has never been renamed
  /// before (the free first correction), or creates a pending approval
  /// request otherwise. Returns true if the name was applied immediately,
  /// false if a request was created and is now awaiting management.
  static Future<bool> renameLead({
    required String leadId,
    required String previousName,
    required String newName,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Enter a name.');
    }

    final current = await _db
        .from('land_leads')
        .select('lead_name_locked')
        .eq('id', leadId)
        .maybeSingle();
    if (current == null) {
      throw Exception('Lead $leadId was not found.');
    }
    final alreadyLocked = current['lead_name_locked'] as bool? ?? false;

    final userName = AuthService.instance.currentUser?.fullName ?? '';
    final userEmail = AuthService.instance.currentUser?.email ?? '';
    final userId = _db.auth.currentUser?.id;

    if (!alreadyLocked) {
      // First rename — free, applies immediately, locks it for next time.
      await _db.from('land_leads').update({
        'lead_name': trimmed,
        'lead_name_locked': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', leadId);

      await AuditLogService.log(
        action: 'rename',
        entityType: 'lead',
        entityId: leadId,
        field: 'lead_name',
        oldValue: previousName,
        newValue: trimmed,
        module: 'Lead',
        leadId: leadId,
        executiveName: userName,
      );
      return true;
    }

    // Already renamed once — this one needs approval instead.
    await _db.from('land_lead_rename_requests').insert({
      'lead_id': leadId,
      'requested_name': trimmed,
      'previous_name': previousName,
      'requested_by': userId,
      'requested_by_name': userName,
      'requested_by_email': userEmail,
    });

    await NotificationsService.create(
      audience: 'management',
      type: 'pending_approval',
      title: 'Lead rename request · Lead $leadId',
      message: '$userName wants to rename this lead from '
          '"$previousName" to "$trimmed".',
      leadId: leadId,
    );
    return false;
  }

  static Future<List<LandLeadRenameRequest>> getPending() async {
    try {
      final rows = await _db
          .from('land_lead_rename_requests')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      return (rows as List)
          .map((r) =>
              LandLeadRenameRequest.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> approve(LandLeadRenameRequest request) async {
    final reviewerName = AuthService.instance.currentUser?.fullName ?? '';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await _db.from('land_leads').update({
      'lead_name': request.requestedName,
      'updated_at': nowIso,
    }).eq('id', request.leadId);

    await _db.from('land_lead_rename_requests').update({
      'status': 'approved',
      'reviewed_by_name': reviewerName,
      'reviewed_at': nowIso,
    }).eq('id', request.id);

    await AuditLogService.log(
      action: 'rename_approved',
      entityType: 'lead',
      entityId: request.leadId,
      field: 'lead_name',
      oldValue: request.previousName,
      newValue: request.requestedName,
      module: 'Lead',
      leadId: request.leadId,
      executiveName: reviewerName,
    );

    await NotificationsService.create(
      audience: request.requestedByEmail,
      type: 'verification',
      title: 'Lead rename approved · Lead ${request.leadId}',
      message: 'Renamed to "${request.requestedName}".',
      leadId: request.leadId,
    );
  }

  static Future<void> reject(
    LandLeadRenameRequest request, {
    String reason = '',
  }) async {
    final reviewerName = AuthService.instance.currentUser?.fullName ?? '';
    final nowIso = DateTime.now().toUtc().toIso8601String();

    await _db.from('land_lead_rename_requests').update({
      'status': 'rejected',
      'reviewed_by_name': reviewerName,
      'reviewed_at': nowIso,
      'rejection_reason': reason.trim(),
    }).eq('id', request.id);

    await NotificationsService.create(
      audience: request.requestedByEmail,
      type: 'reminder',
      title: 'Lead rename rejected · Lead ${request.leadId}',
      message: reason.trim().isEmpty
          ? 'Your request to rename this lead to "${request.requestedName}" was not approved.'
          : reason.trim(),
      leadId: request.leadId,
    );
  }
}
