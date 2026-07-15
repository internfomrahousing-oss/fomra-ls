import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/services/fomra_trail.dart';
import 'package:fomra_ls/widgets/fomra_breadcrumb.dart';

/// A page that names itself in the trail, exactly like a real screen does via
/// FomraAppBar's moduleName.
class _Page extends StatelessWidget {
  final String label;
  const _Page(this.label);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(bottom: FomraTrailBreadcrumbBar(label: label)),
        body: const SizedBox.shrink(),
      );
}

/// Labels rendered in the breadcrumb bar, in order.
List<String> _crumbs(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(FomraBreadcrumbBar),
        matching: find.byType(Text),
      ),
    )
    .map((t) => t.data ?? '')
    .toList();

void main() {
  final navKey = GlobalKey<NavigatorState>();

  Future<void> pumpApp(WidgetTester tester) async {
    FomraTrail.instance.debugReset();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      navigatorObservers: [FomraTrailObserver()],
      home: const _Page('Home'),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> push(WidgetTester tester, String label) async {
    navKey.currentState!.push(
      MaterialPageRoute<void>(builder: (_) => _Page(label)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('trail follows the pages actually visited', (tester) async {
    await pumpApp(tester);
    await push(tester, 'Land Workspace');
    await push(tester, 'Negotiation');
    await push(tester, 'Lead 12');

    expect(_crumbs(tester),
        ['Home', 'Land Workspace', 'Negotiation', 'Lead 12']);
  });

  testWidgets('the same page reached another way shows that other path',
      (tester) async {
    await pumpApp(tester);
    await push(tester, 'Reports');
    await push(tester, 'Lead 12');

    expect(_crumbs(tester), ['Home', 'Reports', 'Lead 12']);
  });

  testWidgets('always begins with Home, and never repeats it', (tester) async {
    await pumpApp(tester);
    await push(tester, 'Land Workspace');

    final crumbs = _crumbs(tester);
    expect(crumbs.first, 'Home');
    expect(crumbs.where((c) => c == 'Home'), hasLength(1));
  });

  testWidgets('going back drops the trailing crumbs', (tester) async {
    await pumpApp(tester);
    await push(tester, 'Land Workspace');
    await push(tester, 'Negotiation');
    expect(_crumbs(tester), ['Home', 'Land Workspace', 'Negotiation']);

    // Equivalent to browser Back / the system back button.
    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(_crumbs(tester), ['Home', 'Land Workspace']);
  });

  testWidgets('tapping an ancestor pops back to exactly that page',
      (tester) async {
    await pumpApp(tester);
    await push(tester, 'Land Workspace');
    await push(tester, 'Negotiation');
    await push(tester, 'Lead 12');

    await tester.tap(find.text('Land Workspace'));
    await tester.pumpAndSettle();

    expect(_crumbs(tester), ['Home', 'Land Workspace']);
    expect(find.text('Lead 12'), findsNothing);
  });

  testWidgets('the current page is not a link', (tester) async {
    await pumpApp(tester);
    await push(tester, 'Land Workspace');

    // Ancestors are tappable; the page you're on is plain text.
    final links = find.descendant(
      of: find.byType(FomraBreadcrumbBar),
      matching: find.byType(InkWell),
    );
    expect(tester.widgetList(links), hasLength(1)); // Home only
  });
}
