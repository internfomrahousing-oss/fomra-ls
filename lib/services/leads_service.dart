import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lead.dart';

class LeadsService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<Lead>> getAll({
    String? status,
    String? source,
    String? assignedTo,
    String? search,
  }) async {
    var query = _db
        .from('leads')
        .select('*, assigned_profile:profiles!assigned_to(full_name)');

    if (status != null)     query = query.eq('status', status);
    if (source != null)     query = query.eq('source', source);
    if (assignedTo != null) query = query.eq('assigned_to', assignedTo);
    if (search != null && search.isNotEmpty) {
      query = query.or(
          'name.ilike.%$search%,email.ilike.%$search%,phone.ilike.%$search%');
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
  }

  static Future<Lead> getById(String id) async {
    final row = await _db
        .from('leads')
        .select('*, assigned_profile:profiles!assigned_to(full_name)')
        .eq('id', id)
        .single();
    return _fromRow(row);
  }

  static Future<Lead> create(Map<String, dynamic> body) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final row = await _db
        .from('leads')
        .insert({...body, if (userId != null) 'created_by': userId})
        .select()
        .single();
    return Lead.fromJson(row);
  }

  static Future<Lead> update(String id, Map<String, dynamic> body) async {
    final row = await _db
        .from('leads')
        .update({...body, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return Lead.fromJson(row);
  }

  static Future<void> delete(String id) async {
    await _db.from('leads').delete().eq('id', id);
  }

  static Lead _fromRow(Map<String, dynamic> r) {
    final profile = r['assigned_profile'] as Map<String, dynamic>?;
    return Lead.fromJson({...r, 'assigned_to_name': profile?['full_name']});
  }
}
