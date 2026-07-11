import 'package:flutter/material.dart';

enum InputSource { broker, landowner, referral, internalTeam, existingDatabase }

enum LandType { agricultural, nonAgricultural, residential, commercial, industrial, other }

enum LeadStatus {
  negotiation,
  legal,
  signed,
  dropped,
  prospectMeetingPending,
  prospectMeetingCompleted,
}

/// Parses status from Supabase, including legacy values saved before the
/// pipeline redesign.
LeadStatus parseLeadStatus(String? raw) {
  final value = raw?.trim() ?? '';
  for (final status in LeadStatus.values) {
    if (status.name == value) return status;
  }
  return switch (value) {
    'new_' => LeadStatus.prospectMeetingPending,
    'contacted' => LeadStatus.prospectMeetingPending,
    'siteVisit' => LeadStatus.prospectMeetingCompleted,
    'closed' => LeadStatus.signed,
    'lost' => LeadStatus.dropped,
    _ => LeadStatus.prospectMeetingPending,
  };
}

class LandLead {
  final String leadId;
  final InputSource inputSource;
  final String location;
  final String gpsCoordinates;
  final String village;
  final String taluk;
  final String district;
  final String pincode;
  final String surveyNumber;
  final String subDivision;
  final String landExtent;
  final String ownerName;
  final String contactDetails;
  final String brokerName;
  final String brokerContact;
  final LandType landType;
  final String roadWidth;
  final String accessDetails;
  final String notes;
  final String sitePhotoUrl;
  final List<String> sitePhotoUrls;
  final DateTime addedOn;
  final String createdByName;
  /// `employee` when the named person posted the lead themselves;
  /// `management` when management created or assigned it.
  final String createdByRole;
  LeadStatus status;
  final String dropReason;
  final String dropNotes;

  LandLead({
    required this.leadId,
    required this.inputSource,
    required this.location,
    required this.gpsCoordinates,
    required this.village,
    required this.taluk,
    required this.district,
    required this.pincode,
    required this.surveyNumber,
    this.subDivision = '',
    required this.landExtent,
    required this.ownerName,
    required this.contactDetails,
    this.brokerName = '',
    this.brokerContact = '',
    required this.landType,
    required this.roadWidth,
    required this.accessDetails,
    required this.notes,
    this.sitePhotoUrl = '',
    this.sitePhotoUrls = const [],
    required this.addedOn,
    this.createdByName = '',
    this.createdByRole = '',
    this.status = LeadStatus.prospectMeetingPending,
    this.dropReason = '',
    this.dropNotes = '',
  });

  /// Chip / summary label: employee-posted leads use "Posted by".
  String get ownershipLabel =>
      createdByRole == 'employee' ? 'Posted by' : 'Assigned';

  LandLead copyWith({
    InputSource? inputSource,
    String? location,
    String? gpsCoordinates,
    String? village,
    String? taluk,
    String? district,
    String? pincode,
    String? surveyNumber,
    String? subDivision,
    String? landExtent,
    String? ownerName,
    String? contactDetails,
    String? brokerName,
    String? brokerContact,
    LandType? landType,
    String? roadWidth,
    String? accessDetails,
    String? notes,
    String? sitePhotoUrl,
    List<String>? sitePhotoUrls,
    String? createdByName,
    String? createdByRole,
    LeadStatus? status,
    String? dropReason,
    String? dropNotes,
  }) =>
      LandLead(
        leadId: leadId,
        inputSource: inputSource ?? this.inputSource,
        location: location ?? this.location,
        gpsCoordinates: gpsCoordinates ?? this.gpsCoordinates,
        village: village ?? this.village,
        taluk: taluk ?? this.taluk,
        district: district ?? this.district,
        pincode: pincode ?? this.pincode,
        surveyNumber: surveyNumber ?? this.surveyNumber,
        subDivision: subDivision ?? this.subDivision,
        landExtent: landExtent ?? this.landExtent,
        ownerName: ownerName ?? this.ownerName,
        contactDetails: contactDetails ?? this.contactDetails,
        brokerName: brokerName ?? this.brokerName,
        brokerContact: brokerContact ?? this.brokerContact,
        landType: landType ?? this.landType,
        roadWidth: roadWidth ?? this.roadWidth,
        accessDetails: accessDetails ?? this.accessDetails,
        notes: notes ?? this.notes,
        sitePhotoUrl: sitePhotoUrl ?? this.sitePhotoUrl,
        sitePhotoUrls: sitePhotoUrls ?? this.sitePhotoUrls,
        addedOn: addedOn,
        createdByName: createdByName ?? this.createdByName,
        createdByRole: createdByRole ?? this.createdByRole,
        status: status ?? this.status,
        dropReason: dropReason ?? this.dropReason,
        dropNotes: dropNotes ?? this.dropNotes,
      );
}

extension InputSourceLabel on InputSource {
  String get label => switch (this) {
        InputSource.broker => 'Broker',
        InputSource.landowner => 'Landowner',
        InputSource.referral => 'Referral',
        InputSource.internalTeam => 'Internal Team',
        InputSource.existingDatabase => 'Existing Database',
      };
}

extension LandTypeLabel on LandType {
  String get label => switch (this) {
        LandType.agricultural => 'Agricultural',
        LandType.nonAgricultural => 'Non-Agricultural',
        LandType.residential => 'Residential',
        LandType.commercial => 'Commercial',
        LandType.industrial => 'Industrial',
        LandType.other => 'Other',
      };
}

extension LeadStatusLabel on LeadStatus {
  String get label => switch (this) {
        LeadStatus.negotiation => 'Negotiation',
        LeadStatus.legal => 'Legal',
        LeadStatus.signed => 'Signed',
        LeadStatus.dropped => 'Dropped',
        LeadStatus.prospectMeetingPending => 'Land owner meeting pending',
        LeadStatus.prospectMeetingCompleted => 'Land owner meeting completed',
      };

  /// Short label for compact chips and KPI cards.
  String get shortLabel => switch (this) {
        LeadStatus.prospectMeetingPending => 'Meeting pending',
        LeadStatus.prospectMeetingCompleted => 'Meeting completed',
        _ => label,
      };

  bool get isProspect =>
      this == LeadStatus.prospectMeetingPending ||
      this == LeadStatus.prospectMeetingCompleted;

  bool get isAcquired => this == LeadStatus.signed;

  bool get isDropped => this == LeadStatus.dropped;

  bool get isActive => !isAcquired && !isDropped;
}

/// Display order for Stage & Status dropdowns and filter chips.
const leadStatusPipelineOrder = <LeadStatus>[
  LeadStatus.negotiation,
  LeadStatus.legal,
  LeadStatus.signed,
  LeadStatus.dropped,
  LeadStatus.prospectMeetingPending,
  LeadStatus.prospectMeetingCompleted,
];

extension LeadStatusColor on LeadStatus {
  Color get color => switch (this) {
        LeadStatus.negotiation => const Color(0xFFEA580C),
        LeadStatus.legal => const Color(0xFF7C3AED),
        LeadStatus.signed => const Color(0xFF16A34A),
        LeadStatus.dropped => const Color(0xFFDC2626),
        LeadStatus.prospectMeetingPending => const Color(0xFF2563EB),
        LeadStatus.prospectMeetingCompleted => const Color(0xFF0891B2),
      };
}
