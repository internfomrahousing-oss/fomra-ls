import 'package:flutter/material.dart';
import '../../models/land_lead.dart';
import '../../theme/app_theme.dart';
import '../market_intelligence/market_intelligence_screen.dart';

class LeadDetailScreen extends StatelessWidget {
  final LandLead lead;

  const LeadDetailScreen({super.key, required this.lead});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
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
                  color: AppColors.textPrimary,
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (lead.sitePhotoUrls.length == 1)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  lead.sitePhotoUrls.first,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _photoError(),
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
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    lead.sitePhotoUrls[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _photoError(),
                  ),
                ),
              ),
          ] else if (lead.sitePhotoUrl.isNotEmpty) ...[
            const Divider(height: 24),
            const Text(
              'Site Photo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                lead.sitePhotoUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _photoError(),
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

Widget _photoError() {
  return Container(
    height: 120,
    color: AppColors.surfaceVar,
    alignment: Alignment.center,
    child: const Text(
      'Photo unavailable',
      style: TextStyle(color: AppColors.textSecondary),
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
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
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
    final color = switch (status) {
      LeadStatus.new_ => AppColors.info,
      LeadStatus.contacted => const Color(0xFF8B5CF6),
      LeadStatus.siteVisit => AppColors.warning,
      LeadStatus.negotiation => AppColors.accent,
      LeadStatus.closed => AppColors.success,
      LeadStatus.lost => AppColors.error,
    };
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
