class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final NotificationType type;
  final String audience;
  final String? leadId;
  final String? referenceId;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    this.audience = 'management',
    this.leadId,
    this.referenceId,
    this.isRead = false,
  });

  factory AppNotification.fromRow(Map<String, dynamic> r) => AppNotification(
        id: r['id'].toString(),
        title: r['title'] as String? ?? '',
        message: r['message'] as String? ?? '',
        time: DateTime.parse(r['created_at'] as String).toLocal(),
        type: _typeFromName(r['type'] as String?),
        audience: r['audience'] as String? ?? 'management',
        leadId: r['lead_id'] as String?,
        referenceId: r['reference_id'] as String?,
        isRead: r['is_read'] as bool? ?? false,
      );

  static NotificationType _typeFromName(String? name) => switch (name) {
        'site_visit' => NotificationType.siteVisit,
        'lead' => NotificationType.lead,
        'assigned_lead' => NotificationType.assignedLead,
        'pending_lead' => NotificationType.pendingLead,
        'pending_approval' => NotificationType.pendingApproval,
        'sla_breach' => NotificationType.slaBreach,
        'overdue_task' => NotificationType.overdueTask,
        'reminder' => NotificationType.reminder,
        'task' => NotificationType.task,
        'document' => NotificationType.document,
        'verification' => NotificationType.verification,
        _ => NotificationType.alert,
      };
}

enum NotificationType {
  lead,
  assignedLead,
  pendingLead,
  pendingApproval,
  slaBreach,
  overdueTask,
  reminder,
  task,
  document,
  alert,
  verification,
  siteVisit,
}
