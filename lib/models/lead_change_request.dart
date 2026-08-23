class LeadFieldChange {
  final String field;
  final String label;
  final String oldValue;
  final String newValue;

  const LeadFieldChange({
    required this.field,
    required this.label,
    required this.oldValue,
    required this.newValue,
  });

  factory LeadFieldChange.fromJson(String field, Map<String, dynamic> j) =>
      LeadFieldChange(
        field: field,
        label: j['label'] as String? ?? field,
        oldValue: j['old'] as String? ?? '',
        newValue: j['new'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'old': oldValue,
        'new': newValue,
      };
}

class LeadChangeRequest {
  final String id;
  final String leadId;
  final List<LeadFieldChange> changes;
  final String requestedByName;
  final String requestedByEmail;
  final String status; // pending / approved / rejected
  final String reviewedByName;
  final DateTime? reviewedAt;
  final String rejectionReason;
  final DateTime createdAt;

  const LeadChangeRequest({
    required this.id,
    required this.leadId,
    required this.changes,
    this.requestedByName = '',
    this.requestedByEmail = '',
    this.status = 'pending',
    this.reviewedByName = '',
    this.reviewedAt,
    this.rejectionReason = '',
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  factory LeadChangeRequest.fromJson(Map<String, dynamic> j) {
    final rawChanges = (j['changes'] as Map<String, dynamic>?) ?? const {};
    return LeadChangeRequest(
      id: j['id'] as String,
      leadId: j['lead_id'] as String,
      changes: rawChanges.entries
          .map((e) => LeadFieldChange.fromJson(
              e.key, Map<String, dynamic>.from(e.value as Map)))
          .toList(),
      requestedByName: j['requested_by_name'] as String? ?? '',
      requestedByEmail: j['requested_by_email'] as String? ?? '',
      status: j['status'] as String? ?? 'pending',
      reviewedByName: j['reviewed_by_name'] as String? ?? '',
      reviewedAt: j['reviewed_at'] == null
          ? null
          : DateTime.tryParse(j['reviewed_at'] as String),
      rejectionReason: j['rejection_reason'] as String? ?? '',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
