import 'package:supabase_flutter/supabase_flutter.dart';

class LegalVerificationService {
  static final _db = Supabase.instance.client;

  /// Returns all legal verification rows as raw maps (keyed by lead_id).
  static Future<List<Map<String, dynamic>>> getAll() async {
    final rows = await _db.from('legal_verifications').select();
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// Upserts legal data for a given lead. [data] should contain only the
  /// columns being updated — lead_id and updated_at are added automatically.
  static Future<void> save(String leadId, Map<String, dynamic> data) async {
    await _db.from('legal_verifications').upsert({
      'lead_id': leadId,
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
