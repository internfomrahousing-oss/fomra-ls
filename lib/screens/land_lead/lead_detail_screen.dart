import 'package:flutter/material.dart';
import '../../models/add_lead_result.dart';
import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../services/land_lead_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/portal_home_sections.dart';
import '../../widgets/portal_page_layout.dart';
import '../market_intelligence/market_intelligence_screen.dart';
import 'add_lead_screen.dart';

class LeadDetailScreen extends StatefulWidget {
  final LandLead lead;

  const LeadDetailScreen({super.key, required this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  late LandLead lead = widget.lead;

  Future<void> _openEdit() async {
    final result = await Navigator.push<AddLeadResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLeadScreen(existingLead: lead),
      ),
    );
    if (result == null || !mounted) return;

    try {
      final saved = await LandLeadService.update(
        result.lead,
        sitePhotoBytes: result.sitePhotoBytes,
      );
      AppStore.instance.replaceLead(saved);
      setState(() => lead = saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lead updated')),
        );
      }
    } catch (e) {
      AppStore.instance.replaceLead(result.lead);
      setState(() => lead = result.lead);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved locally; sync failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fomraPageBg,
      appBar: FomraSubPageAppBar(
        title: lead.ownerName,
        subtitle: lead.leadId,
        subtitleStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.95),
        ),
        actions: [
          TextButton.icon(
            onPressed: _openEdit,
            icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.white),
            label: const Text(
              'Edit',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: portalScrollBody(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PortalFadeSection(
              index: 0,
              child: PortalSectionCard(
                title: 'Land lead details',
                subtitle: 'Parcel, owner and status overview',
                icon: Icons.description_outlined,
                child: _LeadDetailsBody(lead: lead),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PortalFadeSection(
              index: 1,
              child: PortalSectionCard(
                title: 'Market intelligence',
                subtitle: 'Comparable listings near this parcel',
                icon: Icons.travel_explore_outlined,
                child: MarketIntelligenceScreen(
                  key: ValueKey(
                      '${lead.leadId}|${lead.gpsCoordinates}|${lead.landExtent}'),
                  lead: lead,
                  embeddedInLead: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadDetailsBody extends StatelessWidget {
  final LandLead lead;
  const _LeadDetailsBody({required this.lead});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _StatusChip(status: lead.status),
        ),
        const SizedBox(height: AppSpacing.md),
        _DetailRow('Owner', lead.ownerName),
        if (lead.contactDetails.isNotEmpty)
          _DetailRow('Contact', lead.contactDetails),
        _DetailRow('Input Source', lead.inputSource.label),
        _DetailRow('Land Type', lead.landType.label),
        _DetailRow('Status', lead.status.label),
        const Divider(height: 24),
        Text(
          'Land Location',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: context.fomraTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        _DetailRow('Location', lead.location),
        if (lead.village.isNotEmpty) _DetailRow('Village', lead.village),
        if (lead.taluk.isNotEmpty) _DetailRow('Taluk', lead.taluk),
        if (lead.district.isNotEmpty) _DetailRow('District', lead.district),
        if (lead.pincode.isNotEmpty) _DetailRow('Pincode', lead.pincode),
        if (lead.gpsCoordinates.isNotEmpty)
          _DetailRow('GPS', lead.gpsCoordinates),
        if (lead.surveyNumber.isNotEmpty)
          _DetailRow('Survey No.', lead.surveyNumber),
        if (lead.subDivision.isNotEmpty)
          _DetailRow('Sub Division', lead.subDivision),
        if (lead.landExtent.isNotEmpty)
          _DetailRow('Land Extent', lead.landExtent),
        if (lead.roadWidth.isNotEmpty)
          _DetailRow('Road Width', lead.roadWidth),
        if (lead.accessDetails.isNotEmpty)
          _DetailRow('Terms', lead.accessDetails),
        if (lead.notes.isNotEmpty) ...[
          const Divider(height: 24),
          _DetailRow('Notes', lead.notes),
        ],
        if (lead.sitePhotoUrls.isNotEmpty || lead.sitePhotoUrl.isNotEmpty) ...[
          const Divider(height: 24),
          Text(
            _sitePhotoUrls(lead).length == 1 ? 'Site Photo' : 'Site Photos',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.fomraTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _sitePhotosRow(context, _sitePhotoUrls(lead)),
        ],
        const SizedBox(height: 8),
        Text(
          'Added ${lead.addedOn.day}/${lead.addedOn.month}/${lead.addedOn.year}',
          style: TextStyle(
            fontSize: 11,
            color: context.fomraTextSecondary,
          ),
        ),
      ],
    );
  }
}

List<String> _sitePhotoUrls(LandLead lead) {
  if (lead.sitePhotoUrls.isNotEmpty) return lead.sitePhotoUrls;
  if (lead.sitePhotoUrl.isNotEmpty) return [lead.sitePhotoUrl];
  return const [];
}

/// Up to 4 site photos in one compact row (tap to view full size).
Widget _sitePhotosRow(BuildContext context, List<String> urls) {
  const thumbSize = 72.0;
  const gap = 8.0;

  return Row(
    children: [
      for (var i = 0; i < urls.length; i++)
        Padding(
          padding: EdgeInsets.only(right: i < urls.length - 1 ? gap : 0),
          child: GestureDetector(
            onTap: () => _showFullPhoto(context, urls[i]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: thumbSize,
                height: thumbSize,
                child: Image.network(
                  urls[i],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _photoError(),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

void _showFullPhoto(BuildContext context, String url) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const Center(
                              child: CircularProgressIndicator(color: Colors.white)),
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Photo unavailable',
                            style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _photoError() {
  return Container(
    width: 140,
    height: 140,
    color: AppColors.surfaceVar,
    alignment: Alignment.center,
    child: const Text(
      'Photo\nunavailable',
      textAlign: TextAlign.center,
      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.fomraTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.fomraTextPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final LeadStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
