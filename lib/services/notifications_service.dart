import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

class NotificationsService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Newest notifications for an audience ('management' | 'employee').
  static Future<List<AppNotification>> getAll({
    String audience = 'management',
    int limit = 50,
  }) async {
    final rows = await _db
        .from('notifications')
        .select()
        .eq('audience', audience)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => AppNotification.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Insert a notification for an audience ('management' | 'employee').
  /// Fire-and-forget from the UI; failures are swallowed by the caller.
  static Future<void> create({
    required String audience,
    required String title,
    String message = '',
    String type = 'alert',
    String? leadId,
    String? referenceId,
  }) async {
    await _db.from('notifications').insert({
      'audience': audience,
      'type': type,
      'title': title,
      'message': message,
      if (leadId != null) 'lead_id': leadId,
      if (referenceId != null) 'reference_id': referenceId,
    });
  }

  static Future<void> markRead(String id) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', id);
  }

  static Future<void> markAllRead({String audience = 'management'}) async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('audience', audience)
        .eq('is_read', false);
  }

  /// Live channel that fires [onChange] on any insert/update/delete for the
  /// audience. Call [RealtimeChannel.unsubscribe] to stop listening.
  static RealtimeChannel subscribe({
    String audience = 'management',
    required void Function() onChange,
  }) {
    return _db
        .channel('notifications:$audience')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'audience',
            value: audience,
          ),
          callback: (_) => onChange(),
        )
        .subscribe();
  }
}
