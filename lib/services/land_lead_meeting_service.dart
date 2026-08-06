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
    List<String> attendeeTypes = const [],
    bool managementPresent = false,
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
          'attendee_types': attendeeTypes,
          'management_present': managementPresent,
          if (loggedByName.isNotEmpty) 'logged_by_name': loggedByName,
          if (userId != null) 'logged_by': userId,
        })
        .select()
        .single();

    // Auto-derived milestone (see the migration comment for the full
    // rationale): the first time a meeting with the owner/agreement-holder
    // is logged, stamp it on the lead so it survives future status changes.
    // Conditioned on the column still being null so an earlier, genuinely
    // first meeting's timestamp is never overwritten by a later one.
    final qualifies = attendeeTypes.any(
      (t) => MeetingAttendeeTypes.countsAsLandownerMeeting.contains(t),
    );
    if (qualifies) {
      await _db
          .from('land_leads')
          .update({
            'landowner_meeting_completed_at': metAt.toUtc().toIso8601String(),
          })
          .eq('id', leadId)
          .isFilter('landowner_meeting_completed_at', null);
    }

    return LandLeadMeeting.fromJson(row);
  }
}
