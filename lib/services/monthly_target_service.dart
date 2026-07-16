import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/monthly_target.dart';
import 'auth_service.dart';

/// Reads/writes the common monthly target every employee is measured against.
///
/// Degrades gracefully if the `monthly_targets` table is missing: reads return
/// nothing rather than throwing, so an employee dashboard on a workspace that
/// hasn't run the migration simply shows no target instead of breaking.
class MonthlyTargetService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const _table = 'monthly_targets';

  /// Every target, newest month first.
  static Future<List<MonthlyTarget>> getAll() async {
    try {
      final rows = await _db.from(_table).select().order('period', ascending: false);
      return (rows as List)
          .map((r) => MonthlyTarget.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// The common target for a month, or null when management hasn't set one.
  static Future<MonthlyTarget?> forMonth(int year, int month) async {
    try {
      final row = await _db
          .from(_table)
          .select()
          .eq('period', MonthlyTarget.periodOf(year, month))
          .eq('employee_email', '')
          .maybeSingle();
      if (row == null) return null;
      return MonthlyTarget.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  /// The common target for the month [now] falls in.
  static Future<MonthlyTarget?> active({DateTime? now}) {
    final clock = now ?? DateTime.now();
    return forMonth(clock.year, clock.month);
  }

  /// The target [employee] is measured against for the month [now] falls in: a
  /// personal target when one is set, otherwise the common one. Null when
  /// neither exists.
  static Future<MonthlyTarget?> resolveForEmployee(
    String employeeEmail, {
    DateTime? now,
  }) async {
    final clock = now ?? DateTime.now();
    final email = employeeEmail.trim().toLowerCase();
    try {
      final rows = await _db
          .from(_table)
          .select()
          .eq('period', MonthlyTarget.periodOf(clock.year, clock.month))
          .inFilter('employee_email', [email, '']);
      final targets = (rows as List)
          .map((r) => MonthlyTarget.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
      // Personal beats common.
      return MonthlyTarget.pickFor(targets, email);
    } catch (_) {
      return null;
    }
  }

  /// Creates the target for a (month, employee) pair, or updates it if one
  /// already exists — UNIQUE(period, employee_email) keeps it to one per pair.
  /// A common target uses an empty [employeeEmail]. Other months and other
  /// employees are never touched.
  ///
  /// Throws on failure so the settings page can surface why a save didn't land.
  static Future<MonthlyTarget> save({
    required int year,
    required int month,
    required int target,
    String employeeEmail = '',
    String employeeName = '',
  }) async {
    final row = await _db
        .from(_table)
        .upsert({
          'period': MonthlyTarget.periodOf(year, month),
          'employee_email': employeeEmail.trim().toLowerCase(),
          'employee_name': employeeName.trim(),
          'target_count': target,
          'updated_by_name': AuthService.instance.currentUser?.fullName ?? '',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'period,employee_email')
        .select()
        .single();
    return MonthlyTarget.fromJson(Map<String, dynamic>.from(row));
  }
}
