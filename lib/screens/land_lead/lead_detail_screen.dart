import 'package:flutter/material.dart';
import '../../models/land_lead.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../market_intelligence/market_intelligence_screen.dart';

class LeadDetailScreen extends StatelessWidget {
  final LandLead lead;

  const LeadDetailScreen({super.key, required this.lead});

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
            _LeadDetailsCard(lead: lead),
            const SizedBox(height: 20),
            MarketIntelligenceScreen(lead: lead, embeddedInLead: true),
          ],
        ),
      ),
    );
  }
}

class _LeadDetailsCard extends StatelessWidget {
  final LandLead lead;
  const _LeadDetailsCard({required this.lead});

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
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => _showFullPhoto(context, lead.sitePhotoUrls.first),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      lead.sitePhotoUrls.first,
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _photoError(),
                    ),
                  ),
                ),
              )
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
            Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () => _showFullPhoto(context, lead.sitePhotoUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    lead.sitePhotoUrl,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoError(),
                  ),
                ),
              ),
            ),
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

void _showFullPhoto(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _photoError(),
              ),
            ),
          ),
          Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ),
        ],
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
