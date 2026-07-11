enum LandLeadSiteVisitType {
  employee,
  management;

  String get dbValue => name;

  String get label => switch (this) {
        LandLeadSiteVisitType.employee => 'Site visit',
        LandLeadSiteVisitType.management => 'Management site visit',
      };
}

class LandLeadSiteVisit {
  final String id;
  final String leadId;
  final DateTime visitedAt;
  final String loggedByName;
  final LandLeadSiteVisitType visitType;

  const LandLeadSiteVisit({
    required this.id,
    required this.leadId,
    required this.visitedAt,
    required this.loggedByName,
    this.visitType = LandLeadSiteVisitType.employee,
  });

  factory LandLeadSiteVisit.fromJson(Map<String, dynamic> j) {
    final rawType = j['visit_type'] as String? ?? 'employee';
    final visitType = LandLeadSiteVisitType.values.firstWhere(
      (t) => t.dbValue == rawType,
      orElse: () => LandLeadSiteVisitType.employee,
    );
    return LandLeadSiteVisit(
      id: j['id'] as String,
      leadId: j['lead_id'] as String,
      visitedAt: DateTime.parse(j['visited_at'] as String),
      loggedByName: j['logged_by_name'] as String? ?? '',
      visitType: visitType,
    );
  }
}
