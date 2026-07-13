import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../config/maptiler_tiles.dart';
import '../../models/land_lead.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../utils/lead_location_parser.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
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

  // ── Filters ────────────────────────────────────────────────────────────────
  final Set<LeadStatus> _stages = {};
  String? _executive;
  String? _district;
  String? _village;
  String? _owner;
  String? _broker;
  DateTimeRange? _dateRange;

  bool get _hasActiveFilters =>
      _stages.isNotEmpty ||
      _executive != null ||
      _district != null ||
      _village != null ||
      _owner != null ||
      _broker != null ||
      _dateRange != null;

  void _clearFilters() {
    _stages.clear();
    _executive = null;
    _district = null;
    _village = null;
    _owner = null;
    _broker = null;
    _dateRange = null;
  }

  List<String> _distinct(String Function(LandLead) selector) {
    final set = <String>{};
    for (final l in widget.leads) {
      final v = selector(l).trim();
      if (v.isNotEmpty) set.add(v);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<LandLead> get _filteredLeads {
    return widget.leads.where((l) {
      if (_stages.isNotEmpty && !_stages.contains(l.status)) return false;
      if (_executive != null && l.createdByName.trim() != _executive) {
        return false;
      }
      if (_district != null && l.district.trim() != _district) return false;
      if (_village != null && l.village.trim() != _village) return false;
      if (_owner != null && l.ownerName.trim() != _owner) return false;
      if (_broker != null && l.brokerName.trim() != _broker) return false;
      if (_dateRange != null) {
        final d = DateTime(l.addedOn.year, l.addedOn.month, l.addedOn.day);
        if (d.isBefore(_dateRange!.start) || d.isAfter(_dateRange!.end)) {
          return false;
        }
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
    final allPlotted = _plottedFrom(widget.leads);
    final initialView =
        allPlotted.isEmpty ? null : _computeCenterAndZoom(allPlotted);

    return FomraAppShell(
      currentRoute: '/land-lead',
      appBar: FomraSubPageAppBar(
        title: 'Project Map',
        subtitle:
            '${filtered.length} lead${filtered.length == 1 ? '' : 's'} · ${totalAcres.toStringAsFixed(2)} acres',
        breadcrumbs: FomraBreadcrumbs.fromWorkspace('Project Map'),
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
                        width: 340,
                        child: _sidePanel(context, filtered, totalAcres),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: map),
                    ],
                  );
                }
                return Column(
                  children: [
                    _compactFilterBar(context, filtered.length, totalAcres),
                    Expanded(child: map),
                    SizedBox(
                      height: 220,
                      child: _matchingList(context, filtered),
                    ),
                  ],
                );
              },
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
              markers: plotted.map((p) {
                // All lead pins render red for a single, consistent map colour.
                const color = AppColors.error;
                return Marker(
                  point: p.point,
                  width: 44,
                  height: 52,
                  child: GestureDetector(
                    onTap: () => _openLead(context, p.lead),
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
                        const Icon(Icons.location_on, color: color, size: 36),
                      ],
                    ),
                  ),
                );
              }).toList(),
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
                  '$missingGps matching lead${missingGps == 1 ? '' : 's'} '
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

  // ── Wide side panel: filters + matching list ───────────────────────────────
  Widget _sidePanel(
    BuildContext context,
    List<LandLead> filtered,
    double totalAcres,
  ) {
    return Material(
      color: context.fomraSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: _totalsRow(context, filtered.length, totalAcres),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _filterControls(context, (fn) => setState(fn)),
                const Divider(height: 28),
                Text(
                  'Matching properties',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: context.fomraTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  Text(
                    'No leads match the current filters.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.fomraTextSecondary,
                    ),
                  )
                else
                  for (final l in filtered) _leadListTile(context, l),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow: compact filter bar + matching list ─────────────────────────────
  Widget _compactFilterBar(
    BuildContext context,
    int matchCount,
    double totalAcres,
  ) {
    return Material(
      color: context.fomraSurface,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          children: [
            Expanded(child: _totalsRow(context, matchCount, totalAcres)),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _openFilterSheet,
              icon: Badge(
                isLabelVisible: _hasActiveFilters,
                child: const Icon(Icons.tune_rounded, size: 18),
              ),
              label: const Text('Filters'),
            ),
          ],
        ),
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.fomraSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            void apply(VoidCallback fn) {
              setState(fn);
              setSheet(() {});
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.8,
              maxChildSize: 0.95,
              builder: (ctx, controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  Row(
                    children: [
                      Text(
                        'Filter properties',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.fomraTextPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _filterControls(context, apply),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _matchingList(BuildContext context, List<LandLead> filtered) {
    return Material(
      color: context.fomraSurface,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text(
              'Matching properties (${filtered.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: context.fomraTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No leads match the current filters.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final l in filtered) _leadListTile(context, l),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _leadListTile(BuildContext context, LandLead lead) {
    final hasGps = parseLeadGps(lead.gpsCoordinates) != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _openLead(context, lead),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: context.fomraSurfaceVar.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: context.fomraBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: lead.status.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lead #${lead.leadId} · ${lead.status.label}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (lead.village.isNotEmpty) lead.village,
                        if (lead.createdByName.isNotEmpty) lead.createdByName,
                        '${leadPortfolioAcres(lead).toStringAsFixed(2)} ac',
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (!hasGps)
                Icon(Icons.location_off_outlined,
                    size: 15, color: context.fomraTextTertiary),
              Icon(Icons.chevron_right_rounded,
                  size: 18, color: context.fomraTextTertiary),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter controls (shared by side panel + bottom sheet) ──────────────────
  Widget _filterControls(
    BuildContext context,
    void Function(VoidCallback) apply,
  ) {
    final df = DateFormat('dd MMM yyyy');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Lead Stage',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: context.fomraTextSecondary,
              ),
            ),
            const Spacer(),
            if (_hasActiveFilters)
              TextButton(
                onPressed: () => apply(_clearFilters),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear all'),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in leadStatusPipelineOrder)
              FilterChip(
                label: Text(s.label),
                selected: _stages.contains(s),
                onSelected: (v) =>
                    apply(() => v ? _stages.add(s) : _stages.remove(s)),
                selectedColor: s.color.withValues(alpha: 0.18),
                checkmarkColor: s.color,
                labelStyle: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _dropdown(context, 'Assigned Executive', _executive,
            _distinct((l) => l.createdByName), (v) => apply(() => _executive = v)),
        _dropdown(context, 'District', _district,
            _distinct((l) => l.district), (v) => apply(() => _district = v)),
        _dropdown(context, 'Village', _village, _distinct((l) => l.village),
            (v) => apply(() => _village = v)),
        _dropdown(context, 'Owner', _owner, _distinct((l) => l.ownerName),
            (v) => apply(() => _owner = v)),
        _dropdown(context, 'Broker', _broker, _distinct((l) => l.brokerName),
            (v) => apply(() => _broker = v)),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final range = await showDateRangePicker(
              context: context,
              firstDate: DateTime(now.year - 5),
              lastDate: DateTime(now.year + 1),
              initialDateRange: _dateRange,
            );
            if (range != null) apply(() => _dateRange = range);
          },
          icon: const Icon(Icons.date_range_outlined, size: 18),
          label: Text(
            _dateRange == null
                ? 'Any date'
                : '${df.format(_dateRange!.start)} – ${df.format(_dateRange!.end)}',
          ),
        ),
      ],
    );
  }

  Widget _dropdown(
    BuildContext context,
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('$label-${value ?? 'all'}'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: context.fomraSurfaceVar,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('All')),
          for (final o in options)
            DropdownMenuItem<String?>(value: o, child: Text(o)),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _totalsRow(BuildContext context, int matchCount, double totalAcres) {
    return Row(
      children: [
        _totalPill(context, '$matchCount', 'Leads', AppColors.primary),
        const SizedBox(width: 10),
        _totalPill(context, totalAcres.toStringAsFixed(2), 'Acres',
            AppColors.info),
      ],
    );
  }

  Widget _totalPill(
    BuildContext context,
    String value,
    String label,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: context.fomraTextSecondary,
              ),
            ),
          ],
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
              'No leads with GPS coordinates',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.fomraTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add GPS when creating leads (tap the map in Add Lead) '
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

  void _openLead(BuildContext context, LandLead lead) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
    );
  }
}
