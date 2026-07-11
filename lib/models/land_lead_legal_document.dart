class LandLeadLegalDocument {
  final String id;
  final String leadId;
  final String fileName;
  final String fileUrl;
  final DateTime verifiedAt;
  final String loggedByName;

  const LandLeadLegalDocument({
    required this.id,
    required this.leadId,
    required this.fileName,
    required this.fileUrl,
    required this.verifiedAt,
    required this.loggedByName,
  });

  factory LandLeadLegalDocument.fromJson(Map<String, dynamic> j) =>
      LandLeadLegalDocument(
        id: j['id'] as String,
        leadId: j['lead_id'] as String,
        fileName: j['file_name'] as String? ?? '',
        fileUrl: j['file_url'] as String? ?? '',
        verifiedAt: DateTime.parse(j['verified_at'] as String),
        loggedByName: j['logged_by_name'] as String? ?? '',
      );
}
