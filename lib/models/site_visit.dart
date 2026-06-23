class SiteVisit {
  final String id;
  final String? leadId;
  final String? leadName;
  final String? leadPhone;
  final DateTime scheduledAt;
  final DateTime? actualAt;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String status;
  final String? notes;
  final String? feedback;
  final String? agentId;
  final String? agentName;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const List<String> statuses = ['scheduled', 'completed', 'cancelled', 'no_show'];

  const SiteVisit({
    required this.id,
    this.leadId,
    this.leadName,
    this.leadPhone,
    required this.scheduledAt,
    this.actualAt,
    this.address,
    this.latitude,
    this.longitude,
    required this.status,
    this.notes,
    this.feedback,
    this.agentId,
    this.agentName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SiteVisit.fromJson(Map<String, dynamic> j) => SiteVisit(
        id: j['id'] as String,
        leadId: j['lead_id'] as String?,
        leadName: j['lead_name'] as String?,
        leadPhone: j['lead_phone'] as String?,
        scheduledAt: DateTime.parse(j['scheduled_at'] as String),
        actualAt: j['actual_at'] != null ? DateTime.parse(j['actual_at'] as String) : null,
        address: j['address'] as String?,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        status: j['status'] as String? ?? 'scheduled',
        notes: j['notes'] as String?,
        feedback: j['feedback'] as String?,
        agentId: j['agent_id'] as String?,
        agentName: j['agent_name'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'lead_id': leadId,
        'scheduled_at': scheduledAt.toIso8601String(),
        'actual_at': actualAt?.toIso8601String(),
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'status': status,
        'notes': notes,
        'feedback': feedback,
        'agent_id': agentId,
      };
}
