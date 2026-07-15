import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import 'auth_service.dart';

class NotificationsService {
  static SupabaseClient get _db => Supabase.instance.client;

  /// Audiences the signed-in user should see: their shared role audience plus
  /// their personal (email) audience, which approval routing uses to address a
  /// specific Reporting Manager / Head / Executive.
  static List<String> audiencesForCurrentUser() {
    if (AuthService.instance.isManagement) return const ['management'];
    final email =
        (AuthService.instance.currentUser?.email ?? '').trim().toLowerCase();
    return email.isEmpty ? const ['employee'] : ['employee', email];
  }

  /// Newest notifications addressed to the signed-in user (shared + personal).
  static Future<List<AppNotification>> getAllForCurrentUser({
    int limit = 100,
  }) async {
    final rows = await _db
        .from('notifications')
        .select()
        .inFilter('audience', audiencesForCurrentUser())
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => AppNotification.fromRow(r as Map<String, dynamic>))
        .toList();
  }

  /// Marks every unread notification addressed to the signed-in user as read.
  static Future<void> markAllReadForCurrentUser() async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .inFilter('audience', audiencesForCurrentUser())
        .eq('is_read', false);
  }

  /// Newest notifications for an audience ('management' | 'employee').
  static Future<List<AppNotification>> getAll({
    String audience = 'management',
    int limit = 100,
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
    await createAndReturn(
      audience: audience,
      title: title,
      message: message,
      type: type,
      leadId: leadId,
      referenceId: referenceId,
    );
  }

  static Future<AppNotification> createAndReturn({
    required String audience,
    required String title,
    String message = '',
    String type = 'alert',
    String? leadId,
    String? referenceId,
  }) async {
    final row = await _db.from('notifications').insert({
      'audience': audience,
      'type': type,
      'title': title,
      'message': message,
      if (leadId != null) 'lead_id': leadId,
      if (referenceId != null) 'reference_id': referenceId,
    }).select().single();
    return AppNotification.fromRow(row);
  }

  static Future<void> markRead(String id) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', id);
  }

  /// Re-addresses an existing notification to a different audience (used by the
  /// drop-approval chain, where the notification IS the pending request, so
  /// moving it up a level means handing it to the next approver).
  static Future<void> reroute({
    required String id,
    required String audience,
    String? message,
  }) async {
    await _db.from('notifications').update({
      'audience': audience,
      if (message != null) 'message': message,
      'is_read': false,
    }).eq('id', id);
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
