import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/task.dart';

class TasksService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<Task>> getAll({
    String? status,
    String? priority,
    String? leadId,
    String? assignedTo,
  }) async {
    var query = _db.from('tasks').select(
        '*, lead:leads(name), assigned_profile:profiles!assigned_to(full_name)');

    if (status != null)     query = query.eq('status', status);
    if (priority != null)   query = query.eq('priority', priority);
    if (leadId != null)     query = query.eq('lead_id', leadId);
    if (assignedTo != null) query = query.eq('assigned_to', assignedTo);

    final rows = await query.order('created_at', ascending: false);
    return (rows as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
  }

  static Future<Task> getById(String id) async {
    final row = await _db
        .from('tasks')
        .select(
            '*, lead:leads(name), assigned_profile:profiles!assigned_to(full_name)')
        .eq('id', id)
        .single();
    return _fromRow(row);
  }

  static Future<Task> create(Map<String, dynamic> body) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final row = await _db
        .from('tasks')
        .insert({...body, if (userId != null) 'created_by': userId})
        .select()
        .single();
    return Task.fromJson(row);
  }

  static Future<Task> update(String id, Map<String, dynamic> body) async {
    final row = await _db
        .from('tasks')
        .update({...body, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
    return Task.fromJson(row);
  }

  static Future<void> delete(String id) async {
    await _db.from('tasks').delete().eq('id', id);
  }

  static Task _fromRow(Map<String, dynamic> r) {
    final lead    = r['lead'] as Map<String, dynamic>?;
    final profile = r['assigned_profile'] as Map<String, dynamic>?;
    return Task.fromJson({
      ...r,
      'lead_name':        lead?['name'],
      'assigned_to_name': profile?['full_name'],
    });
  }
}
