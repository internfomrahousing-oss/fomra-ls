import 'dart:typed_data';

import 'land_lead.dart';

class AddLeadResult {
  final LandLead lead;
  final List<Uint8List> sitePhotoBytes;
  final bool isEdit;

  const AddLeadResult({
    required this.lead,
    this.sitePhotoBytes = const [],
    this.isEdit = false,
  });
}
