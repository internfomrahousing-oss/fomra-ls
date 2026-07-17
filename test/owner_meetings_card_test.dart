import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/models/land_lead.dart';
import 'package:fomra_ls/widgets/lead_portfolio_breakdown.dart';

LandLead _lead(String id, {LeadStatus status = LeadStatus.legal}) => LandLead(
      leadId: id,
      inputSource: InputSource.landowner,
      location: 'Manapakkam',
      gpsCoordinates: '',
      village: 'Manapakkam',
      taluk: '',
      district: '',
      pincode: '',
      surveyNumber: '72',
      landExtent: '0.10 acre',
      ownerName: 'priyan',
      contactDetails: '9944556622',
      brokerName: '',
      landType: LandType.residential,
      roadWidth: '',
      accessDetails: '',
      notes: '',
      addedOn: DateTime(2026, 7, 11),
      status: status,
    );

Future<void> _pump(
  WidgetTester tester, {
  int? meetings,
  List<LandLead>? leads,
  bool hideEmpty = false,
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: LeadPortfolioBreakdown(
          leads: leads ?? [_lead('13')],
          onOpenLead: (_) {},
          meetingsBesideDropped: meetings,
          hideEmptyStatusCards: hideEmpty,
        ),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('shows Meetings Conducted beside Dropped Leads', (tester) async {
    await _pump(tester, meetings: 4);
    expect(tester.takeException(), isNull);
    // Both cards present — the meetings card does not replace Dropped Leads.
    expect(find.text('Dropped Leads'), findsOneWidget);
    expect(find.text('Meetings Conducted'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
  });

  testWidgets('shows it even when there are no dropped leads', (tester) async {
    // The owner in the screenshot has 0 dropped leads but conducted meetings.
    await _pump(tester, meetings: 2);
    expect(find.text('Dropped Leads'), findsOneWidget);
    expect(find.text('Meetings Conducted'), findsOneWidget);
  });

  testWidgets('omits the card when no count is provided', (tester) async {
    await _pump(tester, meetings: null);
    expect(find.text('Dropped Leads'), findsOneWidget);
    expect(find.text('Meetings Conducted'), findsNothing);
  });

  testWidgets('the standard portfolio cards are still there', (tester) async {
    await _pump(tester, meetings: 1);
    for (final label in [
      'Total Properties',
      'Total Acres',
      'Active Leads',
      'Closed Leads',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });

  group('hideEmptyStatusCards — only the applicable status box', () {
    testWidgets('a single closed lead shows only Closed Leads', (tester) async {
      await _pump(
        tester,
        leads: [_lead('11', status: LeadStatus.signed)], // Signed => Closed
        meetings: 1,
        hideEmpty: true,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Closed Leads'), findsOneWidget);
      expect(find.text('Active Leads'), findsNothing);
      expect(find.text('Dropped Leads'), findsNothing);
      // Non-status cards remain.
      expect(find.text('Total Properties'), findsOneWidget);
      expect(find.text('Meetings Conducted'), findsOneWidget);
    });

    testWidgets('an active-only owner shows only Active Leads', (tester) async {
      await _pump(
        tester,
        leads: [_lead('12', status: LeadStatus.legal)], // active stage
        hideEmpty: true,
      );
      expect(find.text('Active Leads'), findsOneWidget);
      expect(find.text('Closed Leads'), findsNothing);
      expect(find.text('Dropped Leads'), findsNothing);
    });

    testWidgets('a mix shows every non-zero status', (tester) async {
      await _pump(
        tester,
        leads: [
          _lead('1', status: LeadStatus.legal), // active
          _lead('2', status: LeadStatus.signed), // closed
        ],
        hideEmpty: true,
      );
      expect(find.text('Active Leads'), findsOneWidget);
      expect(find.text('Closed Leads'), findsOneWidget);
      expect(find.text('Dropped Leads'), findsNothing);
    });
  });
}
