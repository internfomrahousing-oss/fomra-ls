import 'package:flutter/material.dart';
import '../../models/land_lead.dart';
import '../../models/site_verification.dart';
import '../../services/app_store.dart';
import '../../services/land_lead_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
import 'add_site_verification_screen.dart';

class SiteVerificationScreen extends StatefulWidget {
  const SiteVerificationScreen({super.key});

  @override
  State<SiteVerificationScreen> createState() =>
      _SiteVerificationScreenState();
}

class _SiteVerificationScreenState extends State<SiteVerificationScreen> {
  VerificationStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_onStoreUpdate);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() => setState(() {});

  List<SiteVerification> get _verifications => AppStore.instance.siteVerifications;

  List<SiteVerification> get _filtered => _filterStatus == null
      ? _verifications
      : _verifications.where((v) => v.status == _filterStatus).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FomraAppBar(
        moduleName: 'Site Verification',
        actions: [
          if (_verifications.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilter),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/site-verification'),
      bottomNavigationBar:
          const FomraBottomNav(currentRoute: '/site-verification'),
      body: Column(children: [
        if (_verifications.isNotEmpty)
          _StatusSummary(verifications: _verifications),
        Expanded(
          child: _filtered.isEmpty
              ? _EmptyState(hasData: _verifications.isNotEmpty)
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) => _VerificationCard(
                    v: _filtered[i],
                    onFillDetails: _filtered[i].status == VerificationStatus.scheduled
                        ? () => _openFillDetails(_filtered[i])
                        : null,
                  ),
                ),
        ),
      ]),
    );
  }

  Future<void> _openFillDetails(SiteVerification pending) async {
    final result = await Navigator.push<SiteVerification>(
      context,
      MaterialPageRoute(
        builder: (_) => AddSiteVerificationScreen(
          pendingId: pending.id,
          prefillLeadRef: pending.leadReference,
          prefillGps: pending.geoCoordinates,
          prefillAddress: pending.geoAddress,
          prefillRoadAccess: pending.roadAccess,
          prefillPincode: pending.pincode,
        ),
      ),
    );
    if (result != null) {
      AppStore.instance.completePendingVerification(pending.id, result);
      // Advance lead status to siteVisit so it persists across sessions
      // and unlocks Market Intelligence / Legal Verification for this lead.
      final leadId = pending.leadReference;
      if (leadId.isNotEmpty) {
        AppStore.instance.updateLeadStatus(leadId, LeadStatus.siteVisit);
        LandLeadService.updateStatus(leadId, LeadStatus.siteVisit)
            .catchError((_) {});
      }
    }
  }

  void _showFilter() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Filter by Status',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold))),
          ListTile(
              title: const Text('All'),
              leading: const Icon(Icons.list),
              onTap: () {
                setState(() => _filterStatus = null);
                Navigator.pop(context);
              }),
          ...VerificationStatus.values.map((s) => ListTile(
                leading: CircleAvatar(
                    radius: 8, backgroundColor: _statusColor(s)),
                title: Text(s.label),
                onTap: () {
                  setState(() => _filterStatus = s);
                  Navigator.pop(context);
                },
              )),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasData;
  const _EmptyState({required this.hasData});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_searching,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          Text(
            hasData
                ? 'No records match the current filter.'
                : 'No site verifications yet.\nAdd a lead in Land Lead Management to get started.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500),
          ),
        ]),
      );
}

// ── Status Summary Bar ────────────────────────────────────────────────────────

class _StatusSummary extends StatelessWidget {
  final List<SiteVerification> verifications;
  const _StatusSummary({required this.verifications});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: VerificationStatus.values.map((s) {
          final count =
              verifications.where((v) => v.status == s).length;
          return Column(children: [
            Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(s.label,
                style: const TextStyle(
                    color: Color(0xFFB0BEC5), fontSize: 10)),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── Verification Card ─────────────────────────────────────────────────────────

class _VerificationCard extends StatelessWidget {
  final SiteVerification v;
  final VoidCallback? onFillDetails;
  const _VerificationCard({required this.v, this.onFillDetails});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(v.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: Lead number (primary title) + status badge
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.tag,
                            size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          v.leadReference.isNotEmpty
                              ? v.leadReference
                              : v.id,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3),
                        ),
                      ]),
                    ),
                    const Spacer(),
                    _StatusBadge(status: v.status),
                  ]),
                  const SizedBox(height: 4),

                  // Row 2: SV record ID (secondary, small)
                  Text(v.id,
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),

                  // Row 3: address
                  if (v.geoAddress.isNotEmpty)
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(v.geoAddress,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                  if (v.geoCoordinates.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(v.geoCoordinates,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ],

                  const SizedBox(height: 8),

                  // Row 4: attachments + date
                  Row(children: [
                    Expanded(
                      child: Wrap(spacing: 8, children: [
                        if (v.photographs.isNotEmpty)
                          _Chip(Icons.photo_outlined,
                              '${v.photographs.length} photo(s)',
                              AppColors.info),
                        if (v.video != null)
                          const _Chip(Icons.videocam_outlined, '1 video',
                              Color(0xFF8B5CF6)),
                        if (v.roadAccess.isNotEmpty)
                          const _Chip(Icons.add_road, 'Road noted',
                              AppColors.success),
                      ]),
                    ),
                    const Icon(Icons.calendar_today,
                        size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                        '${v.capturedOn.day}/${v.capturedOn.month}/${v.capturedOn.year}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ]),

                  // Row 5: observations preview
                  if (v.siteObservations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6)),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notes,
                                size: 13,
                                color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(v.siteObservations,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary)),
                            ),
                          ]),
                    ),
                  ],

                  // Pending banner + action for auto-created scheduled SVs
                  if (onFillDetails != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline,
                            size: 13,
                            color: AppColors.warning.withValues(alpha: 0.8)),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Site visit not yet completed',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.warning),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onFillDetails,
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Begin Site Capture',
                            style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ]),
      );
}

class _StatusBadge extends StatelessWidget {
  final VerificationStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 10, color: c, fontWeight: FontWeight.w700)),
    );
  }
}

Color _statusColor(VerificationStatus s) => switch (s) {
      VerificationStatus.scheduled => AppColors.info,
      VerificationStatus.inProgress => AppColors.warning,
      VerificationStatus.completed => AppColors.success,
      VerificationStatus.failed => AppColors.error,
    };
