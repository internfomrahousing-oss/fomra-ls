import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/analytics/management_bi_metrics.dart';
import 'package:fomra_ls/theme/app_theme.dart';
import 'package:fomra_ls/widgets/management_bi_sections.dart';

/// The dashboard's two-column grid, built as the Home dashboard builds it. The
/// private Deal Terms / Pending Stages cards can't be constructed from a test,
/// so plain boxes stand in for the right column — what's under test is the grid
/// geometry, not those cards' contents.
Widget _grid({required double width, bool intrinsicHeight = false}) {
  const pipeline = BiPipelineSection(
    summary: BiPipelineSummary(
      totalLeads: 12,
      totalAcres: 40,
      pipelineAcres: 22,
      activeDeals: 5,
      closedDeals: 3,
    ),
  );
  const ageing = KeyedSubtree(
    key: Key('ageing'),
    child: BiAgeingSection(rows: []),
  );
  const donut = SizedBox(height: 200, child: Card());
  const pendingStages = Card(key: Key('pendingStages'));

  final row = Row(
    crossAxisAlignment: intrinsicHeight
        ? CrossAxisAlignment.stretch
        : CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            pipeline,
            const SizedBox(height: AppSpacing.lg),
            intrinsicHeight ? const Expanded(child: ageing) : ageing,
          ],
        ),
      ),
      const SizedBox(width: AppSpacing.lg),
      Expanded(
        flex: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            donut,
            const SizedBox(height: AppSpacing.lg),
            intrinsicHeight ? const Expanded(child: pendingStages) : pendingStages,
          ],
        ),
      ),
    ],
  );

  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: width,
          child: intrinsicHeight ? IntrinsicHeight(child: row) : row,
        ),
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(1600, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(w);
}

void main() {
  testWidgets('the columns start on the same line', (tester) async {
    await _pump(tester, _grid(width: 1400));
    expect(tester.takeException(), isNull);

    final pipeline = tester.getRect(find.byType(BiPipelineSection));
    final donut = tester.getRect(find.byType(Card).first);
    expect(pipeline.top, moreOrLessEquals(donut.top, epsilon: 0.5));
  });

  testWidgets('the columns split 70/30 either side of one 24px gutter',
      (tester) async {
    await _pump(tester, _grid(width: 1400));
    expect(tester.takeException(), isNull);

    final pipeline = tester.getRect(find.byType(BiPipelineSection));
    final pending = tester.getRect(find.byKey(const Key('pendingStages')));

    // 7:3 of (1400 - 24) => 963.2 / 412.8.
    expect(pipeline.width, moreOrLessEquals(963.2, epsilon: 1.0));
    expect(pending.width, moreOrLessEquals(412.8, epsilon: 1.0));

    // Exactly one 24px gutter between the two columns.
    expect(pending.left - pipeline.right, moreOrLessEquals(AppSpacing.lg, epsilon: 0.5));
  });

  testWidgets('each card is exactly as wide as the one above it',
      (tester) async {
    await _pump(tester, _grid(width: 1400));
    expect(tester.takeException(), isNull);

    final pipeline = tester.getRect(find.byType(BiPipelineSection));
    final ageing = tester.getRect(find.byKey(const Key('ageing')));
    final donut = tester.getRect(find.byType(Card).first);
    final pending = tester.getRect(find.byKey(const Key('pendingStages')));

    expect(ageing.width, moreOrLessEquals(pipeline.width, epsilon: 0.5));
    expect(ageing.left, moreOrLessEquals(pipeline.left, epsilon: 0.5));
    expect(pending.width, moreOrLessEquals(donut.width, epsilon: 0.5));
    expect(pending.left, moreOrLessEquals(donut.left, epsilon: 0.5));
  });

  testWidgets('cards are separated by exactly 24px vertically', (tester) async {
    await _pump(tester, _grid(width: 1400));
    expect(tester.takeException(), isNull);

    final pipeline = tester.getRect(find.byType(BiPipelineSection));
    final ageing = tester.getRect(find.byKey(const Key('ageing')));
    expect(ageing.top - pipeline.bottom, moreOrLessEquals(AppSpacing.lg, epsilon: 0.5));
  });

  testWidgets('the proportions hold at a narrower desktop width',
      (tester) async {
    await _pump(tester, _grid(width: 1000));
    expect(tester.takeException(), isNull);

    final pipeline = tester.getRect(find.byType(BiPipelineSection));
    final pending = tester.getRect(find.byKey(const Key('pendingStages')));

    // 7:3 of (1000 - 24) => 683.2 / 292.8.
    expect(pipeline.width, moreOrLessEquals(683.2, epsilon: 1.0));
    expect(pending.width, moreOrLessEquals(292.8, epsilon: 1.0));
  });

  testWidgets(
      'IntrinsicHeight cannot level these columns — the cards use LayoutBuilder',
      (tester) async {
    // Documents why the grid does not force a shared column height. Levelling
    // the bottom edges needs IntrinsicHeight, but Pipeline Dashboard and Site
    // Ageing each build through a LayoutBuilder, which refuses intrinsics. If
    // this ever stops throwing, the columns can be levelled — see the card
    // bodies in management_bi_sections.dart.
    await _pump(tester, _grid(width: 1400, intrinsicHeight: true));

    expect(
      tester.takeException(),
      isNotNull,
      reason: 'IntrinsicHeight still fails on these cards ("LayoutBuilder does '
          'not support returning intrinsic dimensions"). If this stops throwing, '
          'the two columns can finally be levelled with IntrinsicHeight + '
          'CrossAxisAlignment.stretch and an Expanded trailing card.',
    );
  });
}
