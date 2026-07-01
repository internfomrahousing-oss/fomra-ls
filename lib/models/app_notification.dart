class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  final NotificationType type;
  final String audience;
  final String? leadId;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.type,
    this.audience = 'management',
    this.leadId,
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
        isRead: r['is_read'] as bool? ?? false,
      );

  static NotificationType _typeFromName(String? name) =>
      NotificationType.values.firstWhere(
        (t) => t.name == name,
        orElse: () => NotificationType.alert,
      );
}

enum NotificationType { lead, task, document, alert, verification }
