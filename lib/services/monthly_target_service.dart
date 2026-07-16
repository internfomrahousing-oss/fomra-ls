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

  /// The target for one month, or null when management hasn't set one.
  static Future<MonthlyTarget?> forMonth(int year, int month) async {
    try {
      final row = await _db
          .from(_table)
          .select()
          .eq('period', MonthlyTarget.periodOf(year, month))
          .maybeSingle();
      if (row == null) return null;
      return MonthlyTarget.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  /// The target for the month [now] falls in.
  static Future<MonthlyTarget?> active({DateTime? now}) {
    final clock = now ?? DateTime.now();
    return forMonth(clock.year, clock.month);
  }

  /// Creates the month's target, or updates it if one already exists — the
  /// table's UNIQUE(period) is what keeps it to one per month. Setting a target
  /// on a new month never touches earlier months.
  ///
  /// Throws on failure so the settings page can surface why a save didn't land.
  static Future<MonthlyTarget> save({
    required int year,
    required int month,
    required int target,
  }) async {
    final row = await _db
        .from(_table)
        .upsert({
          'period': MonthlyTarget.periodOf(year, month),
          'target_count': target,
          'updated_by_name': AuthService.instance.currentUser?.fullName ?? '',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'period')
        .select()
        .single();
    return MonthlyTarget.fromJson(Map<String, dynamic>.from(row));
  }
}
