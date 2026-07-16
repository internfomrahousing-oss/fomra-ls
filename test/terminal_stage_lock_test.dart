import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/models/land_lead.dart';
import 'package:fomra_ls/services/land_lead_service.dart';

void main() {
  group('which stages are terminal', () {
    test('Signed and Dropped are terminal', () {
      expect(LeadStatus.signed.isTerminal, isTrue);
      expect(LeadStatus.dropped.isTerminal, isTrue);
    });

    test('every working stage is not terminal', () {
      for (final s in [
        LeadStatus.prospectMeetingPending,
        LeadStatus.prospectMeetingCompleted,
        LeadStatus.managementMeetingCompleted,
        LeadStatus.negotiation,
        LeadStatus.legal,
      ]) {
        expect(s.isTerminal, isFalse, reason: '$s should be editable');
      }
    });
  });

  group('the service refuses to move a terminal lead', () {
    test('a change from Signed is rejected before any DB call', () {
      expect(
        LandLeadService.updateStatus('1', LeadStatus.negotiation,
            previousStatus: LeadStatus.signed),
        throwsA(isA<StateError>()),
      );
    });

    test('a change from Dropped is rejected', () {
      expect(
        LandLeadService.updateStatus('1', LeadStatus.legal,
            previousStatus: LeadStatus.dropped),
        throwsA(isA<StateError>()),
      );
    });

    test('the rejection message names the terminal stage', () async {
      try {
        await LandLeadService.updateStatus('1', LeadStatus.legal,
            previousStatus: LeadStatus.signed);
        fail('should have thrown');
      } on StateError catch (e) {
        expect(e.message, contains('Signed'));
        expect(e.message, contains('can no longer be modified'));
      }
    });
  });
}
