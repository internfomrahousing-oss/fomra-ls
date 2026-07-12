import '../models/app_notification.dart';

extension NotificationTypeX on NotificationType {
  String get label => switch (this) {
        NotificationType.lead => 'Lead',
        NotificationType.assignedLead => 'Assigned Lead',
        NotificationType.pendingLead => 'Pending Lead',
        NotificationType.pendingApproval => 'Pending Approval',
        NotificationType.slaBreach => 'SLA Breach',
        NotificationType.overdueTask => 'Overdue Task',
        NotificationType.reminder => 'Reminder',
        NotificationType.task => 'Task',
        NotificationType.document => 'Document',
        NotificationType.alert => 'Alert',
        NotificationType.verification => 'Verification',
        NotificationType.siteVisit => 'Site Visit',
      };

  String get dbValue => switch (this) {
        NotificationType.lead => 'lead',
        NotificationType.assignedLead => 'assigned_lead',
        NotificationType.pendingLead => 'pending_lead',
        NotificationType.pendingApproval => 'pending_approval',
        NotificationType.slaBreach => 'sla_breach',
        NotificationType.overdueTask => 'overdue_task',
        NotificationType.reminder => 'reminder',
        NotificationType.task => 'task',
        NotificationType.document => 'document',
        NotificationType.alert => 'alert',
        NotificationType.verification => 'verification',
        NotificationType.siteVisit => 'site_visit',
      };
}
