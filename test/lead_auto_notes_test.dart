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
    test('puts every category in a single block, not one note each', () {
      final block = LeadAutoNotes.generate(_nearby(), radiusKm: 2);

      expect(block, startsWith(LeadAutoNotes.marker));
      expect(LeadAutoNotes.splitEntries(block), hasLength(1));
      expect(block, contains('Water Bodies:'));
      expect(block, contains('Schools:'));
      expect(block, contains('Cemetery:'));
    });

    test('lists features as bullets under their heading', () {
      final block = LeadAutoNotes.generate({
        'Schools': const [NearbyFeature(name: 'St Marys', distanceKm: 0.6)],
      }, radiusKm: 2);

      expect(block, contains('Schools:\n• St Marys (600 m)'));
    });

    test('keeps the categories in display order', () {
      final block = LeadAutoNotes.generate(_nearby(), radiusKm: 2);
      expect(block.indexOf('Water Bodies:'), lessThan(block.indexOf('Schools:')));
      expect(block.indexOf('Schools:'), lessThan(block.indexOf('Cemetery:')));
    });

    test('skips categories with nothing nearby', () {
      final block = LeadAutoNotes.generate({
        'Schools': const [NearbyFeature(name: 'A School', distanceKm: 1)],
      }, radiusKm: 2);

      expect(block, contains('Schools:'));
      expect(block, isNot(contains('Cemetery:')));
      expect(block, isNot(contains('Hospitals:')));
    });

    test('orders names nearest first and merges a category\'s sources', () {
      final block = LeadAutoNotes.generate({
        'Cemeteries': const [NearbyFeature(name: 'Far One', distanceKm: 1.8)],
        'Graveyards': const [NearbyFeature(name: 'Near One', distanceKm: 0.2)],
      }, radiusKm: 2);

      expect(block.indexOf('Near One'), lessThan(block.indexOf('Far One')));
    });

    test('renders sub-kilometre distances in metres, longer ones in km', () {
      final block = LeadAutoNotes.generate({
        'Schools': const [NearbyFeature(name: 'Close', distanceKm: 0.42)],
        'Hospitals': const [NearbyFeature(name: 'Far', distanceKm: 1.34)],
      }, radiusKm: 2);

      expect(block, contains('• Close (420 m)'));
      expect(block, contains('• Far (1.3 km)'));
    });

    test('caps the names listed and counts the remainder', () {
      final block = LeadAutoNotes.generate({
        'Schools': const [
          NearbyFeature(name: 'A', distanceKm: 0.1),
          NearbyFeature(name: 'B', distanceKm: 0.2),
          NearbyFeature(name: 'C', distanceKm: 0.3),
          NearbyFeature(name: 'D', distanceKm: 0.4),
          NearbyFeature(name: 'E', distanceKm: 0.5),
        ],
      }, radiusKm: 2);

      expect(block, contains('• +2 more'));
      expect(block, isNot(contains('• D (')));
    });

    test('names an unnamed feature rather than showing a blank bullet', () {
      final block = LeadAutoNotes.generate({
        'Water Bodies': const [NearbyFeature(name: '  ', distanceKm: 1.3)],
      }, radiusKm: 2);

      expect(block, contains('• Unnamed (1.3 km)'));
    });

    test('says so explicitly when nothing at all is nearby', () {
      final block = LeadAutoNotes.generate(const {}, radiusKm: 2);

      expect(LeadAutoNotes.isAutoEntry(block), isTrue);
      expect(block, contains('No mapped features found within 2 km'));
      expect(LeadAutoNotes.splitEntries(block), hasLength(1));
    });
  });

  group('mergeInto', () {
    String block(String label) => '${LeadAutoNotes.marker}\n\n$label:\n• X (100 m)';

    test('appends the block to manual notes', () {
      final merged = LeadAutoNotes.mergeInto(_manual, block('Schools'));
      expect(merged, startsWith(_manual));
      expect(merged, endsWith('• X (100 m)'));
    });

    test('leaves manual notes byte-identical', () {
      final merged = LeadAutoNotes.mergeInto(_manual, block('Schools'));
      expect(LeadAutoNotes.manualOnly(merged), _manual);
    });

    test('replaces the previous block instead of stacking them', () {
      final first = LeadAutoNotes.mergeInto(_manual, block('Schools'));
      final second = LeadAutoNotes.mergeInto(first, block('Hospitals'));

      expect(second, isNot(contains('Schools')));
      expect(second, contains('Hospitals'));
      expect(LeadAutoNotes.manualOnly(second), _manual);
      // Still exactly one auto note, not two.
      expect(
        LeadAutoNotes.splitEntries(second).where(LeadAutoNotes.isAutoEntry),
        hasLength(1),
      );
    });

    test('a moved site updates the note in place rather than adding one', () {
      final before = LeadAutoNotes.mergeInto(
        _manual,
        LeadAutoNotes.generate(_nearby(), radiusKm: 2),
      );
      final after = LeadAutoNotes.mergeInto(
        before,
        LeadAutoNotes.generate({
          'Hospitals': const [NearbyFeature(name: 'New Clinic', distanceKm: 0.1)],
        }, radiusKm: 2),
      );

      expect(after, contains('New Clinic'));
      expect(after, isNot(contains('Perumal Eri')));
      expect(
        LeadAutoNotes.splitEntries(after).where(LeadAutoNotes.isAutoEntry),
        hasLength(1),
      );
    });

    test('is idempotent — unchanged surroundings return the same string', () {
      final generated = LeadAutoNotes.generate(_nearby(), radiusKm: 2);
      final once = LeadAutoNotes.mergeInto(_manual, generated);
      final twice = LeadAutoNotes.mergeInto(once, generated);

      expect(identical(twice, once), isTrue,
          reason: 'unchanged notes must be returned as-is so no write happens');
    });

    test('works on a lead with no notes at all', () {
      final merged = LeadAutoNotes.mergeInto('', block('Schools'));
      expect(merged, block('Schools'));
    });

    test('a manual note added after the block survives regeneration', () {
      final withAuto = LeadAutoNotes.mergeInto(_manual, block('Schools'));
      // The notes dialog appends new manual notes to the very end.
      final later = '$withAuto\n[3/7/2026 11:00] Site visit done';
      final regenerated = LeadAutoNotes.mergeInto(later, block('Hospitals'));

      expect(regenerated, contains('[3/7/2026 11:00] Site visit done'));
      expect(regenerated, contains('Hospitals'));
      expect(regenerated, isNot(contains('Schools')));
    });

    test('does not strip a manual note that merely mentions the word auto', () {
      const tricky = '[1/7/2026 10:30] Auto rickshaw access is poor';
      final merged = LeadAutoNotes.mergeInto(tricky, block('Schools'));
      expect(merged, contains('Auto rickshaw access is poor'));
    });

    test('replaces the old one-line-per-category format', () {
      const legacy = '$_manual\n'
          '${LeadAutoNotes.legacyMarker} Water bodies — 1 within 2 km: Eri (400 m)\n'
          '${LeadAutoNotes.legacyMarker} Schools — 1 within 2 km: St Marys (600 m)';

      final merged = LeadAutoNotes.mergeInto(legacy, block('Hospitals'));

      expect(merged, isNot(contains(LeadAutoNotes.legacyMarker)));
      expect(LeadAutoNotes.manualOnly(merged), _manual);
      expect(
        LeadAutoNotes.splitEntries(merged).where(LeadAutoNotes.isAutoEntry),
        hasLength(1),
      );
    });
  });

  group('splitEntries', () {
    test('keeps the whole block as one entry beside manual notes', () {
      final notes = LeadAutoNotes.mergeInto(
        _manual,
        LeadAutoNotes.generate(_nearby(), radiusKm: 2),
      );
      final entries = LeadAutoNotes.splitEntries(notes);

      // Two manual notes + exactly one auto note.
      expect(entries, hasLength(3));
      expect(entries.where(LeadAutoNotes.isAutoEntry), hasLength(1));
      expect(entries.last, contains('Water Bodies:'));
      expect(entries.last, contains('Cemetery:'));
    });

    test('a manual note after the block stays its own entry', () {
      final notes = '${LeadAutoNotes.mergeInto(_manual, LeadAutoNotes.generate(_nearby(), radiusKm: 2))}\n'
          '[3/7/2026 11:00] Site visit done';
      final entries = LeadAutoNotes.splitEntries(notes);

      expect(entries.last, '[3/7/2026 11:00] Site visit done');
      expect(entries.where(LeadAutoNotes.isAutoEntry), hasLength(1));
    });

    test('leaves notes without an auto block one entry per line', () {
      expect(LeadAutoNotes.splitEntries(_manual), hasLength(2));
    });

    test('is empty for a lead with no notes', () {
      expect(LeadAutoNotes.splitEntries(''), isEmpty);
    });
  });
}
