import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lead_call_log.dart';
import 'auth_service.dart';

class LeadCallLogService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<LeadCallLog>> getForLead(String leadId) async {
    final rows = await _db
        .from('lead_call_logs')
        .select()
        .eq('lead_id', leadId)
        .order('called_at', ascending: false);
    return (rows as List)
        .map((r) => LeadCallLog.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<LeadCallLog> create({
    required String leadId,
    required DateTime calledAt,
    required String duration,
    required String details,
    required CallDirection direction,
    required CallOutcome outcome,
  }) async {
    final userId = _db.auth.currentUser?.id;
    final loggedByName = AuthService.instance.currentUser?.fullName ?? '';

    final row = await _db
        .from('lead_call_logs')
        .insert({
          'lead_id': leadId,
          'called_at': calledAt.toUtc().toIso8601String(),
          'duration': duration.trim(),
          'details': details.trim(),
          'direction': direction.dbValue,
          'outcome': outcome.dbValue,
          if (loggedByName.isNotEmpty) 'logged_by_name': loggedByName,
          if (userId != null) 'logged_by': userId,
        })
        .select()
        .single();

    return LeadCallLog.fromJson(row);
  }
}
