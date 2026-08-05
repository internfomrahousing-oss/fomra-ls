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

/// Matches the real construction in home_screen.dart: an "overall" [progress]
/// drives the header's on-track/behind badge, and [categories] (Leads/Site
/// Visits/Meetings, each with their own progress) drive the per-category
/// timelines below it. Both must be supplied for the real UI to render at
/// all — with an empty categories list the card falls back to a "set your
/// targets" prompt regardless of what [progress] says.
Future<void> _pump(
  WidgetTester tester, {
  required MonthlyTargetProgress progress,
  List<MonthlyTargetCategoryProgress> categories = const [],
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
            categories: categories,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

List<MonthlyTargetCategoryProgress> _sampleCategories({
  required int leadsDone,
}) =>
    [
      MonthlyTargetCategoryProgress(
        label: 'Leads',
        color: AppColors.primary,
        progress: _progress(target: 30, done: leadsDone),
      ),
      MonthlyTargetCategoryProgress(
        label: 'Site Visits',
        color: AppColors.success,
        progress: _progress(target: 15, done: 10),
      ),
      MonthlyTargetCategoryProgress(
        label: 'Meetings',
        color: AppColors.warning,
        progress: _progress(target: 10, done: 5),
      ),
    ];

void main() {
  testWidgets('with categories, each one renders its label and achieved/target',
      (tester) async {
    await _pump(
      tester,
      progress: _progress(target: 30, done: 20),
      categories: _sampleCategories(leadsDone: 20),
    );
    expect(tester.takeException(), isNull);

    expect(find.text('Leads'), findsOneWidget);
    expect(find.text('Site Visits'), findsOneWidget);
    expect(find.text('Meetings'), findsOneWidget);

    // Leads: 20 achieved / 30 target.
    expect(find.text('20'), findsWidgets);
    expect(find.text(' / 30'), findsOneWidget);
    // Site Visits: 10 / 15.
    expect(find.text('10'), findsWidgets);
    expect(find.text(' / 15'), findsOneWidget);
  });

  testWidgets('ahead of the run-rate reads as On track, in green',
      (tester) async {
    // 20 by day 15 against a target of 30 beats the ~14.5 run-rate.
    await _pump(
      tester,
      progress: _progress(target: 30, done: 20),
      categories: _sampleCategories(leadsDone: 20),
    );
    expect(tester.takeException(), isNull);

    expect(find.text('On track'), findsOneWidget);
    expect(find.text('Behind target'), findsNothing);
  });

  testWidgets('behind the run-rate reads as Behind target, in warning',
      (tester) async {
    await _pump(
      tester,
      progress: _progress(target: 30, done: 2),
      categories: _sampleCategories(leadsDone: 2),
    );
    expect(tester.takeException(), isNull);

    expect(find.text('Behind target'), findsOneWidget);
    expect(find.text('On track'), findsNothing);
  });

  testWidgets('a zero-target category does not divide by zero',
      (tester) async {
    await _pump(
      tester,
      progress: _progress(target: 30, done: 20),
      categories: [
        MonthlyTargetCategoryProgress(
          label: 'Leads',
          color: AppColors.primary,
          progress: _progress(target: 0, done: 0),
        ),
      ],
    );
    // A target <= 0 should be handled gracefully (0% fill), not crash.
    expect(tester.takeException(), isNull);
    expect(find.text('Leads'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('with no categories it prompts to set targets instead',
      (tester) async {
    await _pump(tester, progress: _progress(target: 0, done: 3));
    expect(tester.takeException(), isNull);

    expect(find.text('Set your targets'), findsOneWidget);
    expect(find.textContaining('Set Monthly Targets'), findsOneWidget);
  });

  testWidgets('pending approval empty state explains the wait', (tester) async {
    await _pump(
      tester,
      progress: _progress(target: 0, done: 0),
      pendingApproval: true,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Awaiting approval'), findsOneWidget);
    expect(find.textContaining('awaiting management approval'), findsOneWidget);
  });

  testWidgets('lays out on a narrow phone without overflowing', (tester) async {
    await _pump(
      tester,
      progress: _progress(target: 30, done: 20),
      categories: _sampleCategories(leadsDone: 20),
      width: 360,
    );
    // An overflow would surface here.
    expect(tester.takeException(), isNull);
    expect(find.text('Leads'), findsOneWidget);
  });
}
