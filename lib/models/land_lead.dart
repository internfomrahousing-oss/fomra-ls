enum InputSource { broker, landowner, referral, internalTeam, existingDatabase }

enum LandType { agricultural, nonAgricultural, residential, commercial, industrial, other }

enum LeadStatus { new_, contacted, siteVisit, negotiation, closed, lost }

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
  final LandType landType;
  final String roadWidth;
  final String accessDetails;
  final String notes;
  final String sitePhotoUrl;
  final List<String> sitePhotoUrls;
  final DateTime addedOn;
  LeadStatus status;

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
    required this.landType,
    required this.roadWidth,
    required this.accessDetails,
    required this.notes,
    this.sitePhotoUrl = '',
    this.sitePhotoUrls = const [],
    required this.addedOn,
    this.status = LeadStatus.new_,
  });

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
        LeadStatus.new_ => 'New',
        LeadStatus.contacted => 'Contacted',
        LeadStatus.siteVisit => 'Site Visit',
        LeadStatus.negotiation => 'Negotiation',
        LeadStatus.closed => 'Closed',
        LeadStatus.lost => 'Lost',
      };
}
