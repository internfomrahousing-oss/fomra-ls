/// Predefined reasons when a lead is marked as dropped.
enum LeadDropReason {
  ownerRelatedIssues,
  priceBudgetMismatch,
  legalDocumentIssues,
  locationSurroundingIssues,
  landSuitabilityIssues,
  negotiationFailed,
  businessManagementDecision,
  duplicateInvalidNoResponse,
  other;

  String get label => switch (this) {
        LeadDropReason.ownerRelatedIssues => 'Owner Related Issues',
        LeadDropReason.priceBudgetMismatch => 'Price / Budget Mismatch',
        LeadDropReason.legalDocumentIssues => 'Legal & Document Issues',
        LeadDropReason.locationSurroundingIssues =>
          'Location & Surrounding Issues',
        LeadDropReason.landSuitabilityIssues => 'Land Suitability Issues',
        LeadDropReason.negotiationFailed => 'Negotiation Failed',
        LeadDropReason.businessManagementDecision =>
          'Business / Management Decision',
        LeadDropReason.duplicateInvalidNoResponse =>
          'Duplicate / Invalid / No Response',
        LeadDropReason.other => 'Other',
      };

  String get dbValue => name;

  static LeadDropReason? parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    for (final reason in LeadDropReason.values) {
      if (reason.dbValue == raw.trim()) return reason;
    }
    return null;
  }
}

const leadDropReasonOptions = LeadDropReason.values;
