class LeadCallLog {
  final String id;
  final String leadId;
  final DateTime calledAt;
  final String duration;
  final String details;
  final String loggedByName;

  const LeadCallLog({
    required this.id,
    required this.leadId,
    required this.calledAt,
    required this.duration,
    required this.details,
    required this.loggedByName,
  });

  factory LeadCallLog.fromJson(Map<String, dynamic> j) => LeadCallLog(
        id: j['id'] as String,
        leadId: j['lead_id'] as String,
        calledAt: DateTime.parse(j['called_at'] as String),
        duration: j['duration'] as String? ?? '',
        details: j['details'] as String? ?? '',
        loggedByName: j['logged_by_name'] as String? ?? '',
      );
}
