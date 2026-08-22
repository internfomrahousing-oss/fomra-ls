class LandLeadRenameRequest {
  final String id;
  final String leadId;
  final String requestedName;
  final String previousName;
  final String requestedByName;
  final String requestedByEmail;
  final String status; // pending / approved / rejected
  final String reviewedByName;
  final DateTime? reviewedAt;
  final String rejectionReason;
  final DateTime createdAt;

  const LandLeadRenameRequest({
    required this.id,
    required this.leadId,
    required this.requestedName,
    this.previousName = '',
    this.requestedByName = '',
    this.requestedByEmail = '',
    this.status = 'pending',
    this.reviewedByName = '',
    this.reviewedAt,
    this.rejectionReason = '',
    required this.createdAt,
  });

  bool get isPending => status == 'pending';

  factory LandLeadRenameRequest.fromJson(Map<String, dynamic> j) =>
      LandLeadRenameRequest(
        id: j['id'] as String,
        leadId: j['lead_id'] as String,
        requestedName: j['requested_name'] as String? ?? '',
        previousName: j['previous_name'] as String? ?? '',
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
