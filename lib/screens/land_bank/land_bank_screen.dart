import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../analytics/business_module_metrics.dart';
import '../../config/maptiler_tiles.dart';
import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../utils/lead_location_parser.dart';
import '../../utils/maps_navigation.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/ui/app_components.dart';
import '../land_lead/lead_detail_screen.dart';

/// GIS-based land inventory (Land Bank).
class LandBankScreen extends StatefulWidget {
  const LandBankScreen({super.key});

  @override
  State<LandBankScreen> createState() => _LandBankScreenState();
}

class _LandBankScreenState extends State<LandBankScreen> {
  final MapController _mapController = MapController();
  String _query = '';
  String? _district;
  LandLead? _selected;

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  List<LandLead> get _inventory {
    final q = _query.trim().toLowerCase();
    return AppStore.instance.leads.where((l) {
      if (_district != null &&
          l.district.trim().toLowerCase() != _district!.toLowerCase()) {
        return false;
      }
      if (q.isEmpty) return true;
      return l.leadId.toLowerCase().contains(q) ||
          l.ownerName.toLowerCase().contains(q) ||
          l.village.toLowerCase().contains(q) ||
          l.surveyNumber.toLowerCase().contains(q) ||
          l.district.toLowerCase().contains(q);
    }).toList();
  }

  List<(LandLead, LatLng)> get _plotted {
    final out = <(LandLead, LatLng)>[];
    for (final l in _inventory) {
      final p = parseLeadGps(l.gpsCoordinates);
      if (p != null) out.add((l, p));
    }
    return out;
  }

  Set<String> get _districts {
    final s = <String>{};
    for (final l in AppStore.instance.leads) {
      final d = l.district.trim();
      if (d.isNotEmpty) s.add(d);
    }
    return s;
  }

  double get _totalAcres => _inventory.fold<double>(
        0,
        (s, l) => s + AcquisitionCostCalculator.acresFromLead(l),
      );

  @override
  Widget build(BuildContext context) {
    final inventory = _inventory;
    final plotted = _plotted;
    final acresFmt = NumberFormat('#,##0.##');
    final center = plotted.isNotEmpty
        ? plotted.first.$2
        : const LatLng(11.0168, 76.9558);

    return FomraAppShell(
      currentRoute: '/land-bank',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final list = _buildList(inventory, acresFmt);
          final map = _buildMap(plotted, center);
          if (wide) {
            return Row(
              children: [
                SizedBox(width: 380, child: list),
                Expanded(child: map),
              ],
            );
          }
          return Column(
            children: [
              Expanded(flex: 2, child: list),
              Expanded(flex: 3, child: map),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<LandLead> inventory, NumberFormat acresFmt) {
    return ListView(
      padding: FomraLayout.pagePadding(context),
      children: [
        Text(
          'Land Bank',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: context.fomraTextPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'GIS inventory of sourced land parcels.',
          style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _stat('Parcels', '${inventory.length}', AppColors.primary),
            _stat('On map', '${_plotted.length}', AppColors.info),
            _stat('Acres', acresFmt.format(_totalAcres), AppColors.success),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search village, survey, owner…',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: context.fomraSurfaceVar,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: _district,
          decoration: InputDecoration(
            labelText: 'District',
            filled: true,
            fillColor: context.fomraSurfaceVar,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All districts')),
            ..._districts.map(
              (d) => DropdownMenuItem(value: d, child: Text(d)),
            ),
          ],
          onChanged: (v) => setState(() => _district = v),
        ),
        const SizedBox(height: 12),
        if (inventory.isEmpty)
          const AppCard(
            child: EmptyState(
              title: 'No parcels',
              message: 'Add leads with location data to build the land bank.',
            ),
          )
        else
          ...inventory.take(80).map((l) {
            final acres = AcquisitionCostCalculator.acresFromLead(l);
            final hasGps = parseLeadGps(l.gpsCoordinates) != null;
            final selected = _selected?.leadId == l.leadId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () {
                  setState(() => _selected = l);
                  final p = parseLeadGps(l.gpsCoordinates);
                  if (p != null) {
                    _mapController.move(p, 15);
                  }
                },
                child: Container(
                  decoration: selected
                      ? BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  padding: selected ? const EdgeInsets.all(4) : EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.ownerName.trim().isEmpty
                                  ? 'Lead #${l.leadId}'
                                  : l.ownerName,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: context.fomraTextPrimary,
                              ),
                            ),
                          ),
                          if (hasGps)
                            IconButton(
                              tooltip: 'Navigate',
                              icon: const Icon(Icons.directions_outlined,
                                  size: 20),
                              onPressed: () => MapsNavigation.navigateFromGpsString(
                                l.gpsCoordinates,
                                label: l.ownerName,
                              ),
                            ),
                          IconButton(
                            tooltip: 'Open lead',
                            icon: const Icon(Icons.open_in_new, size: 18),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeadDetailScreen(lead: l),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        [
                          if (l.village.isNotEmpty) l.village,
                          if (l.district.isNotEmpty) l.district,
                          if (l.surveyNumber.isNotEmpty)
                            'Sy ${l.surveyNumber}',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        acres > 0
                            ? '${acresFmt.format(acres)} acres · ${l.status.label}'
                            : l.status.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildMap(List<(LandLead, LatLng)> plotted, LatLng center) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: plotted.isEmpty ? 7 : 11,
      ),
      children: [
        TileLayer(
          urlTemplate: MapTilerTiles.standard,
          fallbackUrl: MapTilerTiles.standardFallback,
          userAgentPackageName: 'in.fomrahousing.fomrals',
        ),
        MarkerLayer(
          markers: [
            for (final (lead, point) in plotted)
              Marker(
                point: point,
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: () => setState(() => _selected = lead),
                  child: Icon(
                    Icons.location_on,
                    color: _selected?.leadId == lead.leadId
                        ? AppColors.accent
                        : AppColors.primary,
                    size: 36,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }
}
