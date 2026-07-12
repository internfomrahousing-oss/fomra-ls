import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum FieldCalendarKind { siteVisit, meeting, survey }

extension FieldCalendarKindX on FieldCalendarKind {
  String get label => switch (this) {
        FieldCalendarKind.siteVisit => 'Site Visit',
        FieldCalendarKind.meeting => 'Meeting',
        FieldCalendarKind.survey => 'Survey',
      };
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
    this.completed = false,
  });

  DateTime get remindAt =>
      scheduledAt.subtract(Duration(minutes: remindMinutesBefore));

  bool get isDueSoon {
    final now = DateTime.now();
    return reminderEnabled &&
        !completed &&
        now.isAfter(remindAt) &&
        now.isBefore(scheduledAt.add(const Duration(hours: 2)));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'lead_id': leadId,
        'title': title,
        'scheduled_at': scheduledAt.toIso8601String(),
        'notes': notes,
        'reminder_enabled': reminderEnabled,
        'remind_minutes': remindMinutesBefore,
        'completed': completed,
      };

  factory FieldCalendarEvent.fromJson(Map<String, dynamic> j) =>
      FieldCalendarEvent(
        id: j['id'] as String,
        kind: FieldCalendarKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => FieldCalendarKind.meeting,
        ),
        leadId: j['lead_id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        scheduledAt: DateTime.tryParse(j['scheduled_at'] as String? ?? '') ??
            DateTime.now(),
        notes: j['notes'] as String? ?? '',
        reminderEnabled: j['reminder_enabled'] as bool? ?? true,
        remindMinutesBefore: j['remind_minutes'] as int? ?? 60,
        completed: j['completed'] as bool? ?? false,
      );
}

/// Local calendar for site visits, meetings, and survey dates + reminders.
class FieldCalendarService {
  static const _key = 'fomra_field_calendar_v1';

  static Future<List<FieldCalendarEvent>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    final list = raw
        .map((s) =>
            FieldCalendarEvent.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return list;
  }

  static Future<void> _save(List<FieldCalendarEvent> events) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      events.map((e) => jsonEncode(e.toJson())).toList(),
    );
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
    final event = FieldCalendarEvent(
      id: 'cal_${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      leadId: leadId,
      title: title,
      scheduledAt: scheduledAt,
      notes: notes,
      reminderEnabled: reminderEnabled,
      remindMinutesBefore: remindMinutesBefore,
    );
    final all = await getAll();
    all.add(event);
    await _save(all);
    return event;
  }

  static Future<void> markCompleted(String id, {bool completed = true}) async {
    final all = await getAll();
    for (final e in all) {
      if (e.id == id) e.completed = completed;
    }
    await _save(all);
  }

  static Future<void> remove(String id) async {
    final all = await getAll();
    all.removeWhere((e) => e.id == id);
    await _save(all);
  }

  static Future<List<FieldCalendarEvent>> dueReminders() async {
    final all = await getAll();
    return all.where((e) => e.isDueSoon).toList();
  }
}
