import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

enum FieldCalendarKind { siteVisit, meeting, survey }

extension FieldCalendarKindX on FieldCalendarKind {
  String get label => switch (this) {
        FieldCalendarKind.siteVisit => 'Site Visit',
        FieldCalendarKind.meeting => 'Meeting',
        FieldCalendarKind.survey => 'Survey',
      };

  String get dbValue => name;

  static FieldCalendarKind fromDb(String? raw) => FieldCalendarKind.values
      .firstWhere((k) => k.name == raw, orElse: () => FieldCalendarKind.meeting);
}

class FieldCalendarEvent {
  final String id;
  final FieldCalendarKind kind;
  final String leadId;
  final String title;
  final DateTime scheduledAt;
  final String notes;
  final bool reminderEnabled;
  final int remindMinutesBefore;
  final String createdByName;
  bool completed;

  FieldCalendarEvent({
    required this.id,
    required this.kind,
    required this.leadId,
    required this.title,
    required this.scheduledAt,
    this.notes = '',
    this.reminderEnabled = true,
    this.remindMinutesBefore = 60,
    this.createdByName = '',
    this.completed = false,
  });

  DateTime get remindAt =>
      scheduledAt.subtract(Duration(minutes: remindMinutesBefore));

  /// True once the reminder time has arrived and it hasn't been actioned yet.
  /// Deliberately has no upper-bound cutoff — a reminder stays due (and keeps
  /// surfacing in the Notification Center) until it's completed, so it can't
  /// be silently missed just because nobody opened the app in time.
  bool get isDue =>
      reminderEnabled && !completed && DateTime.now().isAfter(remindAt);

  /// Near-term highlight for the calendar UI (due within the next 2 hours of
  /// the scheduled time, or already started).
  bool get isDueSoon {
    final now = DateTime.now();
    return reminderEnabled &&
        !completed &&
        now.isAfter(remindAt) &&
        now.isBefore(scheduledAt.add(const Duration(hours: 2)));
  }

  factory FieldCalendarEvent.fromJson(Map<String, dynamic> j) =>
      FieldCalendarEvent(
        id: j['id'] as String,
        kind: FieldCalendarKindX.fromDb(j['kind'] as String?),
        leadId: j['lead_id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        scheduledAt: DateTime.parse(j['scheduled_at'] as String).toLocal(),
        notes: j['notes'] as String? ?? '',
        reminderEnabled: j['reminder_enabled'] as bool? ?? true,
        remindMinutesBefore: j['remind_minutes'] as int? ?? 60,
        createdByName: j['created_by_name'] as String? ?? '',
        completed: j['completed'] as bool? ?? false,
      );
}

/// Field Calendar events (site visits, meetings, survey dates) with
/// reminders — backed by Supabase so events and their reminders are visible
/// across every device/session, not just the one that created them.
class FieldCalendarService {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<FieldCalendarEvent>> getAll() async {
    final rows = await _db
        .from('field_calendar_events')
        .select()
        .order('scheduled_at', ascending: true);
    return (rows as List)
        .map((r) => FieldCalendarEvent.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  static Future<FieldCalendarEvent> add({
    required FieldCalendarKind kind,
    required String leadId,
    required String title,
    required DateTime scheduledAt,
    String notes = '',
    bool reminderEnabled = true,
    int remindMinutesBefore = 60,
  }) async {
    final createdByName = AuthService.instance.currentUser?.fullName ?? '';
    final row = await _db
        .from('field_calendar_events')
        .insert({
          'kind': kind.dbValue,
          'lead_id': leadId,
          'title': title,
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'notes': notes,
          'reminder_enabled': reminderEnabled,
          'remind_minutes': remindMinutesBefore,
          if (createdByName.isNotEmpty) 'created_by_name': createdByName,
        })
        .select()
        .single();
    return FieldCalendarEvent.fromJson(row);
  }

  static Future<void> markCompleted(String id, {bool completed = true}) async {
    await _db
        .from('field_calendar_events')
        .update({'completed': completed}).eq('id', id);
  }

  static Future<void> remove(String id) async {
    await _db.from('field_calendar_events').delete().eq('id', id);
  }

  /// Reminders that are due and not yet completed, across all devices/users.
  static Future<List<FieldCalendarEvent>> dueReminders() async {
    final all = await getAll();
    return all.where((e) => e.isDue).toList();
  }
}
