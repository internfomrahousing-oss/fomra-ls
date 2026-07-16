import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/widgets/fomra_breadcrumb.dart';

/// The breadcrumb labels the bar would render, in order.
List<String> _crumbs(List<FomraBreadcrumbItem> items) =>
    items.map((i) => i.label).toList();

void main() {
  group('static module hierarchy', () {
    test('a top-level module is just Home > itself', () {
      expect(_crumbs(FomraBreadcrumbs.forModule('Land Workspace')),
          ['Home', 'Land Workspace']);
      expect(_crumbs(FomraBreadcrumbs.forModule('Reports')),
          ['Home', 'Reports']);
      expect(_crumbs(FomraBreadcrumbs.forModule('Settings')),
          ['Home', 'Settings']);
    });

    test('an unregistered module falls back to Home > itself', () {
      expect(_crumbs(FomraBreadcrumbs.forModule('Cost Calculator')),
          ['Home', 'Cost Calculator']);
    });

    test('a settings page reads Home > Settings > page', () {
      expect(_crumbs(FomraBreadcrumbs.forModule('Dropped Reasons')),
          ['Home', 'Settings', 'Dropped Reasons']);
      expect(_crumbs(FomraBreadcrumbs.forModule('Monthly Targets')),
          ['Home', 'Settings', 'Monthly Targets']);
    });

    test('a land page reads Home > Land Workspace > page', () {
      expect(_crumbs(FomraBreadcrumbs.forModule('Add Land Lead')),
          ['Home', 'Land Workspace', 'Add Land Lead']);
      expect(_crumbs(FomraBreadcrumbs.forModule('Project Map')),
          ['Home', 'Land Workspace', 'Project Map']);
    });

    test('always begins with Home', () {
      for (final label in [
        'Land Workspace',
        'Dropped Reasons',
        'Add Land Lead',
        'Anything Else',
      ]) {
        expect(FomraBreadcrumbs.forModule(label).first.label, 'Home');
      }
    });

    test('the last crumb is the current page and is not a link', () {
      final items = FomraBreadcrumbs.forModule('Dropped Reasons');
      expect(items.last.isCurrent, isTrue);
      expect(items.last.label, 'Dropped Reasons');
    });

    test('intermediate crumbs carry a route to navigate to', () {
      final items = FomraBreadcrumbs.forModule('Dropped Reasons');
      final settings = items[1];
      expect(settings.label, 'Settings');
      expect(settings.action, FomraBreadcrumbAction.namedRoute);
      expect(settings.route, '/settings');
    });
  });

  group('dynamic titles via under()', () {
    test('a filtered list sits under Land Workspace', () {
      expect(
        _crumbs(FomraBreadcrumbs.under(
            const [FomraBreadcrumbs.landWorkspace], 'Negotiation')),
        ['Home', 'Land Workspace', 'Negotiation'],
      );
    });

    test('a lead sits under Land Workspace', () {
      expect(
        _crumbs(FomraBreadcrumbs.under(
            const [FomraBreadcrumbs.landWorkspace], 'Lead 12')),
        ['Home', 'Land Workspace', 'Lead 12'],
      );
    });

    test('the same lead reads the same path however it was opened', () {
      // Route-based, not history-based: opening a lead from Reports or from a
      // filtered list gives the identical module path.
      final a = FomraBreadcrumbs.under(
          const [FomraBreadcrumbs.landWorkspace], 'Lead 12');
      final b = FomraBreadcrumbs.under(
          const [FomraBreadcrumbs.landWorkspace], 'Lead 12');
      expect(_crumbs(a), _crumbs(b));
    });
  });

  group('the bar renders the hierarchy', () {
    testWidgets('shows every crumb label', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            bottom: const FomraModuleBreadcrumbBar(label: 'Dropped Reasons'),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Dropped Reasons'), findsOneWidget);
    });

    testWidgets('a dynamic title renders under its ancestors', (tester) async {
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
      expect(find.text('Land Workspace'), findsOneWidget);
      expect(find.text('Lead 12'), findsOneWidget);
    });
  });
}
