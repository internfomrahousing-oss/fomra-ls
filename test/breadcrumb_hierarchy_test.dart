import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/widgets/fomra_breadcrumb.dart';

/// The breadcrumb labels the bar would render, in order.
List<String> _crumbs(List<FomraBreadcrumbItem> items) =>
    items.map((i) => i.label).toList();

void main() {
  group('flat two-level breadcrumbs', () {
    test('every module page is just Home > itself', () {
      expect(_crumbs(FomraBreadcrumbs.forModule('Land Workspace')),
          ['Home', 'Land Workspace']);
      expect(_crumbs(FomraBreadcrumbs.forModule('Reports')),
          ['Home', 'Reports']);
      expect(_crumbs(FomraBreadcrumbs.forModule('Settings')),
          ['Home', 'Settings']);
    });

    test('pages that used to nest are now flat Home > page', () {
      // No intermediate "Settings" / "Land Workspace" crumb anymore — a page
      // opened from Home shows only where you are.
      expect(_crumbs(FomraBreadcrumbs.forModule('Dropped Reasons')),
          ['Home', 'Dropped Reasons']);
      expect(_crumbs(FomraBreadcrumbs.forModule('Monthly Targets')),
          ['Home', 'Monthly Targets']);
      expect(_crumbs(FomraBreadcrumbs.forModule('Project Map')),
          ['Home', 'Project Map']);
      expect(_crumbs(FomraBreadcrumbs.forModule('Add Land Lead')),
          ['Home', 'Add Land Lead']);
    });

    test('always begins with Home and is exactly two crumbs', () {
      for (final label in [
        'Land Workspace',
        'Dropped Reasons',
        'Add Land Lead',
        'Anything Else',
      ]) {
        final items = FomraBreadcrumbs.forModule(label);
        expect(items.first.label, 'Home');
        expect(items.length, 2);
      }
    });

    test('the last crumb is the current page and is not a link', () {
      final items = FomraBreadcrumbs.forModule('Dropped Reasons');
      expect(items.last.isCurrent, isTrue);
      expect(items.last.label, 'Dropped Reasons');
    });
  });

  group('dynamic titles via under() are also flat', () {
    test('a filtered list is Home > its title, ignoring passed ancestors', () {
      expect(
        _crumbs(FomraBreadcrumbs.under(
            const [FomraBreadcrumbs.landWorkspace], 'Negotiation')),
        ['Home', 'Negotiation'],
      );
    });

    test('a lead is Home > its title', () {
      expect(
        _crumbs(FomraBreadcrumbs.under(
            const [FomraBreadcrumbs.landWorkspace], 'Lead 12')),
        ['Home', 'Lead 12'],
      );
    });
  });

  group('the bar renders the flat trail', () {
    testWidgets('shows Home > page only', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            bottom: const FomraModuleBreadcrumbBar(label: 'Dropped Reasons'),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Dropped Reasons'), findsOneWidget);
      // The old intermediate "Settings" crumb is gone.
      expect(find.text('Settings'), findsNothing);
    });

    testWidgets('a dynamic title renders Home > title, no ancestor',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            bottom: const FomraModuleBreadcrumbBar(
              label: 'Lead 12',
              ancestors: [FomraBreadcrumbs.landWorkspace],
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Lead 12'), findsOneWidget);
      expect(find.text('Land Workspace'), findsNothing);
    });
  });
}
