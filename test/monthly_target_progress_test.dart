import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/analytics/monthly_target_progress.dart';
import 'package:fomra_ls/models/monthly_target.dart';

// 15 July 2026 — mid-month, and July has 31 days.
final _now = DateTime(2026, 7, 15);

MonthlyTargetProgress _progress({
  int target = 30,
  List<DateTime> completedOn = const [],
  DateTime? now,
}) =>
    MonthlyTargetProgress.forMonth(
      target: target,
      now: now ?? _now,
      completedOn: completedOn,
    );

void main() {
  group('the headline numbers', () {
    test('achieved counts only this month\'s completions', () {
      final p = _progress(completedOn: [
        DateTime(2026, 7, 2),
        DateTime(2026, 7, 9),
        DateTime(2026, 6, 30), // last month
        DateTime(2026, 8, 1), // next month
      ]);
      expect(p.achieved, 2);
    });

    test('remaining is what is left of the target', () {
      expect(_progress(target: 30, completedOn: [DateTime(2026, 7, 3)]).remaining, 29);
    });

    test('beating the target is not negative work', () {
      final p = _progress(
        target: 2,
        completedOn: [DateTime(2026, 7, 1), DateTime(2026, 7, 2), DateTime(2026, 7, 3)],
      );
      expect(p.remaining, 0);
      expect(p.completionPercent, 100, reason: 'capped, not 150%');
    });

    test('completion percent tracks achieved over target', () {
      final p = _progress(
        target: 4,
        completedOn: [DateTime(2026, 7, 1), DateTime(2026, 7, 2)],
      );
      expect(p.completionPercent, 50);
    });

    test('no target set means nothing to be behind on', () {
      final p = _progress(target: 0, completedOn: [DateTime(2026, 7, 1)]);
      expect(p.hasTarget, isFalse);
      expect(p.completionPercent, 0);
      expect(p.expectedToday, 0);
      expect(p.isOnTrack, isTrue);
    });
  });

  group('expected progress today', () {
    test('is the even run-rate to date', () {
      // Day 15 of 31, target 31 => 15.
      final p = _progress(target: 31);
      expect(p.expectedToday, closeTo(15, 0.001));
    });

    test('on track when at or above the run-rate', () {
      final done = [for (var d = 1; d <= 15; d++) DateTime(2026, 7, d)];
      final p = _progress(target: 31, completedOn: done);
      expect(p.achieved, 15);
      expect(p.isOnTrack, isTrue);
      expect(p.varianceToday, closeTo(0, 0.001));
    });

    test('behind when under the run-rate', () {
      final p = _progress(target: 31, completedOn: [DateTime(2026, 7, 1)]);
      expect(p.isOnTrack, isFalse);
      expect(p.varianceToday, lessThan(0));
    });

    test('ahead of the run-rate is on track', () {
      // Two a day for the first ten days: 20 done by day 15, run-rate wants 15.
      final done = [
        for (var d = 1; d <= 10; d++) ...[DateTime(2026, 7, d), DateTime(2026, 7, d)],
      ];
      final p = _progress(target: 31, completedOn: done);
      expect(p.achieved, 20);
      expect(p.isOnTrack, isTrue);
      expect(p.varianceToday, greaterThan(0));
    });

    test('work dated after today does not count as achieved yet', () {
      final p = _progress(target: 31, completedOn: [DateTime(2026, 7, 20)]);
      expect(p.achieved, 0, reason: 'day 20 has not happened on day 15');
    });
  });

  group('the chart series', () {
    test('the actual line is cumulative and stops at today', () {
      final p = _progress(completedOn: [
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 3),
      ]);
      // Day1=2, day2=2 (none), day3=3, then flat to day 15.
      expect(p.actualByDay.first, 2);
      expect(p.actualByDay[1], 2);
      expect(p.actualByDay[2], 3);
      expect(p.actualByDay.length, 15, reason: 'stops at today, not month end');
      expect(p.actualByDay.last, 3);
    });

    test('the target line spans the whole month and ends on the target', () {
      final p = _progress(target: 31);
      expect(p.targetByDay.length, 31);
      expect(p.targetByDay.first, closeTo(1, 0.001));
      expect(p.targetByDay.last, closeTo(31, 0.001));
    });

    test('a 30-day month has 30 points', () {
      final p = _progress(now: DateTime(2026, 6, 10));
      expect(p.daysInMonth, 30);
      expect(p.targetByDay.length, 30);
    });

    test('February leap years are handled', () {
      final p = _progress(now: DateTime(2028, 2, 10));
      expect(p.daysInMonth, 29);
    });

    test('on day 1 the actual line has a single point', () {
      final p = _progress(now: DateTime(2026, 7, 1), completedOn: [DateTime(2026, 7, 1)]);
      expect(p.actualByDay, [1]);
      expect(p.dayOfMonth, 1);
    });
  });

  group('MonthlyTarget', () {
    test('the period key is the stable YYYY-MM the table is unique on', () {
      expect(MonthlyTarget.periodOf(2026, 7), '2026-07');
      expect(MonthlyTarget.periodOf(2026, 12), '2026-12');
    });

    test('round-trips through the row shape Supabase returns', () {
      final t = MonthlyTarget.fromJson({
        'id': 'abc',
        'period': '2026-07',
        'target_count': 25,
        'employee_email': '',
        'employee_name': '',
        'updated_by_name': 'Manager',
        'updated_at': '2026-07-01T00:00:00.000Z',
      });
      expect(t.year, 2026);
      expect(t.month, 7);
      expect(t.target, 25);
      expect(t.label, 'July 2026');
      expect(t.period, '2026-07');
    });

    test('knows which month it is active for', () {
      final t = MonthlyTarget.fromJson({
        'id': 'a',
        'period': '2026-07',
        'target_count': 5,
        'updated_at': '2026-07-01T00:00:00.000Z',
      });
      expect(t.isActiveAt(DateTime(2026, 7, 20)), isTrue);
      expect(t.isActiveAt(DateTime(2026, 8, 1)), isFalse);
    });

    test('an empty employee_email is the common target for everyone', () {
      final t = MonthlyTarget.fromJson({
        'id': 'a',
        'period': '2026-07',
        'target_count': 30,
        'employee_email': '',
        'updated_at': '2026-07-01T00:00:00.000Z',
      });
      expect(t.isCommon, isTrue);
      expect(t.appliesToLabel, 'All employees');
    });

    test('a named employee_email is a personal target', () {
      final t = MonthlyTarget.fromJson({
        'id': 'b',
        'period': '2026-07',
        'target_count': 12,
        'employee_email': 'Sara@Fomrahousing.in',
        'employee_name': 'Sara',
        'updated_at': '2026-07-01T00:00:00.000Z',
      });
      expect(t.isCommon, isFalse);
      // Stored lowercase so it matches the signed-in email.
      expect(t.employeeEmail, 'sara@fomrahousing.in');
      expect(t.appliesToLabel, 'Sara');
    });

    test('a personal target with no name falls back to the email label', () {
      final t = MonthlyTarget.fromJson({
        'id': 'c',
        'period': '2026-07',
        'target_count': 8,
        'employee_email': 'x@y.in',
        'updated_at': '2026-07-01T00:00:00.000Z',
      });
      expect(t.appliesToLabel, 'x@y.in');
    });

    test('an old row with no employee column reads as the common target', () {
      // Pre per-employee rows have neither employee_email nor employee_name.
      final t = MonthlyTarget.fromJson({
        'id': 'd',
        'period': '2026-06',
        'target_count': 20,
        'updated_at': '2026-06-01T00:00:00.000Z',
      });
      expect(t.isCommon, isTrue);
    });
  });

  group('pickFor — the target an employee is measured against', () {
    MonthlyTarget common(int target) => MonthlyTarget(
          id: 'c',
          year: 2026,
          month: 7,
          target: target,
          updatedAt: DateTime(2026, 7, 1),
        );
    MonthlyTarget personal(String email, int target) => MonthlyTarget(
          id: 'p-$email',
          year: 2026,
          month: 7,
          target: target,
          employeeEmail: email,
          updatedAt: DateTime(2026, 7, 1),
        );

    test('a personal target overrides the common one', () {
      final pick = MonthlyTarget.pickFor(
        [common(30), personal('sara@fomrahousing.in', 12)],
        'sara@fomrahousing.in',
      );
      expect(pick?.target, 12);
    });

    test('order does not matter', () {
      final pick = MonthlyTarget.pickFor(
        [personal('sara@fomrahousing.in', 12), common(30)],
        'sara@fomrahousing.in',
      );
      expect(pick?.target, 12);
    });

    test('an employee with no personal target falls back to common', () {
      final pick = MonthlyTarget.pickFor(
        [common(30), personal('other@fomrahousing.in', 12)],
        'sara@fomrahousing.in',
      );
      expect(pick?.target, 30);
    });

    test('matching is case-insensitive', () {
      final pick = MonthlyTarget.pickFor(
        [personal('sara@fomrahousing.in', 12)],
        'SARA@Fomrahousing.IN',
      );
      expect(pick?.target, 12);
    });

    test('no common and no personal means nothing to measure against', () {
      final pick = MonthlyTarget.pickFor(
        [personal('other@fomrahousing.in', 12)],
        'sara@fomrahousing.in',
      );
      expect(pick, isNull);
    });

    test('only a common target set applies to everyone', () {
      final pick = MonthlyTarget.pickFor([common(30)], 'anyone@fomrahousing.in');
      expect(pick?.target, 30);
    });
  });
}
