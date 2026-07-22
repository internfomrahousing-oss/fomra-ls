import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../config/maptiler_tiles.dart';
import '../../models/land_lead.dart';
import '../../services/lead_visibility.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../utils/lead_location_parser.dart';
import '../../utils/maps_navigation.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/lead_portfolio_breakdown.dart';
import '../../widgets/portal_page_layout.dart';
import 'lead_detail_screen.dart';

class _PlottedLead {
  final LandLead lead;
  final LatLng point;

  const _PlottedLead({required this.lead, required this.point});
}

class LeadsMapScreen extends StatefulWidget {
  final List<LandLead> leads;

  const LeadsMapScreen({super.key, required this.leads});

  @override
  State<LeadsMapScreen> createState() => _LeadsMapScreenState();
}

class _LeadsMapScreenState extends State<LeadsMapScreen> {
  final MapController _mapController = MapController();
  bool _mapReady = false;

  /// The pin whose compact details card is shown on the map (null = none).
  _PlottedLead? _selectedPin;

  // ── Filters ────────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  String _search = '';
  final Set<LeadStatus> _stages = {};
  String? _executive;
  String? _broker;
  DateTimeRange? _dateRange;

  /// Filters excluding the free-text search — drives the "Filters" badge.
  bool get _hasFieldFilters =>
      _stages.isNotEmpty ||
      _executive != null ||
      _broker != null ||
      _dateRange != null;

  bool get _hasActiveFilters => _hasFieldFilters || _search.trim().isNotEmpty;

