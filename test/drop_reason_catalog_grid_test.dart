import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fomra_ls/models/lead_drop_reason.dart';
import 'package:fomra_ls/services/lead_drop_reason_catalog_service.dart';
import 'package:fomra_ls/widgets/drop_reason_catalog_grid.dart';

final _catalog = LeadDropReasonCatalogService.instance;

List<String> get _labels => _catalog.current.map((r) => r.label).toList();

Future<void> _seed(List<String> labels) => _catalog.setItems([
      for (final l in labels) LeadDropReason(id: l.toLowerCase(), label: l),
    ]);

/// Drag the card at [from] onto the card at [to], exactly as the grid does.
Future<void> _dropOnto(int from, int to) =>
    _catalog.reorder(from, dropReasonReorderNewIndex(from, to));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await _seed(['A', 'B', 'C', 'D']);
  });

  group('dropping a card lands it exactly where it was dropped', () {
    test('dragging forward', () async {
      await _dropOnto(0, 2); // A onto C's slot
      expect(_labels, ['B', 'C', 'A', 'D']);
      expect(_labels.indexOf('A'), 2);
    });

    test('dragging backward', () async {
      await _dropOnto(3, 1); // D onto B's slot
      expect(_labels, ['A', 'D', 'B', 'C']);
      expect(_labels.indexOf('D'), 1);
    });

    test('dragging to the very end', () async {
      await _dropOnto(0, 3);
      expect(_labels, ['B', 'C', 'D', 'A']);
    });

    test('dragging to the very start', () async {
      await _dropOnto(3, 0);
      expect(_labels, ['D', 'A', 'B', 'C']);
    });

    test('adjacent swap forward', () async {
      await _dropOnto(0, 1);
      expect(_labels, ['B', 'A', 'C', 'D']);
    });

    test('adjacent swap backward', () async {
      await _dropOnto(1, 0);
      expect(_labels, ['B', 'A', 'C', 'D']);
    });

    test('every card survives a reorder', () async {
      await _dropOnto(1, 3);
      expect(_labels..sort(), ['A', 'B', 'C', 'D']);
    });
  });

  group('dropReasonReorderNewIndex', () {
    test('nudges forward drags past the gap the lifted card leaves', () {
      expect(dropReasonReorderNewIndex(0, 2), 3);
    });

    test('leaves backward drags alone', () {
      expect(dropReasonReorderNewIndex(3, 1), 1);
    });
  });

  test('reordering does not touch labels or slugs', () async {
    final before = _catalog.current.map((r) => '${r.id}|${r.label}').toSet();
    await _dropOnto(0, 3);
    final after = _catalog.current.map((r) => '${r.id}|${r.label}').toSet();
    expect(after, before);
  });
}
