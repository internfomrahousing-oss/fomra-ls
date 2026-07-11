class LandLeadMeeting {
  final String id;
  final String leadId;
  final DateTime metAt;
  final String duration;
  final String notes;
  final String loggedByName;

  const LandLeadMeeting({
    required this.id,
    required this.leadId,
    required this.metAt,
    required this.duration,
    required this.notes,
    required this.loggedByName,
  });

  factory LandLeadMeeting.fromJson(Map<String, dynamic> j) => LandLeadMeeting(
        id: j['id'] as String,
        leadId: j['lead_id'] as String,
        metAt: DateTime.parse(j['met_at'] as String),
        duration: j['duration'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        loggedByName: j['logged_by_name'] as String? ?? '',
      );
}
