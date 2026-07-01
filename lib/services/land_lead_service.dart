import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/land_lead.dart';
import '../utils/image_compressor.dart';
import 'auth_service.dart';

class LandLeadService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const _photoBucket = 'land-lead-photos';

  static Future<List<LandLead>> getAll() async {
    final rows = await _db
        .from('land_leads')
        .select()
        .order('added_on', ascending: false);
    return (rows as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
  }

  static Future<LandLead> create(
    LandLead lead, {
    List<Uint8List> sitePhotoBytes = const [],
  }) async {
    final userId = _db.auth.currentUser?.id;
    final createdByName = AuthService.instance.currentUser?.fullName ?? '';
    final leadId = await _db.rpc('generate_land_lead_id') as String;

    var sitePhotoUrls = List<String>.from(lead.sitePhotoUrls);
    var sitePhotoUrl = lead.sitePhotoUrl;

    final row = await _db
        .from('land_leads')
        .insert({
          'id': leadId,
          'input_source': lead.inputSource.name,
          'location': lead.location,
          'gps_coordinates': lead.gpsCoordinates,
          'village': lead.village,
          'taluk': lead.taluk,
          'district': lead.district,
          'pincode': lead.pincode,
          'survey_number': lead.surveyNumber,
          'sub_division': lead.subDivision,
          'land_extent': lead.landExtent,
          'owner_name': lead.ownerName,
          'contact_details': lead.contactDetails,
          'land_type': lead.landType.name,
          'road_width': lead.roadWidth,
          'access_details': lead.accessDetails,
          'notes': lead.notes,
          'status': lead.status.name,
          'added_on': lead.addedOn.toUtc().toIso8601String(),
          if (userId != null) 'created_by': userId,
          if (createdByName.isNotEmpty) 'created_by_name': createdByName,
        })
        .select()
        .single();

    final photos = sitePhotoBytes.where((b) => b.isNotEmpty).take(4).toList();
    if (photos.isNotEmpty) {
      sitePhotoUrls = [];
      for (var i = 0; i < photos.length; i++) {
        final url = await _uploadSitePhoto(leadId, photos[i], index: i + 1);
        sitePhotoUrls.add(url);
      }
      sitePhotoUrl = sitePhotoUrls.first;
      await _db.from('land_leads').update({
        'site_photo_url': sitePhotoUrl,
        'site_photo_urls': sitePhotoUrls,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', leadId);
    }

    return _fromRow({
      ...row,
      'site_photo_url': sitePhotoUrl,
      'site_photo_urls': sitePhotoUrls,
      'sub_division': lead.subDivision,
    });
  }

  static Future<String> _uploadSitePhoto(
    String leadId,
    Uint8List rawBytes, {
    required int index,
  }) async {
    final compressed = await ImageCompressor.compressTo250Kb(rawBytes);
    final path = index == 1 ? '$leadId.jpg' : '${leadId}_$index.jpg';

    await _db.storage.from(_photoBucket).uploadBinary(
          path,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return _db.storage.from(_photoBucket).getPublicUrl(path);
  }

  static Future<void> updateStatus(String leadId, LeadStatus status) async {
    await _db.from('land_leads').update({
      'status': status.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', leadId);
  }

  static Future<void> delete(String leadId) async {
    await _db.from('land_leads').delete().eq('id', leadId);
  }

  static LandLead _fromRow(Map<String, dynamic> r) {
    final urlsRaw = r['site_photo_urls'];
    List<String> photoUrls = [];
    if (urlsRaw is List) {
      photoUrls = urlsRaw.map((e) => e.toString()).where((u) => u.isNotEmpty).toList();
    }
    final single = r['site_photo_url'] as String? ?? '';
    if (photoUrls.isEmpty && single.isNotEmpty) {
      photoUrls = [single];
    }

    return LandLead(
      leadId: r['id'] as String,
      inputSource: InputSource.values.firstWhere(
        (e) => e.name == r['input_source'],
        orElse: () => InputSource.broker,
      ),
      location: r['location'] as String? ?? '',
      gpsCoordinates: r['gps_coordinates'] as String? ?? '',
      village: r['village'] as String? ?? '',
      taluk: r['taluk'] as String? ?? '',
      district: r['district'] as String? ?? '',
      pincode: r['pincode'] as String? ?? '',
      surveyNumber: r['survey_number'] as String? ?? '',
      subDivision: r['sub_division'] as String? ?? '',
      landExtent: r['land_extent'] as String? ?? '',
      ownerName: r['owner_name'] as String,
      contactDetails: r['contact_details'] as String? ?? '',
      landType: LandType.values.firstWhere(
        (e) => e.name == r['land_type'],
        orElse: () => LandType.agricultural,
      ),
      roadWidth: r['road_width'] as String? ?? '',
      accessDetails: r['access_details'] as String? ?? '',
      notes: r['notes'] as String? ?? '',
      sitePhotoUrl: photoUrls.isNotEmpty ? photoUrls.first : single,
      sitePhotoUrls: photoUrls,
      addedOn: DateTime.parse(r['added_on'] as String),
      createdByName: r['created_by_name'] as String? ?? '',
      status: LeadStatus.values.firstWhere(
        (e) => e.name == r['status'],
        orElse: () => LeadStatus.new_,
      ),
    );
  }
}
