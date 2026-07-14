import 'land_lead_site_visit.dart' show SiteVisitApprovalStatus;

/// An employee's request to mark a lead as Signed. Stays pending until
/// management approves it; only then does the lead stage become Signed.
class LandLeadSignedRequest {
  final String id;
  final String leadId;
  final String requestedByName;
  final String note;
  final List<String> photoUrls;
  final SiteVisitApprovalStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String reviewedByName;

  const LandLeadSignedRequest({
    required this.id,
    required this.leadId,
    required this.requestedByName,
    this.note = '',
    this.photoUrls = const [],
    this.status = SiteVisitApprovalStatus.pending,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedByName = '',
  });

  bool get isPending => status == SiteVisitApprovalStatus.pending;

  factory LandLeadSignedRequest.fromJson(Map<String, dynamic> j) {
    final rawPhotos = j['photo_urls'];
    final photos = <String>[];
    if (rawPhotos is List) {
      for (final p in rawPhotos) {
        final s = p?.toString() ?? '';
        if (s.trim().isNotEmpty) photos.add(s);
      }
    }
    final reviewedRaw = j['reviewed_at'];
    return LandLeadSignedRequest(
      id: j['id'] as String,
      leadId: j['lead_id'] as String,
      requestedByName: j['requested_by_name'] as String? ?? '',
      note: j['note'] as String? ?? '',
      photoUrls: photos,
      status: SiteVisitApprovalStatus.parse(j['status'] as String?),
      createdAt: DateTime.parse(j['created_at'] as String),
      reviewedAt:
          reviewedRaw == null ? null : DateTime.tryParse(reviewedRaw as String),
      reviewedByName: j['reviewed_by_name'] as String? ?? '',
    );
  }
}
