import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A follow-up reminder set on a lead. Stored status is pending/completed;
/// "missed" is derived (still pending after its scheduled time passed).
enum FollowUpStatus { pending, completed, missed }

extension FollowUpStatusX on FollowUpStatus {
  String get label => switch (this) {
        FollowUpStatus.pending => 'Pending',
        FollowUpStatus.completed => 'Completed',
        FollowUpStatus.missed => 'Missed',
      };

  Color get color => switch (this) {
        FollowUpStatus.pending => AppColors.warning,
        FollowUpStatus.completed => AppColors.success,
        FollowUpStatus.missed => AppColors.error,
      };
}

class LeadFollowUp {
  final String id;
  final String leadId;
  final String title;
  final String notes;
  final DateTime remindAt;

  /// Stored status: 'pending' or 'completed'.
  final bool completed;

  final String createdBy;
  final String createdByEmail;
  final DateTime createdAt;
  final DateTime? completedAt;

  const LeadFollowUp({
    required this.id,
    required this.leadId,
    required this.title,
    required this.remindAt,
    required this.createdAt,
    this.notes = '',
    this.completed = false,
    this.createdBy = '',
    this.createdByEmail = '',
    this.completedAt,
  });

  /// Pending / Completed / Missed, derived against [now].
  FollowUpStatus statusAt(DateTime now) {
    if (completed) return FollowUpStatus.completed;
    if (remindAt.isBefore(now)) return FollowUpStatus.missed;
    return FollowUpStatus.pending;
  }

  FollowUpStatus get status => statusAt(DateTime.now());

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// e.g. "24 Jul 2026 • 10:30 AM".
  static String formatDateTime(DateTime d) {
    final l = d.toLocal();
    final h12 = l.hour % 12 == 0 ? 12 : l.hour % 12;
    final ampm = l.hour < 12 ? 'AM' : 'PM';
    final mm = l.minute.toString().padLeft(2, '0');
    return '${l.day} ${_months[l.month - 1]} ${l.year} • $h12:$mm $ampm';
  }

  static String formatDate(DateTime d) {
    final l = d.toLocal();
    return '${l.day} ${_months[l.month - 1]} ${l.year}';
  }

  String get scheduledLabel => formatDateTime(remindAt);
  String get createdLabel => formatDate(createdAt);

  factory LeadFollowUp.fromJson(Map<String, dynamic> j) => LeadFollowUp(
        id: j['id'].toString(),
        leadId: (j['lead_id'] as String? ?? '').trim(),
        title: j['title'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        remindAt:
            DateTime.tryParse(j['remind_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        completed: (j['status'] as String? ?? 'pending') == 'completed',
        createdBy: j['created_by'] as String? ?? '',
        createdByEmail:
            (j['created_by_email'] as String? ?? '').trim().toLowerCase(),
        createdAt:
            DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        completedAt:
            DateTime.tryParse(j['completed_at'] as String? ?? '')?.toLocal(),
      );
}
