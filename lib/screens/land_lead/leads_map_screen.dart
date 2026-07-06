import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/maptiler_tiles.dart';
import '../../models/land_lead.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../utils/lead_location_parser.dart';
import '../../widgets/fomra_app_bar.dart';
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

  List<_PlottedLead> get _plotted {
    final out = <_PlottedLead>[];
    for (final lead in widget.leads) {
      final point = parseLeadGps(lead.gpsCoordinates);
      if (point != null) out.add(_PlottedLead(lead: lead, point: point));
    }
    return out;
  }

  int get _missingGps => widget.leads.length - _plotted.length;

  @override
  Widget build(BuildContext context) {
    final plotted = _plotted;

    return Scaffold(
      backgroundColor: context.fomraPageBg,
      extendBodyBehindAppBar: true,
      appBar: FomraAppBar(
        moduleName: plotted.isEmpty
            ? 'Lead map'
            : '${plotted.length} pinned',
      ),
      body: plotted.isEmpty
          ? _buildEmpty(context)
          : Stack(
              fit: StackFit.expand,
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: plotted.first.point,
                    initialZoom: 11,
                    onMapReady: () {
                      setState(() => _mapReady = true);
                      _fitAll(plotted);
                    },
                  ),
                  children: [
                    MapTilerTiles.tileLayer(urlTemplate: MapTilerTiles.standard),
                    MarkerLayer(
                      markers: plotted.map((p) {
                        final color = p.lead.status.color;
                        return Marker(
                          point: p.point,
                          width: 48,
                          height: 56,
                          child: GestureDetector(
                            onTap: () => _openLead(context, p.lead),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: AppColors.coloredShadow(color),
                                  ),
                                  child: Text(
                                    p.lead.leadId.length > 8
                                        ? p.lead.leadId
                                            .substring(p.lead.leadId.length - 6)
                                        : p.lead.leadId,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Icon(Icons.location_on_rounded,
                                    color: color, size: 40),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                if (_missingGps > 0)
                  Positioned(
                    left: 16,
                    right: 16,
                    top: kToolbarHeight + 20,
                    child: FomraLayout.constrain(
                      context,
                      child: FomraGlassPanel(
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$_missingGps lead${_missingGps == 1 ? '' : 's'} '
                                'without GPS are hidden. Add GPS when creating leads.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.fomraTextSecondary,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: FomraLayout.constrain(
                    context,
                    child: FomraGlassPanel(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Wrap(
                        spacing: 14,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: LeadStatus.values
                            .where((s) => s != LeadStatus.siteVisit)
                            .map((s) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.circle,
                                        size: 10, color: s.color),
                                    const SizedBox(width: 6),
                                    Text(
                                      s.label,
                                      style: TextStyle(
                                        fontSize: 11,
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
                if (!_mapReady)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: FomraLayout.constrain(
        context,
        child: Padding(
          padding: FomraLayout.pagePadding(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.fomraSurface,
              borderRadius: BorderRadius.circular(AppColors.radiusXl),
              border: Border.all(color: context.fomraBorder),
              boxShadow: context.fomraCardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.map_outlined,
                      size: 36,
                      color: AppColors.primary.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 18),
                Text(
                  'No leads with GPS coordinates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.fomraTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add GPS when creating leads (tap the map in Add Lead) '
                  'so they appear here as pinned locations.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.fomraTextSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _fitAll(List<_PlottedLead> plotted) {
    if (plotted.length == 1) {
      _mapController.move(plotted.first.point, 15);
      return;
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

    _mapController.move(center, zoom);
  }

  void _openLead(BuildContext context, LandLead lead) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
    );
  }
}
