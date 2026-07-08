import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/maptiler_tiles.dart';
import '../../models/land_lead.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../utils/lead_location_parser.dart';
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
    final initialView = plotted.isEmpty
        ? null
        : _computeCenterAndZoom(plotted);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          plotted.isEmpty
              ? 'Lead map'
              : '${plotted.length} lead${plotted.length == 1 ? '' : 's'} on map',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: plotted.isEmpty
          ? _buildEmpty(context)
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialView!.$1,
                    initialZoom: initialView.$2,
                    onMapReady: () {
                      setState(() => _mapReady = true);
                    },
                  ),
                  children: [
                    TileLayer(
                      // Use the default tile provider on this screen.
                      // Cancellable provider can occasionally leave the first
                      // paint blank until interaction on some web builds.
                      urlTemplate: MapTilerTiles.standard,
                      fallbackUrl: MapTilerTiles.standardFallback,
                      userAgentPackageName: 'in.fomrahousing.fomrals',
                      maxZoom: 22,
                    ),
                    MarkerLayer(
                      markers: plotted.map((p) {
                        final color = p.lead.status.color;
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
                                        ? p.lead.leadId.substring(p.lead.leadId.length - 6)
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
                      }).toList(),
                    ),
                  ],
                ),
                if (_missingGps > 0)
                  Positioned(
                    left: 12,
                    right: 12,
                    top: 12,
                    child: Material(
                      color: context.fomraSurface.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(16),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Text(
                          '$_missingGps lead${_missingGps == 1 ? '' : 's'} '
                          'without GPS — not shown. Add GPS when creating leads.',
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
                        children: LeadStatus.values
                            .where((s) => s != LeadStatus.siteVisit)
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
                if (!_mapReady)
                  const Center(child: CircularProgressIndicator()),
              ],
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
