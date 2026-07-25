/// A nearby feature found around a lead's GPS point.
class NearbyFeature {
  final String name;

  /// Straight-line distance from the site, in km. Null when the source had no
  /// coordinates for the feature.
  final double? distanceKm;

  const NearbyFeature({required this.name, this.distanceKm});
}

/// Builds and merges the automatic "nearby features" note on a lead.
///
/// All categories live in a **single** block inside [LandLead.notes], opened by
/// [marker], so the Activity Timeline shows one auto-generated note rather than
/// one per category. Regenerating replaces only that block, so anything an
/// executive typed by hand is left exactly as it was.
///
/// The block carries no timestamp on purpose: it describes what is currently
/// near the site rather than an event, which also makes regeneration idempotent
/// — re-running with unchanged surroundings produces a byte-identical string, so
/// [mergeInto] can be used to decide whether a write is needed at all.
abstract final class LeadAutoNotes {
  /// Opens the block, and is how it is recognised in [LandLead.notes].
  static const marker = '[Location Intelligence]';

  /// The previous block header, still recognised so a lead written by the old
  /// code has its block replaced in place rather than duplicated.
  static const _legacyBlockMarker = '[Auto Generated Nearby Information]';

  /// The pre-consolidation format: one marked line per category. Still stripped
  /// on merge, so a lead written by the old code picks up the single block.
  static const legacyMarker = '[Auto · Nearby]';

  /// Feature categories surfaced in the note, in display order. Each entry maps
  /// a heading to the source categories that feed it — Cemetery merges OSM's two
  /// taggings, and Water Bodies covers standing and flowing water.
  static const categories = <({String label, List<String> sources})>[
    (label: 'Water Bodies', sources: ['Water Bodies', 'Rivers & Canals']),
    (label: 'Schools', sources: ['Schools']),
    (label: 'Cemetery', sources: ['Cemeteries', 'Graveyards']),
    (label: 'Hospitals', sources: ['Hospitals']),
    (label: 'Bus Stops', sources: ['Bus Stops', 'Bus Terminals']),
    (label: 'Railway Stations', sources: ['Railway Stations']),
    (label: 'Places of Worship', sources: ['Worship Places']),
  ];

  /// Whether [entry] is the auto-generated note (or its opening line) — the
  /// current header or the legacy one, so old blocks are still recognised.
  static bool isAutoEntry(String entry) {
    final t = entry.trimLeft();
    return t.startsWith(marker) || t.startsWith(_legacyBlockMarker);
  }

  static bool _isLegacyAutoLine(String line) =>
      line.trimLeft().startsWith(legacyMarker);

  static final _bullet = RegExp(r'^\s*•\s');
  static final _heading = RegExp(r'^\s*[A-Za-z][A-Za-z &]*:\s*$');

  /// Whether [line] continues the block opened above it. Only the shapes
  /// [generate] emits qualify, so a manual note written after the block ends it
  /// rather than being swallowed by it.
  static bool _isBlockBody(String line) =>
      line.trim().isEmpty || _bullet.hasMatch(line) || _heading.hasMatch(line);

  static String _distance(double? km) {
    if (km == null) return '';
    if (km < 1) return ' (${(km * 1000).round()} m)';
    return ' (${km.toStringAsFixed(1)} km)';
  }

  /// The single auto-generated note for [byCategory], keyed by the source
  /// category names the POI service returns. Categories with nothing nearby are
  /// skipped, so a site with no cemetery simply has no Cemetery heading.
  static String generate(
    Map<String, List<NearbyFeature>> byCategory, {
    required int radiusKm,
    int maxNamesPerCategory = 3,
  }) {
    final sections = <String>[];

    for (final category in categories) {
      final found = <NearbyFeature>[
        for (final source in category.sources) ...?byCategory[source],
      ]..sort((a, b) => (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity));

      if (found.isEmpty) continue;

      final bullets = found.take(maxNamesPerCategory).map((f) {
        final name = f.name.trim().isEmpty ? 'Unnamed' : f.name.trim();
        return '• $name${_distance(f.distanceKm)}';
      }).toList();

      final more = found.length - maxNamesPerCategory;
      if (more > 0) bullets.add('• +$more more');

      sections.add('${category.label}:\n${bullets.join('\n')}');
    }

    if (sections.isEmpty) {
      // A bullet, so the line reads as part of the block like any other.
      sections.add('• No mapped features found within $radiusKm km of the site.');
    }

    return '$marker\n\n${sections.join('\n\n')}';
  }

  /// [existingNotes] with any previous auto block replaced by [autoBlock].
  /// Manual notes keep their original text and order; the block always sits at
  /// the end, so a moved site updates the note in place instead of adding one.
  ///
  /// Returns [existingNotes] unchanged when the block already matches, so
  /// callers can compare identity to skip a pointless write.
  static String mergeInto(String existingNotes, String autoBlock) {
    final manual = manualOnly(existingNotes);
    final merged = manual.isEmpty ? autoBlock : '$manual\n$autoBlock';
    return merged == existingNotes ? existingNotes : merged;
  }

  /// The manual-only portion, for callers that need to show or diff it.
  static String manualOnly(String notes) {
    final kept = <String>[];
    var inBlock = false;

    for (final line in notes.split('\n')) {
      if (isAutoEntry(line)) {
        inBlock = true;
        continue;
      }
      if (inBlock) {
        if (_isBlockBody(line)) continue;
        inBlock = false;
      }
      if (_isLegacyAutoLine(line)) continue;
      kept.add(line);
    }

    // Drop trailing blank lines left behind by a removed block.
    while (kept.isNotEmpty && kept.last.trim().isEmpty) {
      kept.removeLast();
    }
    return kept.join('\n').trimRight();
  }

  /// [notes] split into entries for display, with the whole auto block kept
  /// together as one entry. Every other line is its own entry, as before.
  static List<String> splitEntries(String notes) {
    final entries = <String>[];
    List<String>? block;

    void flush() {
      final current = block;
      if (current == null) return;
      while (current.isNotEmpty && current.last.trim().isEmpty) {
        current.removeLast();
      }
      entries.add(current.join('\n'));
      block = null;
    }

    for (final line in notes.split('\n')) {
      if (isAutoEntry(line)) {
        flush();
        block = [line.trim()];
        continue;
      }
      if (block != null) {
        if (_isBlockBody(line)) {
          block!.add(line.trimRight());
          continue;
        }
        flush();
      }
      if (line.trim().isEmpty) continue;
      entries.add(line.trim());
    }
    flush();

    return entries;
  }
}
