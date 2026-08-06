/// Who was actually present on the other side of a meeting. Kept as plain
/// strings (not an enum) so the list can grow later without a schema/app
/// migration — "Land Owner" and "Agreement Holder" are the two values that
/// count toward the landowner-meeting-completed milestone (see
/// LandLeadMeetingService.logMeeting).
class MeetingAttendeeTypes {
  static const landOwner = 'Land Owner';
  static const agreementHolder = 'Agreement Holder / Power of Attorney';
  static const broker = 'Broker';
  static const familyOrFriend = 'Family / Friend';
  static const legalRepresentative = 'Legal Representative';
  static const other = 'Other';

  static const all = [
    landOwner,
    agreementHolder,
    broker,
    familyOrFriend,
    legalRepresentative,
    other,
  ];

  /// Attendee types that count as "we actually met the decision-maker" for
  /// the landowner-meeting-completed milestone.
  static const countsAsLandownerMeeting = [landOwner, agreementHolder];
}

class LandLeadMeeting {
  final String id;
  final String leadId;
  final DateTime metAt;
  final String duration;
  final String notes;
  final String loggedByName;
  final List<String> attendeeTypes;
  final bool managementPresent;

  const LandLeadMeeting({
    required this.id,
    required this.leadId,
    required this.metAt,
    required this.duration,
    required this.notes,
    required this.loggedByName,
    this.attendeeTypes = const [],
    this.managementPresent = false,
  });

  factory LandLeadMeeting.fromJson(Map<String, dynamic> j) => LandLeadMeeting(
        id: j['id'] as String,
        leadId: j['lead_id'] as String,
        metAt: DateTime.parse(j['met_at'] as String),
        duration: j['duration'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        loggedByName: j['logged_by_name'] as String? ?? '',
        attendeeTypes: (j['attendee_types'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        managementPresent: j['management_present'] as bool? ?? false,
      );
}
