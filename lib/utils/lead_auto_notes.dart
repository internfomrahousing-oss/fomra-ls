/// A nearby feature found around a lead's GPS point.
class NearbyFeature {
  final String name;

  /// Straight-line distance from the site, in km. Null when the source had no
  /// coordinates for the feature.
  final double? distanceKm;

  const NearbyFeature({required this.name, this.distanceKm});
}

/// Builds and merges the automatic "nearby features" notes on a lead.
///
/// Auto notes are ordinary lines in [LandLead.notes], each prefixed with
/// [marker]. Regenerating replaces only the marked lines, so anything an
/// executive typed by hand is left exactly as it was.
///
/// The lines carry no timestamp on purpose: they describe what is currently
/// near the site rather than an event, which also makes regeneration idempotent
/// — re-running with unchanged surroundings produces byte-identical notes, so
/// [mergeInto] can be used to decide whether a write is needed at all.
abstract final class LeadAutoNotes {
  static const marker = '[Auto · Nearby]';

  /// Feature categories surfaced in the notes, in display order. Each entry
  /// maps a note label to the source categories that feed it — Cemetery merges
  /// OSM's two taggings, and Water Bodies covers standing and flowing water.
  static const categories = <({String label, List<String> sources})>[
    (label: 'Water bodies', sources: ['Water Bodies', 'Rivers & Canals']),
    (label: 'Schools', sources: ['Schools']),
    (label: 'Cemetery', sources: ['Cemeteries', 'Graveyards']),
    (label: 'Hospitals', sources: ['Hospitals']),
    (label: 'Bus stops', sources: ['Bus Stops', 'Bus Terminals']),
    (label: 'Railway stations', sources: ['Railway Stations']),
    (label: 'Worship places', sources: ['Worship Places']),
  ];

  static bool isAutoLine(String line) => line.trimLeft().startsWith(marker);

  static String _distance(double? km) {
    if (km == null) return '';
    if (km < 1) return ' (${(km * 1000).round()} m)';
    return ' (${km.toStringAsFixed(1)} km)';
  }

  /// The auto-note lines for [byCategory], keyed by the source category names
  /// the POI service returns. Categories with nothing nearby are skipped, so a
  /// site with no cemetery simply has no cemetery line.
  static List<String> generate(
    Map<String, List<NearbyFeature>> byCategory, {
    required int radiusKm,
    int maxNamesPerLine = 3,
  }) {
    final lines = <String>[];

    for (final category in categories) {
      final found = <NearbyFeature>[
        for (final source in category.sources) ...?byCategory[source],
      ]..sort((a, b) =>
          (a.distanceKm ?? double.infinity)
              .compareTo(b.distanceKm ?? double.infinity));

      if (found.isEmpty) continue;

      final shown = found.take(maxNamesPerLine).map((f) {
        final name = f.name.trim().isEmpty ? 'Unnamed' : f.name.trim();
        return '$name${_distance(f.distanceKm)}';
      }).join(', ');

      final more = found.length - maxNamesPerLine;
      final suffix = more > 0 ? ', +$more more' : '';
      lines.add(
        '$marker ${category.label} — ${found.length} within $radiusKm km: '
        '$shown$suffix',
      );
    }

    if (lines.isEmpty) {
      lines.add(
        '$marker No water bodies, schools, cemetery or other mapped features '
        'found within $radiusKm km of the site.',
      );
    }
    return lines;
  }

  /// [existingNotes] with every auto line replaced by [autoLines]. Manual notes
  /// keep their original text and order; the auto block always sits at the end.
  ///
  /// Returns [existingNotes] unchanged when the auto block already matches, so
  /// callers can compare identity to skip a pointless write.
  static String mergeInto(String existingNotes, List<String> autoLines) {
    final manual = existingNotes
        .split('\n')
        .where((l) => !isAutoLine(l))
        .toList();

    // Drop trailing blank lines left behind by a removed auto block.
    while (manual.isNotEmpty && manual.last.trim().isEmpty) {
      manual.removeLast();
    }

    final merged = [...manual, ...autoLines].join('\n');
    return merged == existingNotes ? existingNotes : merged;
  }

  /// The manual-only portion, for callers that need to show or diff it.
  static String manualOnly(String notes) => notes
      .split('\n')
      .where((l) => !isAutoLine(l))
      .join('\n')
      .trimRight();
}
