import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/land_lead_legal_document.dart';
import 'auth_service.dart';

class LandLeadLegalService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const _bucket = 'land-lead-legal-docs';

  static Future<List<LandLeadLegalDocument>> getDocuments(String leadId) async {
    final rows = await _db
        .from('land_lead_legal_documents')
        .select()
        .eq('lead_id', leadId)
        .order('verified_at', ascending: false);
    return (rows as List)
        .map((r) => LandLeadLegalDocument.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<String> getReferenceNotes(String leadId) async {
    final row = await _db
        .from('legal_verifications')
        .select('reference_notes')
        .eq('lead_id', leadId)
        .maybeSingle();
    return row?['reference_notes'] as String? ?? '';
  }

  static Future<void> saveReferenceNotes(String leadId, String notes) async {
    await _db.from('legal_verifications').upsert({
      'lead_id': leadId,
      'reference_notes': notes.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<LandLeadLegalDocument> uploadDocument({
    required String leadId,
    required Uint8List bytes,
    required String fileName,
    DateTime? verifiedAt,
  }) async {
    final userId = _db.auth.currentUser?.id;
    final loggedByName = AuthService.instance.currentUser?.fullName ?? '';
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-() ]'), '_');
    final path =
        '$leadId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await _db.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(safeName),
            upsert: true,
          ),
        );

    final fileUrl = _db.storage.from(_bucket).getPublicUrl(path);
    final verified = (verifiedAt ?? DateTime.now()).toUtc();

    final row = await _db
        .from('land_lead_legal_documents')
        .insert({
          'lead_id': leadId,
          'file_name': fileName,
          'file_url': fileUrl,
          'verified_at': verified.toIso8601String(),
          if (loggedByName.isNotEmpty) 'logged_by_name': loggedByName,
          if (userId != null) 'logged_by': userId,
        })
        .select()
        .single();

    return LandLeadLegalDocument.fromJson(row);
  }

  static String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }
}
