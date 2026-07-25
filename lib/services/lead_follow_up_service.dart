import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lead_follow_up.dart';
import 'auth_service.dart';

/// Follow-up reminders for a lead. Degrades gracefully when the
/// `lead_follow_ups` table is missing (reads return empty, writes throw).
class LeadFollowUpService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const _table = 'lead_follow_ups';

  /// Every follow-up for a lead, newest scheduled first.
  static Future<List<LeadFollowUp>> getForLead(String leadId) async {
    try {
      final rows = await _db
          .from(_table)
          .select()
          .eq('lead_id', leadId)
          .order('remind_at', ascending: false);
      return (rows as List)
          .map((r) => LeadFollowUp.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Creates a follow-up for a lead, scheduled for [remindAt].
  static Future<LeadFollowUp> create({
    required String leadId,
    required String title,
    required DateTime remindAt,
    String notes = '',
  }) async {
    final user = AuthService.instance.currentUser;
    final row = await _db
        .from(_table)
        .insert({
          'lead_id': leadId,
          'title': title.trim(),
          'notes': notes.trim(),
          'remind_at': remindAt.toUtc().toIso8601String(),
          'status': 'pending',
          'created_by': user?.fullName ?? '',
          'created_by_email': (user?.email ?? '').trim().toLowerCase(),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    return LeadFollowUp.fromJson(Map<String, dynamic>.from(row));
  }

  /// Marks a follow-up completed.
  static Future<void> markCompleted(String id) async {
    await _db.from(_table).update({
      'status': 'completed',
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  /// Pending follow-ups whose time has passed, created by [email] — the source
  /// the reminder sync turns into notifications. Empty email → nothing (so a
  /// signed-out/anon state never surfaces someone else's reminders).
  static Future<List<LeadFollowUp>> dueForUser(String email) async {
    final me = email.trim().toLowerCase();
    if (me.isEmpty) return const [];
    try {
      final rows = await _db
          .from(_table)
          .select()
          .eq('status', 'pending')
          .eq('created_by_email', me)
          .lte('remind_at', DateTime.now().toUtc().toIso8601String())
          .order('remind_at', ascending: false);
      return (rows as List)
          .map((r) => LeadFollowUp.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