  void _clearFilters() {
    _search = '';
    _searchCtrl.clear();
    _stages.clear();
    _executive = null;
    _broker = null;
    _dateRange = null;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Role-scoped source leads: an executive only ever sees the sites assigned
  /// to / created by them, and a Reporting Manager / Head sees their team or
  /// just themselves per the header toggle — even if the caller passed a
  /// broader list. Management sees everything. This enforces the access rule at
  /// the map itself.
  List<LandLead> get _scopedLeads => LeadVisibility.scope(widget.leads);

  List<String> _distinct(String Function(LandLead) selector) {
    final set = <String>{};
    for (final l in _scopedLeads) {
      final v = selector(l).trim();
      if (v.isNotEmpty) set.add(v);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<LandLead> get _filteredLeads {
    final q = _search.trim().toLowerCase();
    return _scopedLeads.where((l) {
      if (_stages.isNotEmpty && !_stages.contains(l.status)) return false;
      if (_executive != null && l.createdByName.trim() != _executive) {
        return false;
      }
      if (_broker != null && l.brokerName.trim() != _broker) return false;
      if (_dateRange != null) {
        final d = DateTime(l.addedOn.year, l.addedOn.month, l.addedOn.day);
        if (d.isBefore(_dateRange!.start) || d.isAfter(_dateRange!.end)) {
          return false;
        }
      }
      if (q.isNotEmpty) {
        final match = <String>[
          l.ownerName,
          l.surveyNumber,
          l.village,
          l.brokerName,
          l.leadId,
        ].any((f) => f.toLowerCase().contains(q));
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  List<_PlottedLead> _plottedFrom(List<LandLead> leads) {
    final out = <_PlottedLead>[];
    for (final lead in leads) {
      final point = parseLeadGps(lead.gpsCoordinates);
      if (point != null) out.add(_PlottedLead(lead: lead, point: point));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLeads;
    final plotted = _plottedFrom(filtered);
    final totalAcres =
        filtered.fold<double>(0, (s, l) => s + leadPortfolioAcres(l));
    final missingGps = filtered.length - plotted.length;

    // Initial view uses the full (unfiltered) set so the camera is stable.
    final allPlotted = _plottedFrom(_scopedLeads);
    final initialView =
        allPlotted.isEmpty ? null : _computeCenterAndZoom(allPlotted);

    return FomraAppShell(
      currentRoute: '/land-lead',
      appBar: FomraSubPageAppBar(
        title: 'Project Map',
        // Compact KPI chips sit inline with the title in the header, so the
        // body — and therefore the map — keeps its full height.
        actions: allPlotted.isEmpty
            ? null
            : [
                _headerKpi(
                    '${filtered.length}', 'Sites', Icons.place_outlined),
                const SizedBox(width: 8),
                _headerKpi(totalAcres.toStringAsFixed(2), 'Acres',
                    Icons.landscape_outlined),
                const SizedBox(width: 12),
              ],
      ),
      body: allPlotted.isEmpty
          ? _buildEmpty(context)
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final map = _buildMap(context, plotted, initialView, missingGps);
                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 320,
                        child: _sidePanel(context),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: map),
                    ],
                  );
                }
                return Column(
                  children: [
                    _compactSearchBar(context),
                    Expanded(child: map),
                  ],
                );
              },
            ),
    );
  }

  // ── Header KPI chip (rendered on the gradient app bar) ─────────────────────
  Widget _headerKpi(String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Map ──────────────────────────────────────────────────────────────────
  Widget _buildMap(
    BuildContext context,
    List<_PlottedLead> plotted,
    (LatLng, double)? initialView,
    int missingGps,
  ) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialView!.$1,
            initialZoom: initialView.$2,
            onMapReady: () => setState(() => _mapReady = true),
          ),
          children: [
            TileLayer(
              urlTemplate: MapTilerTiles.standard,
              fallbackUrl: MapTilerTiles.standardFallback,
              userAgentPackageName: 'in.fomrahousing.fomrals',
              maxZoom: 22,
            ),
            MarkerLayer(
              markers: [
                ...plotted.map((p) {
                final color = p.lead.status.color;
                return Marker(
                  point: p.point,
                  width: 44,
                  height: 52,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedPin = p),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            p.lead.leadId.length > 8
                                ? p.lead.leadId
                                    .substring(p.lead.leadId.length - 6)
                                : p.lead.leadId,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(Icons.location_on, color: color, size: 36),
                      ],
                    ),
                  ),
                );
                }),
                // A small details card anchored just above the tapped pin. As a
                // marker it stays pinned to the location while the map moves.
                if (_selectedPin != null)
                  Marker(
                    point: _selectedPin!.point,
                    width: 226,
                    height: 150,
                    // Anchor the card's bottom to the pin so it floats above it.
                    alignment: Alignment.bottomCenter,
                    child: _PropertyPopup(
                      lead: _selectedPin!.lead,
                      onOpenSite: () => _openLead(context, _selectedPin!.lead),
                      onClose: () => setState(() => _selectedPin = null),
                    ),
                  ),
              ],
            ),
          ],
        ),
        if (missingGps > 0)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Material(
              color: context.fomraSurface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              elevation: 2,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  '$missingGps matching site${missingGps == 1 ? '' : 's'} '
                  'without GPS — not shown on the map.',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.fomraTextSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ),
        // The status legend hides while a pin's details are open.
        if (_selectedPin == null)
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Material(
            color: context.fomraSurface.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                children: leadStatusPipelineOrder
                    .map((s) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, size: 14, color: s.color),
                            const SizedBox(width: 4),
                            Text(
                              s.label,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.fomraTextSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
        if (!_mapReady) const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  // ── Wide side panel: sticky search + scrollable filters ────────────────────
  Widget _sidePanel(BuildContext context) {
    return Material(
      color: context.fomraSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search stays pinned while the filter list scrolls beneath it.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: _searchField(context, (fn) => setState(fn)),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              children: [
                _filterControls(context, (fn) => setState(fn)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow: sticky search + Filters button (opens slide-over drawer) ───────
  Widget _compactSearchBar(BuildContext context) {
    return Material(
      color: context.fomraSurface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(child: _searchField(context, (fn) => setState(fn))),
            const SizedBox(width: 8),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: _openFilterDrawer,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Badge(
                  isLabelVisible: _hasFieldFilters,
                  child: const Icon(Icons.tune_rounded, size: 18),
                ),
                label: const Text('Filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Mobile filter panel as a right-side slide-over drawer.
  void _openFilterDrawer() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Filters',
      barrierColor: Colors.black.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, _, __) {
        final width =
            math.min(360.0, MediaQuery.sizeOf(ctx).width * 0.86);
        return Align(
          alignment: Alignment.centerRight,
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              void apply(VoidCallback fn) {
                setState(fn);
                setSheet(() {});
              }

              return Material(
                color: context.fomraSurface,
                child: SizedBox(
                  width: width,
                  height: double.infinity,
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                          child: Row(
                            children: [
                              Text(
                                'Filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: context.fomraTextPrimary,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: () => Navigator.pop(ctx),
                                icon: const Icon(Icons.close_rounded),
                                tooltip: 'Close',
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView(
                            padding:
                                const EdgeInsets.fromLTRB(20, 16, 20, 28),
                            children: [
                              _filterControls(context, apply),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        );
      },
    );
  }

  // ── Search field (leading icon; owner / survey / village / broker / ID) ────
  Widget _searchField(
    BuildContext context,
    void Function(VoidCallback) apply,
  ) {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => apply(() => _search = v),
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 13, color: context.fomraTextPrimary),
        decoration: InputDecoration(
          hintText: 'Search owner, survey, village, broker, ID',
          hintStyle: TextStyle(
            fontSize: 13,
            color: context.fomraTextSecondary.withValues(alpha: 0.8),
          ),
          isDense: true,
          filled: true,
          fillColor: context.fomraSurfaceVar,
          prefixIcon: Icon(Icons.search_rounded,
              size: 18, color: context.fomraTextSecondary),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 36, minHeight: 36),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  splashRadius: 18,
                  onPressed: () => apply(() {
                    _search = '';
                    _searchCtrl.clear();
                  }),
                ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── Filter controls (shared by side panel + slide-over drawer) ─────────────
  Widget _filterControls(
    BuildContext context,
    void Function(VoidCallback) apply,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section title with the "Clear all" aligned neatly on the same row.
        Row(
          children: [
            Text(
              'Site Stage',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: context.fomraTextSecondary,
              ),
            ),
            const Spacer(),
            if (_hasActiveFilters)
              TextButton(
                onPressed: () => apply(_clearFilters),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Clear all',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in leadStatusPipelineOrder)
              _stageChip(context, s, apply),
          ],
        ),
        const SizedBox(height: 14),
        _dropdown(context, 'Assigned Executive', _executive,
            _distinct((l) => l.createdByName), (v) => apply(() => _executive = v)),
        const SizedBox(height: 10),
        _dropdown(context, 'Broker', _broker, _distinct((l) => l.brokerName),
            (v) => apply(() => _broker = v)),
        const SizedBox(height: 10),
        _dateField(context, apply),
      ],
    );
  }

  // Compact stage chip — reduced height, selected highlight uses status color.
  Widget _stageChip(
    BuildContext context,
    LeadStatus s,
    void Function(VoidCallback) apply,
  ) {
    final selected = _stages.contains(s);
    return FilterChip(
      label: Text(s.label),
      selected: selected,
      showCheckmark: false,
      onSelected: (v) =>
          apply(() => v ? _stages.add(s) : _stages.remove(s)),
      backgroundColor: context.fomraSurfaceVar,
      selectedColor: s.color.withValues(alpha: 0.18),
      side: BorderSide(
        color: selected ? s.color : context.fomraBorder,
        width: selected ? 1.4 : 1,
      ),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color: selected ? s.color : context.fomraTextSecondary,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
      isDense: true,
      filled: true,
      fillColor: context.fomraSurfaceVar,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _dropdown(
    BuildContext context,
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButtonFormField<String?>(
      key: ValueKey('$label-${value ?? 'all'}'),
      initialValue: value,
      isExpanded: true,
      style: TextStyle(fontSize: 13, color: context.fomraTextPrimary),
      decoration: _fieldDecoration(context, label: label),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('All')),
        for (final o in options)
          DropdownMenuItem<String?>(value: o, child: Text(o)),
      ],
      onChanged: onChanged,
    );
  }

  // Compact outlined date field with a calendar icon — matches the dropdowns.
  Widget _dateField(
    BuildContext context,
    void Function(VoidCallback) apply,
  ) {
    final df = DateFormat('dd MMM yyyy');
    final hasRange = _dateRange != null;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final now = DateTime.now();
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 1),
          initialDateRange: _dateRange,
        );
        if (range != null) apply(() => _dateRange = range);
      },
      child: InputDecorator(
        decoration: _fieldDecoration(
          context,
          label: 'Date added',
          prefixIcon: Icon(Icons.calendar_today_outlined,
              size: 16, color: context.fomraTextSecondary),
          suffixIcon: hasRange
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  splashRadius: 18,
                  onPressed: () => apply(() => _dateRange = null),
                )
              : null,
        ),
        child: Text(
          hasRange
              ? '${df.format(_dateRange!.start)} – ${df.format(_dateRange!.end)}'
              : 'Any date',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: hasRange
                ? context.fomraTextPrimary
                : context.fomraTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined,
                size: 56, color: AppColors.primary.withValues(alpha: 0.35)),
            const SizedBox(height: 16),
            Text(
              'No sites with GPS coordinates',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.fomraTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add GPS when creating sites (tap the map in Add Site) '
              'so they appear here as pinned locations.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.fomraTextSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  (LatLng, double) _computeCenterAndZoom(List<_PlottedLead> plotted) {
    if (plotted.length == 1) {
      return (plotted.first.point, 15);
    }

    var minLat = plotted.first.point.latitude;
    var maxLat = minLat;
    var minLng = plotted.first.point.longitude;
    var maxLng = minLng;

    for (final p in plotted) {
      minLat = minLat < p.point.latitude ? minLat : p.point.latitude;
      maxLat = maxLat > p.point.latitude ? maxLat : p.point.latitude;
      minLng = minLng < p.point.longitude ? minLng : p.point.longitude;
      maxLng = maxLng > p.point.longitude ? maxLng : p.point.longitude;
    }

    final center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    final latSpan = (maxLat - minLat).abs();
    final lngSpan = (maxLng - minLng).abs();
    final span = latSpan > lngSpan ? latSpan : lngSpan;

    double zoom;
    if (span > 2) {
      zoom = 7;
    } else if (span > 1) {
      zoom = 8;
    } else if (span > 0.5) {
      zoom = 9;
    } else if (span > 0.2) {
      zoom = 10;
    } else if (span > 0.08) {
      zoom = 11;
    } else if (span > 0.03) {
      zoom = 12;
    } else {
      zoom = 13;
    }

    return (center, zoom);
  }

  /// Navigate directly to the Land Lead Details page for the tapped site,
  /// matching the standard lead-detail navigation used across the app. The
  /// selected lead is passed by value so it loads immediately; role-based
  /// visibility is already enforced upstream (only scoped pins are shown).
  void _openLead(BuildContext context, LandLead lead) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
    );
  }

}

String _siteName(LandLead l) {
  if (l.location.trim().isNotEmpty) return l.location.trim();
  final parts = <String>[
    if (l.surveyNumber.trim().isNotEmpty) 'Survey ${l.surveyNumber.trim()}',
    if (l.village.trim().isNotEmpty) l.village.trim(),
  ];
  if (parts.isNotEmpty) return parts.join(' · ');
  if (l.taluk.trim().isNotEmpty) return l.taluk.trim();
  if (l.district.trim().isNotEmpty) return l.district.trim();
  return 'Site #${l.leadId}';
}

/// Small pin-tap details card, shown on the map near the tapped pin (rendered
/// as a marker so it stays anchored to the location while the map moves).
class _PropertyPopup extends StatelessWidget {
  final LandLead lead;
  final VoidCallback onOpenSite;
  final VoidCallback onClose;

  const _PropertyPopup({
    required this.lead,
    required this.onOpenSite,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final acres = leadPortfolioAcres(lead);
    return Material(
      color: context.fomraSurface,
      elevation: 8,
      borderRadius: BorderRadius.circular(14),
      shadowColor: Colors.black.withValues(alpha: 0.35),
      child: Container(
        width: 226,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.fomraBorder),
        ),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    _siteName(lead),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: context.fomraTextSecondary),
                  ),
                ),
              ],
            ),
            Text(
              'Site #${lead.leadId}',
              style: TextStyle(fontSize: 11, color: context.fomraTextSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: lead.status.color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    lead.status.label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: lead.status.color,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${acres.toStringAsFixed(2)} ac',
                  style:
                      TextStyle(fontSize: 11.5, color: context.fomraTextSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      onClose();
                      onOpenSite();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: const Size(0, 34),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('View',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 34,
                  child: FilledButton(
                    onPressed: lead.gpsCoordinates.trim().isEmpty
                        ? null
                        : () => MapsNavigation.navigateFromGpsString(
                              lead.gpsCoordinates,
                              label: _siteName(lead),
                            ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Icon(Icons.directions_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
