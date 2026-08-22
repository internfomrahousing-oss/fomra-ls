import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/land_lead_rename_request.dart';
import 'audit_log_service.dart';
import 'auth_service.dart';
import 'notifications_service.dart';

/// Renaming a lead is free on the same calendar day it was saved — any
/// number of corrections — then requires management approval for every
/// rename after that day. A lead's name (or its fallback: owner name, or
/// "Lead #id") is the canonical label people refer to it by across
/// reports and conversations, so casual renaming once the initial entry
/// window has passed is deliberately made a little harder, rather than
/// left wide open. (Revised from an earlier "free once, ever" rule to
/// this time-based one, per direct product decision.)
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
        .select('added_on')
        .eq('id', leadId)
        .maybeSingle();
    if (current == null) {
      throw Exception('Lead $leadId was not found.');
    }
    final addedOn = DateTime.tryParse(current['added_on'] as String? ?? '');
    // Free to rename (any number of times) on the same calendar day the
    // lead was saved. Once that day has passed, every rename needs
    // approval — replacing the old "free once, then always needs
    // approval" rule with a time-based one, per direct product decision.
    final now = DateTime.now();
    final sameDay = addedOn != null &&
        addedOn.toLocal().year == now.year &&
        addedOn.toLocal().month == now.month &&
        addedOn.toLocal().day == now.day;

    final userName = AuthService.instance.currentUser?.fullName ?? '';
    final userEmail = AuthService.instance.currentUser?.email ?? '';
    final userId = _db.auth.currentUser?.id;

    if (sameDay) {
      // Free — same calendar day the lead was saved. Still stamps
      // lead_name_locked for historical/informational purposes (has this
      // lead ever been renamed at all), but that flag no longer gates
      // anything here.
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

  /// The one pending rename request for [leadId], if any — used by the
  /// Lead Detail screen to show a real, actionable approval banner
  /// directly on the lead, rather than management only ever discovering
  /// this via a notification.
  static Future<LandLeadRenameRequest?> getPendingForLead(String leadId) async {
    try {
      final rows = await _db
          .from('land_lead_rename_requests')
          .select()
          .eq('lead_id', leadId)
          .eq('status', 'pending')
          .order('created_at', ascending: false)
          .limit(1);
      final list = (rows as List);
      if (list.isEmpty) return null;
      return LandLeadRenameRequest.fromJson(
          Map<String, dynamic>.from(list.first));
    } catch (_) {
      return null;
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
