import 'package:flutter_test/flutter_test.dart';

import 'package:fomra_ls/utils/lead_auto_notes.dart';

const _manual = '[1/7/2026 10:30] Owner wants to sell by Q4\n'
    '[2/7/2026 09:15] Called owner, no answer';

Map<String, List<NearbyFeature>> _nearby() => {
      'Water Bodies': const [
        NearbyFeature(name: 'Perumal Eri', distanceKm: 0.42),
      ],
      'Schools': const [
        NearbyFeature(name: 'Govt High School', distanceKm: 1.2),
        NearbyFeature(name: 'St Marys', distanceKm: 0.6),
      ],
      'Cemeteries': const [NearbyFeature(name: 'Unnamed', distanceKm: 0.9)],
    };

void main() {
  group('generate', () {
    test('emits a line per category that has something nearby', () {
      final lines = LeadAutoNotes.generate(_nearby(), radiusKm: 2);
      expect(lines, hasLength(3));
      expect(lines.every(LeadAutoNotes.isAutoLine), isTrue);
      expect(lines[0], contains('Water bodies'));
      expect(lines[1], contains('Schools'));
      expect(lines[2], contains('Cemetery'));
    });

    test('skips categories with nothing nearby', () {
      final lines = LeadAutoNotes.generate(
        {
          'Schools': const [NearbyFeature(name: 'A School', distanceKm: 1)],
        },
        radiusKm: 2,
      );
      expect(lines, hasLength(1));
      expect(lines.single, contains('Schools'));
    });

    test('orders names nearest first and merges a category\'s sources', () {
      final lines = LeadAutoNotes.generate({
        'Cemeteries': const [NearbyFeature(name: 'Far One', distanceKm: 1.8)],
        'Graveyards': const [NearbyFeature(name: 'Near One', distanceKm: 0.2)],
      }, radiusKm: 2);
      expect(lines.single, contains('Cemetery — 2 within 2 km'));
      expect(lines.single.indexOf('Near One'),
          lessThan(lines.single.indexOf('Far One')));
    });

    test('renders sub-kilometre distances in metres', () {
      final lines = LeadAutoNotes.generate({
        'Schools': const [NearbyFeature(name: 'Close', distanceKm: 0.42)],
      }, radiusKm: 2);
      expect(lines.single, contains('(420 m)'));
    });

    test('caps the names listed and counts the remainder', () {
      final lines = LeadAutoNotes.generate({
        'Schools': const [
          NearbyFeature(name: 'A', distanceKm: 0.1),
          NearbyFeature(name: 'B', distanceKm: 0.2),
          NearbyFeature(name: 'C', distanceKm: 0.3),
          NearbyFeature(name: 'D', distanceKm: 0.4),
          NearbyFeature(name: 'E', distanceKm: 0.5),
        ],
      }, radiusKm: 2);
      expect(lines.single, contains('Schools — 5 within 2 km'));
      expect(lines.single, contains('+2 more'));
      expect(lines.single, isNot(contains('D (')));
    });

    test('says so explicitly when nothing at all is nearby', () {
      final lines = LeadAutoNotes.generate(const {}, radiusKm: 2);
      expect(lines, hasLength(1));
      expect(lines.single, contains('No water bodies'));
      expect(LeadAutoNotes.isAutoLine(lines.single), isTrue);
    });
  });

  group('mergeInto', () {
    test('appends the auto block to manual notes', () {
      final merged = LeadAutoNotes.mergeInto(_manual, ['${LeadAutoNotes.marker} X']);
      expect(merged, startsWith(_manual));
      expect(merged, endsWith('${LeadAutoNotes.marker} X'));
    });

    test('leaves manual notes byte-identical', () {
      final merged = LeadAutoNotes.mergeInto(_manual, ['${LeadAutoNotes.marker} X']);
      expect(LeadAutoNotes.manualOnly(merged), _manual);
    });

    test('replaces a previous auto block instead of stacking them', () {
      final first = LeadAutoNotes.mergeInto(_manual, ['${LeadAutoNotes.marker} old']);
      final second =
          LeadAutoNotes.mergeInto(first, ['${LeadAutoNotes.marker} new']);
      expect(second, isNot(contains('old')));
      expect(second, contains('new'));
      expect(LeadAutoNotes.manualOnly(second), _manual);
    });

    test('is idempotent — unchanged surroundings return the same string', () {
      final lines = LeadAutoNotes.generate(_nearby(), radiusKm: 2);
      final once = LeadAutoNotes.mergeInto(_manual, lines);
      final twice = LeadAutoNotes.mergeInto(once, lines);
      expect(identical(twice, once), isTrue,
          reason: 'unchanged notes must be returned as-is so no write happens');
    });

    test('works on a lead with no notes at all', () {
      final merged = LeadAutoNotes.mergeInto('', ['${LeadAutoNotes.marker} X']);
      expect(merged, '${LeadAutoNotes.marker} X');
    });

    test('a manual note added after an auto block survives regeneration', () {
      final withAuto =
          LeadAutoNotes.mergeInto(_manual, ['${LeadAutoNotes.marker} old']);
      // The notes dialog appends new manual notes to the very end.
      final later = '$withAuto\n[3/7/2026 11:00] Site visit done';
      final regenerated =
          LeadAutoNotes.mergeInto(later, ['${LeadAutoNotes.marker} new']);
      expect(regenerated, contains('[3/7/2026 11:00] Site visit done'));
      expect(regenerated, contains('new'));
      expect(regenerated, isNot(contains('old')));
    });

    test('does not strip a manual note that merely mentions the word auto', () {
      const tricky = '[1/7/2026 10:30] Auto rickshaw access is poor';
      final merged =
          LeadAutoNotes.mergeInto(tricky, ['${LeadAutoNotes.marker} X']);
      expect(merged, contains('Auto rickshaw access is poor'));
    });
  });
}
