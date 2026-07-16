import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../theme/app_theme.dart';

extension NotificationTypeX on NotificationType {
  /// Accent used wherever a notification is rendered — bell dropdown, toast,
  /// and the Notification Center — so a type reads the same everywhere.
  Color get color => switch (this) {
        NotificationType.lead ||
        NotificationType.assignedLead =>
          AppColors.info,
        NotificationType.pendingLead => AppColors.warning,
        NotificationType.pendingApproval => AppColors.secondary,
        NotificationType.slaBreach ||
        NotificationType.overdueTask ||
        NotificationType.alert =>
          AppColors.error,
        NotificationType.reminder || NotificationType.siteVisit =>
          AppColors.primary,
        NotificationType.task => AppColors.warning,
        NotificationType.document => AppColors.success,
        NotificationType.verification => AppColors.secondary,
        NotificationType.signed => AppColors.success,
      };

  IconData get icon => switch (this) {
        NotificationType.lead ||
        NotificationType.assignedLead =>
          Icons.person_add_alt_1_outlined,
        NotificationType.pendingLead => Icons.hourglass_top_rounded,
        NotificationType.pendingApproval => Icons.approval_outlined,
        NotificationType.slaBreach => Icons.timer_off_outlined,
        NotificationType.overdueTask => Icons.warning_amber_rounded,
        NotificationType.reminder => Icons.notifications_active_outlined,
        NotificationType.task => Icons.task_alt,
        NotificationType.document => Icons.description,
        NotificationType.alert => Icons.warning_amber,
        NotificationType.verification => Icons.verified,
        NotificationType.siteVisit => Icons.apartment_outlined,
        NotificationType.signed => Icons.check_circle,
      };

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
        NotificationType.signed => 'Signed',
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
        NotificationType.signed => 'signed',
      };
}
