import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/analytics/monthly_target_progress.dart';
import 'package:fomra_ls/theme/app_theme.dart';
import 'package:fomra_ls/widgets/monthly_target_progress_card.dart';

final _now = DateTime(2026, 7, 15);

MonthlyTargetProgress _progress({required int target, required int done}) =>
    MonthlyTargetProgress.forMonth(
      target: target,
      now: _now,
      completedOn: [for (var i = 0; i < done; i++) DateTime(2026, 7, 1 + i % 14)],
    );

Future<void> _pump(
  WidgetTester tester,
  MonthlyTargetProgress progress, {
  double width = 600,
  bool pendingApproval = false,
}) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: width,
          child: MonthlyTargetProgressCard(
            progress: progress,
            month: _now,
            pendingApproval: pendingApproval,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the headline numbers and both chart lines',
      (tester) async {
    await _pump(tester, _progress(target: 30, done: 20));
    expect(tester.takeException(), isNull);

    // Achieved / target.
    expect(find.text('20'), findsWidgets);
    expect(find.text('/ 30 sites'), findsOneWidget);

    // Actual + target progress lines.
    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData, hasLength(2));

    // The target line spans the whole month; the actual stops at today.
    expect(chart.data.lineBarsData[1].spots, hasLength(31));
    expect(chart.data.lineBarsData[0].spots, hasLength(15));
  });

  testWidgets('ahead of the run-rate reads as On track, in green',
      (tester) async {
    // 20 by day 15 against a target of 30 beats the ~14.5 run-rate.
    await _pump(tester, _progress(target: 30, done: 20));
    expect(tester.takeException(), isNull);

    expect(find.text('On track'), findsOneWidget);
    expect(find.text('Behind target'), findsNothing);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.first.color, AppColors.success);
  });

  testWidgets('behind the run-rate reads as Behind target, in warning',
      (tester) async {
    await _pump(tester, _progress(target: 30, done: 2));
    expect(tester.takeException(), isNull);

    expect(find.text('Behind target'), findsOneWidget);
    expect(find.text('On track'), findsNothing);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.first.color, AppColors.warning);
  });

  testWidgets('shows the four foot stats', (tester) async {
    await _pump(tester, _progress(target: 30, done: 20));
    expect(tester.takeException(), isNull);

    expect(find.text('Current target'), findsOneWidget);
    expect(find.text('Achieved'), findsOneWidget);
    expect(find.text('Remaining'), findsOneWidget);
    expect(find.text('Expected today'), findsOneWidget);

    // Remaining = 30 - 20.
    expect(find.text('10'), findsWidgets);

    // Expected today is shown as a whole number, never a decimal. On day 15 of
    // 31 with target 30 the precise value is 14.52, displayed rounded as 15.
    expect(find.textContaining('.'), findsNothing);
    expect(find.text('15'), findsWidgets);
  });

  testWidgets('with no target set it says so instead of dividing by zero',
      (tester) async {
    await _pump(tester, _progress(target: 0, done: 3));
    expect(tester.takeException(), isNull);

    expect(find.text('No target set'), findsOneWidget);
    expect(find.textContaining('My Monthly Targets'), findsOneWidget);
    expect(find.byType(LineChart), findsNothing);
  });

  testWidgets('pending approval empty state explains the wait', (tester) async {
    await _pump(
      tester,
      _progress(target: 0, done: 0),
      pendingApproval: true,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(find.textContaining('awaiting management approval'), findsOneWidget);
  });

  testWidgets('lays out on a narrow phone without overflowing', (tester) async {
    await _pump(tester, _progress(target: 30, done: 20), width: 360);
    // An overflow would surface here.
    expect(tester.takeException(), isNull);
    expect(find.byType(LineChart), findsOneWidget);
  });
}
