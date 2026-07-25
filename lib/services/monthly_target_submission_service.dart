import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/monthly_target_submission.dart';
import 'auth_service.dart';
import 'notifications_service.dart';

/// Employee-submitted monthly targets and their management approval.
///
/// Degrades gracefully when the `monthly_target_submissions` table is missing:
/// reads return nothing and writes throw, so a workspace that hasn't run the
/// migration simply shows no submissions rather than breaking.
class MonthlyTargetSubmissionService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const _table = 'monthly_target_submissions';

  /// Only approved targets feed dashboards / KPIs / reports — pending and
  /// rejected proposals never count. Callers use [approvedForEmployee].
  static String _now() => DateTime.now().toUtc().toIso8601String();
  static String get _actorName =>
      AuthService.instance.currentUser?.fullName ?? 'User';

  /// Every submission for one employee, newest month first (their history).
  static Future<List<MonthlyTargetSubmission>> getForEmployee(
      String email) async {
    try {
      final rows = await _db
          .from(_table)
          .select()
          .eq('employee_email', email.trim().toLowerCase())
          .order('period', ascending: false);
      return (rows as List)
          .map((r) =>
              MonthlyTargetSubmission.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// All pending submissions awaiting management, newest first.
  static Future<List<MonthlyTargetSubmission>> getPending() async {
    try {
      final rows = await _db
          .from(_table)
          .select()
          .eq('status', 'pending')
          .order('submitted_at', ascending: false);
      return (rows as List)
          .map((r) =>
              MonthlyTargetSubmission.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// The approved submission an employee is measured against for a month, if any.
  /// Only approved values are ever returned — the rule for dashboards/KPIs.
  static Future<MonthlyTargetSubmission?> approvedForEmployee(
    String email, {
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    try {
      final row = await _db
          .from(_table)
          .select()
          .eq('employee_email', email.trim().toLowerCase())
          .eq('period', MonthlyTargetSubmission.periodOf(clock.year, clock.month))
          .eq('status', 'approved')
          .maybeSingle();
      if (row == null) return null;
      return MonthlyTargetSubmission.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  static Future<List<dynamic>> _existingHistory(
      String period, String email) async {
    try {
      final row = await _db
          .from(_table)
          .select('status_history')
          .eq('period', period)
          .eq('employee_email', email)
          .maybeSingle();
      final h = row?['status_history'];
      return h is List ? List<dynamic>.from(h) : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  /// Employee submits (or resubmits after a rejection) their targets for a
  /// month. Upserts on (period, employee) → status pending, then routes a
  /// pending-approval notification to management (the existing approval queue).
  static Future<MonthlyTargetSubmission> submit({
    required int year,
    required int month,
    required Map<String, int> values,
    required String employeeEmail,
    required String employeeName,
    String employeeCode = '',
    String department = '',
    String designation = '',
    String note = '',
  }) async {
    final email = employeeEmail.trim().toLowerCase();
    final period = MonthlyTargetSubmission.periodOf(year, month);
    final by = _actorName;

    final history = await _existingHistory(period, email)
      ..add({
        'at': _now(),
        'by': by,
        'action': 'submitted',
        'to': 'pending',
        'values': values,
      });

    final row = await _db
        .from(_table)
        .upsert({
          'period': period,
          'employee_email': email,
          'employee_name': employeeName.trim(),
          'employee_code': employeeCode.trim(),
          'department': department.trim(),
          'designation': designation.trim(),
          'submitted_values': values,
          'approved_values': null,
          'status': 'pending',
          'management_edited': false,
          'note': note.trim(),
          'submitted_by': by,
          'submitted_at': _now(),
          'edited_by': '',
          'edited_at': null,
          'approved_by': '',
          'approved_at': null,
          'status_history': history,
          'updated_at': _now(),
        }, onConflict: 'period,employee_email')
        .select()
        .single();

    final submission =
        MonthlyTargetSubmission.fromJson(Map<String, dynamic>.from(row));

    // Surface in the existing management approval queue.
    await NotificationsService.create(
      audience: 'management',
      type: 'pending_approval',
      title:
          'Monthly target · ${submission.employeeName.isEmpty ? email : submission.employeeName} · ${submission.monthLabel}',
      message: _proposalSummary(submission),
      referenceId: submission.id,
    );
    return submission;
  }

  /// Persist management edits without approving — status stays pending so the
  /// employee is not notified until Approve / Reject.
  static Future<void> saveEdits({
    required MonthlyTargetSubmission submission,
    required Map<String, int> values,
  }) async {
    final by = _actorName;
    final history = await _existingHistory(
        submission.period, submission.employeeEmail)
      ..add({
        'at': _now(),
        'by': by,
        'action': 'edited',
        'from': submission.status.dbValue,
        'to': 'pending',
        'values': values,
      });

    await _db.from(_table).update({
      'approved_values': values,
      'management_edited': true,
      'edited_by': by,
      'edited_at': _now(),
      'status_history': history,
      'updated_at': _now(),
    }).eq('id', submission.id);
  }

  /// Management approves — optionally with edited [approvedValues]. Saves both
  /// the employee-submitted and management-approved values and notifies the
  /// employee (different message when modified).
  static Future<void> approve({
    required MonthlyTargetSubmission submission,
    Map<String, int>? approvedValues,
  }) async {
    final by = _actorName;
    // Prefer explicit dialog values, then any previously saved management
    // edits, then what the employee submitted.
    final finalValues = approvedValues ??
        submission.approvedValues ??
        submission.submittedValues;
    final edited = !_sameValues(finalValues, submission.submittedValues);

    final history = await _existingHistory(
        submission.period, submission.employeeEmail)
      ..add({
        'at': _now(),
        'by': by,
        'action': edited ? 'approved_with_edits' : 'approved',
        'from': submission.status.dbValue,
        'to': 'approved',
        'values': finalValues,
      });

    await _db.from(_table).update({
      'approved_values': finalValues,
      'status': 'approved',
      'management_edited': edited,
      'approved_by': by,
      'approved_at': _now(),
      if (edited) 'edited_by': by,
      if (edited) 'edited_at': _now(),
      'status_history': history,
      'updated_at': _now(),
    }).eq('id', submission.id);

    await _notifyEmployee(
      submission,
      title: 'Monthly targets approved',
      message: edited
          ? 'Your monthly targets have been approved with modifications by Management.'
          : 'Your monthly targets have been approved.',
      type: 'verification',
    );
  }

  /// Management rejects — the employee can then edit and resubmit.
  static Future<void> reject({
    required MonthlyTargetSubmission submission,
    String reason = '',
  }) async {
    final by = _actorName;
    final history = await _existingHistory(
        submission.period, submission.employeeEmail)
      ..add({
        'at': _now(),
        'by': by,
        'action': 'rejected',
        'from': submission.status.dbValue,
        'to': 'rejected',
        'reason': reason.trim(),
      });

    await _db.from(_table).update({
      'status': 'rejected',
      'approved_by': by,
      'approved_at': _now(),
      'note': reason.trim().isEmpty ? submission.note : reason.trim(),
      'status_history': history,
      'updated_at': _now(),
    }).eq('id', submission.id);

    await _notifyEmployee(
      submission,
      title: 'Monthly targets rejected',
      message:
          'Your monthly targets were rejected. Please review and resubmit.',
      type: 'alert',
    );
  }

  static Future<void> _notifyEmployee(
    MonthlyTargetSubmission submission, {
    required String title,
    required String message,
    required String type,
  }) async {
    final to = submission.employeeEmail.trim().toLowerCase();
    if (to.isEmpty) return;
    await NotificationsService.create(
      audience: to,
      type: type,
      title: title,
      // Exact required copy — month context stays in the title when useful.
      message: message,
      referenceId: submission.id,
    );
  }

  static String _proposalSummary(MonthlyTargetSubmission s) {
    final parts = <String>[
      'Submitted by: ${s.submittedBy}',
      if (s.employeeCode.isNotEmpty) 'Employee ID: ${s.employeeCode}',
      if (s.department.isNotEmpty) 'Department: ${s.department}',
      if (s.designation.isNotEmpty) 'Designation: ${s.designation}',
      'Proposed:',
      for (final c in TargetCategory.values)
        if (s.submittedValues.containsKey(c.key))
          '• ${c.label}: ${s.submittedValues[c.key]}',
    ];
    return parts.join('\n');
  }

  static bool _sameValues(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
