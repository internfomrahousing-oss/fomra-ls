import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/site_visit.dart';

class SiteVisitsService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<SiteVisit>> getAll({
    String? status,
    String? leadId,
    String? agentId,
  }) async {
    var query = _db.from('site_visits').select(
        '*, lead:leads(name, phone), agent:profiles!agent_id(full_name)');

    if (status != null)  query = query.eq('status', status);
    if (leadId != null)  query = query.eq('lead_id', leadId);
    if (agentId != null) query = query.eq('agent_id', agentId);

    final rows = await query.order('scheduled_at', ascending: false);
    return (rows as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
  }

  static Future<SiteVisit> getById(String id) async {
    final row = await _db
        .from('site_visits')
        .select('*, lead:leads(name, phone), agent:profiles!agent_id(full_name)')
        .eq('id', id)
        .single();
    return _fromRow(row);
  }

  static Future<SiteVisit> create(Map<String, dynamic> body) async {
    final row = await _db
        .from('site_visits')
        .insert(body)
        .select()
        .single();
    return SiteVisit.fromJson(row);
  }

  static Future<SiteVisit> update(String id, Map<String, dynamic> body) async {
    final row = await _db
        .from('site_visits')
        .update({...body, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return SiteVisit.fromJson(row);
  }

  static Future<void> delete(String id) async {
    await _db.from('site_visits').delete().eq('id', id);
  }

  static SiteVisit _fromRow(Map<String, dynamic> r) {
    final lead  = r['lead']  as Map<String, dynamic>?;
    final agent = r['agent'] as Map<String, dynamic>?;
    return SiteVisit.fromJson({
      ...r,
      'lead_name':  lead?['name'],
      'lead_phone': lead?['phone'],
      'agent_name': agent?['full_name'],
    });
  }
}
