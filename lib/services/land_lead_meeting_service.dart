import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/land_lead_meeting.dart';
import 'auth_service.dart';

class LandLeadMeetingService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<LandLeadMeeting>> getForLead(String leadId) async {
    final rows = await _db
        .from('land_lead_meetings')
        .select()
        .eq('lead_id', leadId)
        .order('met_at', ascending: false);
    return (rows as List)
        .map((r) => LandLeadMeeting.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<LandLeadMeeting> create({
    required String leadId,
    required DateTime metAt,
    required String duration,
    String notes = '',
  }) async {
    final userId = _db.auth.currentUser?.id;
    final loggedByName = AuthService.instance.currentUser?.fullName ?? '';

    final row = await _db
        .from('land_lead_meetings')
        .insert({
          'lead_id': leadId,
          'met_at': metAt.toUtc().toIso8601String(),
          'duration': duration.trim(),
          'notes': notes.trim(),
          if (loggedByName.isNotEmpty) 'logged_by_name': loggedByName,
          if (userId != null) 'logged_by': userId,
        })
        .select()
        .single();

    return LandLeadMeeting.fromJson(row);
  }
}
