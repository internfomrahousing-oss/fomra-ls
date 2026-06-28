import 'dart:typed_data';

import 'land_lead.dart';

class AddLeadResult {
  final LandLead lead;
  final Uint8List? sitePhotoBytes;

  const AddLeadResult({required this.lead, this.sitePhotoBytes});
}
