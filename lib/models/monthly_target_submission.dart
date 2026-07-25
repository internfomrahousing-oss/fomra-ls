import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The four target categories an employee can propose for a month.
enum TargetCategory { leads, siteVisits, meetings, brokers }

extension TargetCategoryX on TargetCategory {
  /// Stable storage key (also the JSON key in submitted/approved values).
  String get key => switch (this) {
        TargetCategory.leads => 'leads',
        TargetCategory.siteVisits => 'site_visits',
        TargetCategory.meetings => 'meetings',
        TargetCategory.brokers => 'brokers',
      };

  String get label => switch (this) {
        TargetCategory.leads => 'Leads',
        TargetCategory.siteVisits => 'Site Visits',
        TargetCategory.meetings => 'Meetings',
        TargetCategory.brokers => 'Brokers',
      };

  IconData get icon => switch (this) {
        TargetCategory.leads => Icons.person_add_alt_1_outlined,
        TargetCategory.siteVisits => Icons.location_on_outlined,
        TargetCategory.meetings => Icons.groups_outlined,
        TargetCategory.brokers => Icons.handshake_outlined,
      };

  static TargetCategory? fromKey(String key) {
    for (final c in TargetCategory.values) {
      if (c.key == key) return c;
    }
    return null;
  }
}

enum TargetSubmissionStatus { pending, approved, rejected }

extension TargetSubmissionStatusX on TargetSubmissionStatus {
  String get dbValue => name;

  String get label => switch (this) {
        TargetSubmissionStatus.pending => 'Pending Approval',
        TargetSubmissionStatus.approved => 'Approved',
        TargetSubmissionStatus.rejected => 'Rejected',
      };

  Color get color => switch (this) {
        TargetSubmissionStatus.pending => AppColors.warning,
        TargetSubmissionStatus.approved => AppColors.success,
        TargetSubmissionStatus.rejected => AppColors.error,
      };

  static TargetSubmissionStatus parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'approved':
        return TargetSubmissionStatus.approved;
      case 'rejected':
        return TargetSubmissionStatus.rejected;
      default:
        return TargetSubmissionStatus.pending;
    }
  }
}

/// One employee's proposed monthly targets and its approval state, with the
/// full audit fields (submitted / edited / approved by & when).
class MonthlyTargetSubmission {
  final String id;
  final String period; // 'YYYY-MM'
  final String employeeEmail;
  final String employeeName;
  final String employeeCode;
  final String department;
  final String designation;

  /// Category key → value, only for categories the employee selected.
  final Map<String, int> submittedValues;

  /// Category key → value that management approved (may differ if edited).
  final Map<String, int>? approvedValues;

  final TargetSubmissionStatus status;
  final bool managementEdited;
  final String note;

  final String submittedBy;
  final DateTime submittedAt;
  final String editedBy;
  final DateTime? editedAt;
  final String approvedBy;
  final DateTime? approvedAt;

  const MonthlyTargetSubmission({
    required this.id,
    required this.period,
    required this.employeeEmail,
    required this.employeeName,
    required this.submittedValues,
    required this.status,
    required this.submittedAt,
    this.employeeCode = '',
    this.department = '',
    this.designation = '',
    this.approvedValues,
    this.managementEdited = false,
    this.note = '',
    this.submittedBy = '',
    this.editedBy = '',
    this.editedAt,
    this.approvedBy = '',
    this.approvedAt,
  });

  bool get isPending => status == TargetSubmissionStatus.pending;
  bool get isApproved => status == TargetSubmissionStatus.approved;
  bool get isRejected => status == TargetSubmissionStatus.rejected;

  /// The values in force: approved when present, otherwise what was submitted.
  Map<String, int> get effectiveValues => approvedValues ?? submittedValues;

  int get year => int.tryParse(period.split('-').first) ?? 0;
  int get month => int.tryParse(period.split('-').last) ?? 1;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static String monthName(int month) =>
      (month >= 1 && month <= 12) ? _monthNames[month - 1] : '';

  static String periodOf(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  String get monthLabel => '${monthName(month)} $year';

  static Map<String, int> _intMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, int>{};
    raw.forEach((k, v) {
      final n = (v as num?)?.toInt();
      if (n != null) out[k.toString()] = n;
    });
    return out;
  }

  static DateTime? _date(dynamic raw) =>
      raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();

  factory MonthlyTargetSubmission.fromJson(Map<String, dynamic> j) {
    return MonthlyTargetSubmission(
      id: j['id'] as String,
      period: (j['period'] as String? ?? '').trim(),
      employeeEmail: (j['employee_email'] as String? ?? '').trim().toLowerCase(),
      employeeName: j['employee_name'] as String? ?? '',
      employeeCode: j['employee_code'] as String? ?? '',
      department: j['department'] as String? ?? '',
      designation: j['designation'] as String? ?? '',
      submittedValues: _intMap(j['submitted_values']),
      approvedValues:
          j['approved_values'] == null ? null : _intMap(j['approved_values']),
      status: TargetSubmissionStatusX.parse(j['status'] as String?),
      managementEdited: j['management_edited'] == true,
      note: j['note'] as String? ?? '',
      submittedBy: j['submitted_by'] as String? ?? '',
      submittedAt: _date(j['submitted_at']) ?? DateTime.now(),
      editedBy: j['edited_by'] as String? ?? '',
      editedAt: _date(j['edited_at']),
      approvedBy: j['approved_by'] as String? ?? '',
      approvedAt: _date(j['approved_at']),
    );
  }
}
