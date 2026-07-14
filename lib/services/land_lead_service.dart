import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/land_lead.dart';
import '../utils/image_compressor.dart';
import 'app_store.dart';
import 'audit_log_service.dart';
import 'auth_service.dart';

typedef LeadSaveProgressCallback = void Function(String message);

class LandLeadService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const _photoBucket = 'land-lead-photos';

  /// Best-effort owner/broker/executive lookup from the in-memory lead cache,
  /// used to enrich audit entries for actions that only have a `leadId`.
  static ({String owner, String broker, String executive}) _auditContextFor(
    String leadId,
  ) {
    for (final l in AppStore.instance.leads) {
      if (l.leadId == leadId) {
        return (owner: l.ownerName, broker: l.brokerName, executive: l.createdByName);
      }
    }
    return (owner: '', broker: '', executive: '');
  }

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
    LeadSaveProgressCallback? onProgress,
  }) async {
    onProgress?.call('Saving lead details…');
    final userId = _db.auth.currentUser?.id;
    final createdByName = AuthService.instance.currentUser?.fullName ?? '';
    final createdByRole =
        AuthService.instance.isManagement ? 'management' : 'employee';
    final leadId = await _db.rpc('generate_land_lead_id') as String;

    var sitePhotoUrls = List<String>.from(lead.sitePhotoUrls);
    var sitePhotoUrl = lead.sitePhotoUrl;

    final row = await _insertLandLead(
      {
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
        'broker_name': lead.brokerName,
        'broker_contact': lead.brokerContact,
        'land_type': lead.landType.name,
        'road_width': lead.roadWidth,
        'access_details': lead.accessDetails,
        'notes': lead.notes,
        'status': lead.status.name,
        'added_on': lead.addedOn.toUtc().toIso8601String(),
        if (userId != null) 'created_by': userId,
        if (createdByName.isNotEmpty) 'created_by_name': createdByName,
        'created_by_role': createdByRole,
      },
      lead.additionalOwners,
    );

    final photos = sitePhotoBytes.where((b) => b.isNotEmpty).take(4).toList();
    if (photos.isNotEmpty) {
      sitePhotoUrls = [];
      for (var i = 0; i < photos.length; i++) {
        onProgress?.call('Uploading photo ${i + 1} of ${photos.length}…');
        final url = await _uploadSitePhoto(leadId, photos[i], index: i + 1);
        sitePhotoUrls.add(url);
      }
      sitePhotoUrl = sitePhotoUrls.first;
      onProgress?.call('Finalizing lead…');
      await _db.from('land_leads').update({
        'site_photo_url': sitePhotoUrl,
        'site_photo_urls': sitePhotoUrls,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', leadId);
    }

    final created = _fromRow({
      ...row,
      'site_photo_url': sitePhotoUrl,
      'site_photo_urls': sitePhotoUrls,
      'sub_division': lead.subDivision,
    });
    await AuditLogService.log(
      action: 'create',
      entityType: 'lead',
      entityId: created.leadId,
      field: 'lead',
      oldValue: '',
      newValue: created.ownerName,
      module: 'Lead',
      leadId: created.leadId,
      ownerName: created.ownerName,
      brokerName: created.brokerName,
      executiveName: created.createdByName,
    );
    return created;
  }

  /// Inserts a lead row, including `additional_owners` when the column
  /// exists. Falls back to inserting without it on databases that haven't
  /// had `supabase/land_lead_additional_owners.sql` applied yet.
  static Future<Map<String, dynamic>> _insertLandLead(
    Map<String, dynamic> base,
    List<OwnerContact> additionalOwners,
  ) async {
    try {
      return await _db
          .from('land_leads')
          .insert({
            ...base,
            'additional_owners':
                additionalOwners.map((o) => o.toJson()).toList(),
          })
          .select()
          .single();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' && e.message.contains('additional_owners')) {
        return await _db.from('land_leads').insert(base).select().single();
      }
      rethrow;
    }
  }

  /// Updates a lead row, including `additional_owners` when the column
  /// exists. Falls back to updating without it on databases that haven't
  /// had `supabase/land_lead_additional_owners.sql` applied yet.
  static Future<Map<String, dynamic>> _updateLandLead(
    String leadId,
    Map<String, dynamic> base,
    List<OwnerContact> additionalOwners,
  ) async {
    try {
      return await _db
          .from('land_leads')
          .update({
            ...base,
            'additional_owners':
                additionalOwners.map((o) => o.toJson()).toList(),
          })
          .eq('id', leadId)
          .select()
          .single();
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST204' && e.message.contains('additional_owners')) {
        return await _db
            .from('land_leads')
            .update(base)
            .eq('id', leadId)
            .select()
            .single();
      }
      rethrow;
    }
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

  /// Reassign a lead to an employee (by name). Since a lead's owning employee
  /// is tracked via created_by_name, this makes the lead appear on that
  /// employee's leads page.
  static Future<void> assignTo(String leadId, String employeeName) async {
    await _db.from('land_leads').update({
      'created_by_name': employeeName,
      // Management reassignment — show as "Assigned", not "Posted by".
      'created_by_role': 'management',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', leadId);
    final ctx = _auditContextFor(leadId);
    await AuditLogService.log(
      action: 'assign',
      entityType: 'lead',
      entityId: leadId,
      field: 'created_by_name',
      oldValue: '',
      newValue: employeeName,
      module: 'Lead',
      leadId: leadId,
      ownerName: ctx.owner,
      brokerName: ctx.broker,
      executiveName: employeeName,
    );
  }

  static Future<void> updateStatus(
    String leadId,
    LeadStatus status, {
    LeadStatus? previousStatus,
  }) async {
    final base = <String, dynamic>{
      'status': status.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    // Clearing drop reason/notes is best-effort: on a plain status change we
    // don't want a database that hasn't had lead_drop_reason.sql applied to
    // block the update. Retry without those columns if they're missing.
    final payload = <String, dynamic>{...base};
    if (status != LeadStatus.dropped) {
      payload['drop_reason'] = '';
      payload['drop_notes'] = '';
    }

    List rows;
    try {
      rows = await _db
          .from('land_leads')
          .update(payload)
          .eq('id', leadId)
          .select('id');
    } on PostgrestException catch (e) {
      final missingDropColumn = e.code == 'PGRST204' &&
          (e.message.contains('drop_notes') ||
              e.message.contains('drop_reason'));
      if (!missingDropColumn) rethrow;
      rows = await _db
          .from('land_leads')
          .update(base)
          .eq('id', leadId)
          .select('id');
    }
    if (rows.isEmpty) {
      throw Exception('Lead $leadId was not updated (not found or blocked)');
    }
    final ctx = _auditContextFor(leadId);
    await AuditLogService.log(
      action: 'update',
      entityType: 'lead',
      entityId: leadId,
      field: 'status',
      oldValue: previousStatus?.name ?? '',
      newValue: status.name,
      module: 'Lead',
      leadId: leadId,
      ownerName: ctx.owner,
      brokerName: ctx.broker,
      executiveName: ctx.executive,
    );
  }

  static Future<void> markDropped({
    required String leadId,
    required String reasonLabel,
    required String notes,
  }) async {
    await _db.from('land_leads').update({
      'status': LeadStatus.dropped.name,
      'drop_reason': reasonLabel.trim(),
      'drop_notes': notes.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', leadId);
    final ctx = _auditContextFor(leadId);
    await AuditLogService.log(
      action: 'update',
      entityType: 'lead',
      entityId: leadId,
      field: 'status',
      oldValue: '',
      newValue: 'dropped:${reasonLabel.trim()}',
      module: 'Lead',
      leadId: leadId,
      ownerName: ctx.owner,
      brokerName: ctx.broker,
      executiveName: ctx.executive,
    );
  }

  static Future<void> updateSurveySub(
      String leadId, String surveyNumber, String subDivision) async {
    await _db.from('land_leads').update({
      'survey_number': surveyNumber,
      'sub_division': subDivision,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', leadId);
  }

  static Future<void> updateLocation(
    String leadId, {
    required String location,
    required String village,
    required String taluk,
    required String district,
    required String pincode,
  }) async {
    await _db.from('land_leads').update({
      'location': location,
      'village': village,
      'taluk': taluk,
      'district': district,
      'pincode': pincode,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', leadId);
  }

  static Future<LandLead> update(
    LandLead lead, {
    List<Uint8List> sitePhotoBytes = const [],
    LeadSaveProgressCallback? onProgress,
  }) async {
    onProgress?.call('Saving lead details…');
    var sitePhotoUrls = List<String>.from(lead.sitePhotoUrls);
    var sitePhotoUrl = sitePhotoUrls.isNotEmpty ? sitePhotoUrls.first : '';

    final newPhotos =
        sitePhotoBytes.where((b) => b.isNotEmpty).take(4).toList();
    final slotsLeft = 4 - sitePhotoUrls.length;
    if (newPhotos.isNotEmpty && slotsLeft > 0) {
      final uploadCount = newPhotos.length.clamp(0, slotsLeft);
      for (var i = 0; i < newPhotos.length && sitePhotoUrls.length < 4; i++) {
        onProgress?.call('Uploading photo ${i + 1} of $uploadCount…');
        final url = await _uploadSitePhoto(
          lead.leadId,
          newPhotos[i],
          index: sitePhotoUrls.length + 1,
        );
        sitePhotoUrls.add(url);
      }
      sitePhotoUrl = sitePhotoUrls.first;
      onProgress?.call('Finalizing lead…');
    }

    final row = await _updateLandLead(
      lead.leadId,
      {
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
        'broker_name': lead.brokerName,
        'broker_contact': lead.brokerContact,
        'land_type': lead.landType.name,
        'road_width': lead.roadWidth,
        'access_details': lead.accessDetails,
        'notes': lead.notes,
        'status': lead.status.name,
        'site_photo_url': sitePhotoUrl,
        'site_photo_urls': sitePhotoUrls,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      lead.additionalOwners,
    );

    final updated = _fromRow({
      ...row,
      'site_photo_url': sitePhotoUrl,
      'site_photo_urls': sitePhotoUrls,
    });
    await AuditLogService.log(
      action: 'update',
      entityType: 'lead',
      entityId: updated.leadId,
      field: 'lead',
      oldValue: '',
      newValue: updated.ownerName,
      module: 'Lead',
      leadId: updated.leadId,
      ownerName: updated.ownerName,
      brokerName: updated.brokerName,
      executiveName: updated.createdByName,
    );
    return updated;
  }

  static Future<void> delete(String leadId) async {
    final ctx = _auditContextFor(leadId);
    await _db.from('land_leads').delete().eq('id', leadId);
    await AuditLogService.log(
      action: 'delete',
      entityType: 'lead',
      entityId: leadId,
      field: 'lead',
      oldValue: leadId,
      newValue: '',
      module: 'Lead',
      leadId: leadId,
      ownerName: ctx.owner,
      brokerName: ctx.broker,
      executiveName: ctx.executive,
    );
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

    final additionalOwnersRaw = r['additional_owners'];
    final additionalOwners = additionalOwnersRaw is List
        ? additionalOwnersRaw
            .whereType<Map>()
            .map((m) => OwnerContact.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : <OwnerContact>[];

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
      additionalOwners: additionalOwners,
      brokerName: r['broker_name'] as String? ?? '',
      brokerContact: r['broker_contact'] as String? ?? '',
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
      createdByRole: r['created_by_role'] as String? ?? '',
      status: parseLeadStatus(r['status'] as String?),
      dropReason: r['drop_reason'] as String? ?? '',
      dropNotes: r['drop_notes'] as String? ?? '',
    );
  }
}
