/// User-editable drop reason catalog item.
class LeadDropReason {
  final String id;
  final String label;

  const LeadDropReason({required this.id, required this.label});

  Map<String, dynamic> toJson() => {'id': id, 'label': label};

  factory LeadDropReason.fromJson(Map<String, dynamic> json) => LeadDropReason(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
      );

  LeadDropReason copyWith({String? label}) => LeadDropReason(
        id: id,
        label: label ?? this.label,
      );

  @override
  bool operator ==(Object other) =>
      other is LeadDropReason && other.id == id && other.label == label;

  @override
  int get hashCode => Object.hash(id, label);
}

const defaultLeadDropReasons = <LeadDropReason>[
  LeadDropReason(
    id: 'owner_related_issues',
    label: 'Owner Related Issues',
  ),
  LeadDropReason(
    id: 'price_budget_mismatch',
    label: 'Price / Budget Mismatch',
  ),
  LeadDropReason(
    id: 'legal_document_issues',
    label: 'Legal & Document Issues',
  ),
  LeadDropReason(
    id: 'location_surrounding_issues',
    label: 'Location & Surrounding Issues',
  ),
  LeadDropReason(
    id: 'land_suitability_issues',
    label: 'Land Suitability Issues',
  ),
  LeadDropReason(
    id: 'negotiation_failed',
    label: 'Negotiation Failed',
  ),
  LeadDropReason(
    id: 'business_management_decision',
    label: 'Business / Management Decision',
  ),
  LeadDropReason(
    id: 'land_owner_meeting_pending_no_response',
    label: 'Land Owner Meeting Pending / No Response',
  ),
];

const _legacyReasonAliases = {
  'ownerRelatedIssues': 'owner_related_issues',
  'priceBudgetMismatch': 'price_budget_mismatch',
  'legalDocumentIssues': 'legal_document_issues',
  'locationSurroundingIssues': 'location_surrounding_issues',
  'landSuitabilityIssues': 'land_suitability_issues',
  'negotiationFailed': 'negotiation_failed',
  'businessManagementDecision': 'business_management_decision',
  'duplicateInvalidNoResponse': 'land_owner_meeting_pending_no_response',
  'other': 'land_owner_meeting_pending_no_response',
  'Duplicate / Invalid / No Response':
      'land_owner_meeting_pending_no_response',
  'Land Owner Meeting Pending / No Response':
      'land_owner_meeting_pending_no_response',
};

String normalizeLeadDropReasonId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final alias = _legacyReasonAliases[trimmed];
  if (alias != null) return alias;
  return trimmed;
}

LeadDropReason? leadDropReasonFromRaw(
  String? raw, {
  List<LeadDropReason> catalog = defaultLeadDropReasons,
}) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  final id = normalizeLeadDropReasonId(trimmed);
  for (final reason in catalog) {
    if (reason.id == id || reason.label == trimmed) return reason;
  }
  for (final reason in defaultLeadDropReasons) {
    if (reason.id == id || reason.label == trimmed) return reason;
  }
  return null;
}
