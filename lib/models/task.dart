class Task {
  final String id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final DateTime? dueDate;
  final String? leadId;
  final String? leadName;
  final String? assignedTo;
  final String? assignedToName;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  static const List<String> statuses = ['pending', 'in_progress', 'completed', 'cancelled'];
  static const List<String> priorities = ['low', 'medium', 'high', 'urgent'];

  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    this.dueDate,
    this.leadId,
    this.leadName,
    this.assignedTo,
    this.assignedToName,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String?,
        status: j['status'] as String? ?? 'pending',
        priority: j['priority'] as String? ?? 'medium',
        dueDate: j['due_date'] != null ? DateTime.parse(j['due_date'] as String) : null,
        leadId: j['lead_id'] as String?,
        leadName: j['lead_name'] as String?,
        assignedTo: j['assigned_to'] as String?,
        assignedToName: j['assigned_to_name'] as String?,
        createdBy: j['created_by'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'status': status,
        'priority': priority,
        'due_date': dueDate?.toIso8601String(),
        'lead_id': leadId,
        'assigned_to': assignedTo,
      };
}
