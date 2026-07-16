import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/models/lead_call_log.dart';
import 'package:fomra_ls/widgets/separate_date_time_fields.dart';

void main() {
  group('follow-up on a call log', () {
    test('a row with a follow_up_at reads as needing follow-up', () {
      final log = LeadCallLog.fromJson({
        'id': '1',
        'lead_id': '12',
        'called_at': '2026-07-16T09:00:00.000Z',
        'duration': '5',
        'details': 'Discussed price',
        'direction': 'outgoing',
        'outcome': 'answered',
        'logged_by_name': 'Exec',
        'follow_up_at': '2026-07-18T10:30:00.000Z',
      });
      expect(log.needsFollowUp, isTrue);
      expect(log.followUpAt, isNotNull);
    });

    test('a row without a follow_up_at needs no follow-up', () {
      final log = LeadCallLog.fromJson({
        'id': '2',
        'lead_id': '12',
        'called_at': '2026-07-16T09:00:00.000Z',
        'duration': '5',
        'details': '',
        'direction': 'outgoing',
        'outcome': 'answered',
        'logged_by_name': 'Exec',
      });
      expect(log.needsFollowUp, isFalse);
      expect(log.followUpAt, isNull);
    });
  });

  group('the follow-up fields toggle in the dialog', () {
    // A tiny stand-in mirroring the dialog's toggle: fields appear only when on.
    Widget harness() => MaterialApp(
          home: Scaffold(
            body: _FollowUpToggle(),
          ),
        );

    testWidgets('date/time fields are hidden until the toggle is on',
        (tester) async {
      await tester.pumpWidget(harness());
      expect(tester.takeException(), isNull);

      // Off by default → no date/time fields.
      expect(find.byType(SeparateDateTimeFields), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // On → the reused date/time component appears.
      expect(find.byType(SeparateDateTimeFields), findsOneWidget);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.byType(SeparateDateTimeFields), findsNothing);
    });
  });
}

/// Mirrors the dialog's follow-up section so the show/hide rule is testable
/// without a live Supabase session behind the full dialog.
class _FollowUpToggle extends StatefulWidget {
  @override
  State<_FollowUpToggle> createState() => _FollowUpToggleState();
}

class _FollowUpToggleState extends State<_FollowUpToggle> {
  bool _on = false;
  final _at = DateTime(2026, 7, 18, 10, 30);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Follow-up Required'),
          value: _on,
          onChanged: (v) => setState(() => _on = v),
        ),
        if (_on)
          SeparateDateTimeFields(
            value: _at,
            onEditDate: () async {},
            onEditTime: () async {},
          ),
      ],
    );
  }
}
