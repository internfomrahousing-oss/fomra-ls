enum CallDirection {
  outgoing,
  incoming;

  String get label => switch (this) {
        CallDirection.outgoing => 'Outgoing',
        CallDirection.incoming => 'Incoming',
      };

  String get dbValue => name;

  static CallDirection fromDb(String? raw) {
    return CallDirection.values.firstWhere(
      (d) => d.dbValue == raw,
      orElse: () => CallDirection.outgoing,
    );
  }
}

class LeadCallLog {
  final String id;
  final String leadId;
  final DateTime calledAt;
  final String duration;
  final String details;
  final CallDirection direction;
  final String loggedByName;

  const LeadCallLog({
    required this.id,
    required this.leadId,
    required this.calledAt,
    required this.duration,
    required this.details,
    this.direction = CallDirection.outgoing,
    required this.loggedByName,
  });

  factory LeadCallLog.fromJson(Map<String, dynamic> j) => LeadCallLog(
        id: j['id'] as String,
        leadId: j['lead_id'] as String,
        calledAt: DateTime.parse(j['called_at'] as String),
        duration: j['duration'] as String? ?? '',
        details: j['details'] as String? ?? '',
        direction: CallDirection.fromDb(j['direction'] as String?),
        loggedByName: j['logged_by_name'] as String? ?? '',
      );

  /// Logged calls require duration; treat non-zero minutes as answered.
  bool get isAnswered {
    final mins = int.tryParse(duration.trim()) ?? 0;
    return mins > 0;
  }
}

class CallActivityMetrics {
  final int outgoingNotAnswered;
  final int outgoingAnswered;
  final int incomingNotAnswered;
  final int incomingAnswered;

  const CallActivityMetrics({
    this.outgoingNotAnswered = 0,
    this.outgoingAnswered = 0,
    this.incomingNotAnswered = 0,
    this.incomingAnswered = 0,
  });

  static const zero = CallActivityMetrics();

  factory CallActivityMetrics.fromLogs(List<LeadCallLog> logs) {
    var outgoingNotAnswered = 0;
    var outgoingAnswered = 0;
    var incomingNotAnswered = 0;
    var incomingAnswered = 0;

    for (final log in logs) {
      final answered = log.isAnswered;
      switch (log.direction) {
        case CallDirection.outgoing:
          if (answered) {
            outgoingAnswered++;
          } else {
            outgoingNotAnswered++;
          }
        case CallDirection.incoming:
          if (answered) {
            incomingAnswered++;
          } else {
            incomingNotAnswered++;
          }
      }
    }

    return CallActivityMetrics(
      outgoingNotAnswered: outgoingNotAnswered,
      outgoingAnswered: outgoingAnswered,
      incomingNotAnswered: incomingNotAnswered,
      incomingAnswered: incomingAnswered,
    );
  }
}
