import 'package:flutter/material.dart';
import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../services/land_lead_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../market_intelligence/market_intelligence_screen.dart';

class LeadDetailScreen extends StatefulWidget {
  final LandLead lead;

  const LeadDetailScreen({super.key, required this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  late LandLead lead = widget.lead;

  Future<void> _onLocationEdited({
    required String location,
    required String village,
    required String taluk,
    required String district,
    required String pincode,
  }) async {
    setState(() => lead = lead.copyWith(
          location: location,
          village: village,
          taluk: taluk,
          district: district,
          pincode: pincode,
        ));
    AppStore.instance.updateLeadLocation(lead.leadId, lead);
    try {
      await LandLeadService.updateLocation(
        lead.leadId,
        location: location,
        village: village,
        taluk: taluk,
        district: district,
        pincode: pincode,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved locally; sync failed: $e')),
        );
      }
    }
  }

  Future<void> _onParcelEdited(String survey, String sub) async {
    setState(() => lead = lead.copyWith(surveyNumber: survey, subDivision: sub));
    AppStore.instance.updateLeadParcel(lead.leadId, survey, sub);
    try {
      await LandLeadService.updateSurveySub(lead.leadId, survey, sub);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Survey / sub-division updated')),
        );
      }
    } catch (e) {
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
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lead.ownerName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              lead.leadId,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LeadDetailsCard(lead: lead, onEditLocation: _onLocationEdited),
            const SizedBox(height: 20),
            MarketIntelligenceScreen(
              lead: lead,
              embeddedInLead: true,
              onParcelEdited: _onParcelEdited,
            ),
          ],
        ),
      ),
    );
  }
}

class _LeadDetailsCard extends StatelessWidget {
  final LandLead lead;
  final Future<void> Function({
    required String location,
    required String village,
    required String taluk,
    required String district,
    required String pincode,
  })? onEditLocation;
  const _LeadDetailsCard({required this.lead, this.onEditLocation});

  Future<void> _editLocation(BuildContext context) async {
    final locC = TextEditingController(text: lead.location);
    final vilC = TextEditingController(text: lead.village);
    final talC = TextEditingController(text: lead.taluk);
    final disC = TextEditingController(text: lead.district);
    final pinC = TextEditingController(text: lead.pincode);
    Widget field(String label, TextEditingController c, {TextInputType? kb}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: c,
            keyboardType: kb,
            decoration: InputDecoration(labelText: label, isDense: true),
          ),
        );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Land Location', style: TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            field('Location', locC),
            field('Village', vilC),
            field('Taluk', talC),
            field('District', disC),
            field('Pincode', pinC, kb: TextInputType.number),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await onEditLocation?.call(
        location: locC.text.trim(),
        village: vilC.text.trim(),
        taluk: talC.text.trim(),
        district: disC.text.trim(),
        pincode: pinC.text.trim(),
      );
    }
    for (final c in [locC, vilC, talC, disC, pinC]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.fomraSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.fomraCardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Land Lead Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _StatusChip(status: lead.status),
            ],
          ),
          const SizedBox(height: 14),
          _DetailRow('Owner', lead.ownerName),
          if (lead.contactDetails.isNotEmpty)
            _DetailRow('Contact', lead.contactDetails),
          _DetailRow('Input Source', lead.inputSource.label),
          _DetailRow('Land Type', lead.landType.label),
          _DetailRow('Status', lead.status.label),
          const Divider(height: 24),
          Row(children: [
            Expanded(
              child: Text('Land Location',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.fomraTextSecondary)),
            ),
            if (onEditLocation != null)
              TextButton.icon(
                onPressed: () => _editLocation(context),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Edit', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
          ]),
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
          if (lead.sitePhotoUrls.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              lead.sitePhotoUrls.length == 1 ? 'Site Photo' : 'Site Photos',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.fomraTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (lead.sitePhotoUrls.length == 1)
              _sitePhotoThumb(context, lead.sitePhotoUrls.first)
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.2,
                ),
                itemCount: lead.sitePhotoUrls.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _showFullPhoto(context, lead.sitePhotoUrls[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      lead.sitePhotoUrls[i],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _photoError(),
                    ),
                  ),
                ),
              ),
          ] else if (lead.sitePhotoUrl.isNotEmpty) ...[
            const Divider(height: 24),
            Text(
              'Site Photo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.fomraTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _sitePhotoThumb(context, lead.sitePhotoUrl),
          ],
          const SizedBox(height: 8),
          Text(
            'Added ${lead.addedOn.day}/${lead.addedOn.month}/${lead.addedOn.year}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// A small square site-photo thumbnail with a guaranteed-tappable "View full
// size" button below it. On web the image can render as an HTML overlay that
// swallows taps, so the button (a real Flutter widget) is the reliable target.
Widget _sitePhotoThumb(BuildContext context, String url) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      GestureDetector(
        onTap: () => _showFullPhoto(context, url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 140,
            height: 140,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _photoError(),
          ),
        ),
      ),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () => _showFullPhoto(context, url),
        child: const Text(
          'Tap to view',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
