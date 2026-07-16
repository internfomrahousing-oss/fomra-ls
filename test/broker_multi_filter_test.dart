import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/models/land_lead.dart';
import 'package:fomra_ls/widgets/land_workspace_ui.dart';

LandLead _lead({String broker = '', String owner = 'O'}) => LandLead(
      leadId: 'L-$broker-$owner',
      inputSource: InputSource.broker,
      location: '',
      gpsCoordinates: '',
      village: '',
      taluk: '',
      district: '',
      pincode: '',
      surveyNumber: '',
      landExtent: '',
      ownerName: owner,
      contactDetails: '',
      brokerName: broker,
      landType: LandType.residential,
      roadWidth: '',
      accessDetails: '',
      notes: '',
      addedOn: DateTime(2026, 7, 1),
    );

void main() {
  group('multi-select broker filter (OR)', () {
    test('keeps leads whose broker is any of the selected', () {
      final f = LandWorkspaceFilters(brokers: {'Ravi', 'Kumar'});
      expect(f.matches(_lead(broker: 'Ravi')), isTrue);
      expect(f.matches(_lead(broker: 'Kumar')), isTrue);
      expect(f.matches(_lead(broker: 'Suresh')), isFalse);
    });

    test('is case-insensitive', () {
      final f = LandWorkspaceFilters(brokers: {'Ravi Kumar'});
      expect(f.matches(_lead(broker: 'ravi kumar')), isTrue);
    });

    test('an empty broker set applies no broker filter', () {
      final f = LandWorkspaceFilters(brokers: {});
      expect(f.matches(_lead(broker: 'Anyone')), isTrue);
      expect(f.matches(_lead(broker: '')), isTrue);
    });

    test('each selected broker counts toward the active filter total', () {
      final f = LandWorkspaceFilters(brokers: {'A', 'B', 'C'});
      expect(f.activeCount, 3);
    });

    test('active chips include one removable chip per broker', () {
      final f = LandWorkspaceFilters(brokers: {'A', 'B'});
      final chips = f.activeChips(() {});
      final brokerChips = chips.where((c) => c.label.startsWith('Broker: '));
      expect(brokerChips, hasLength(2));

      // Removing a chip drops just that broker.
      chips.firstWhere((c) => c.label == 'Broker: A').onRemove();
      expect(f.brokers, {'B'});
    });

    test('copy() carries the broker set independently', () {
      final f = LandWorkspaceFilters(brokers: {'A'});
      final c = f.copy();
      c.brokers.add('B');
      expect(f.brokers, {'A'}, reason: 'copy must not share the set');
      expect(c.brokers, {'A', 'B'});
    });

    test('clear() empties the broker set', () {
      final f = LandWorkspaceFilters(brokers: {'A', 'B'});
      f.clear();
      expect(f.brokers, isEmpty);
    });
  });

  group('the single-broker (Land Workspace) filter is unchanged', () {
    test('still matches on the single broker field', () {
      final f = LandWorkspaceFilters(broker: 'Ravi');
      expect(f.matches(_lead(broker: 'Ravi')), isTrue);
      expect(f.matches(_lead(broker: 'Other')), isFalse);
    });

    test('the two broker filters are independent', () {
      // Workspace uses `broker`; Broker page uses `brokers`. Neither leaks.
      final workspace = LandWorkspaceFilters(broker: 'Ravi');
      expect(workspace.brokers, isEmpty);
    });
  });
}
