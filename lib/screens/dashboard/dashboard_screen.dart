import 'package:flutter/material.dart';
import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../land_lead/lead_detail_screen.dart';
import '../settings/change_password_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';

enum _KpiFilter { total, active, acquired, rejected }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  List<LandLead> _leadsForFilter(_KpiFilter filter) {
    final leads = AppStore.instance.leads;
    return switch (filter) {
      _KpiFilter.total => List<LandLead>.from(leads),
      _KpiFilter.active => leads
          .where((l) => [
                LeadStatus.new_,
                LeadStatus.contacted,
                LeadStatus.siteVisit,
                LeadStatus.negotiation,
              ].contains(l.status))
          .toList(),
      _KpiFilter.acquired =>
        leads.where((l) => l.status == LeadStatus.closed).toList(),
      _KpiFilter.rejected =>
        leads.where((l) => l.status == LeadStatus.lost).toList(),
    };
  }

  void _openKpiLeads(_KpiData kpi) {
    final leads = _leadsForFilter(kpi.filter);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KpiLeadsSheet(
        title: kpi.label,
        subtitle: kpi.sub,
        color: kpi.color,
        leads: leads,
      ),
    );
  }

  void _openChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leads = AppStore.instance.leads;
    final totalLeads = leads.length;
    final activeLeads = _leadsForFilter(_KpiFilter.active).length;
    final acquired = _leadsForFilter(_KpiFilter.acquired).length;
    final rejected = _leadsForFilter(_KpiFilter.rejected).length;

    return Scaffold(
      appBar: const FomraAppBar(moduleName: 'Dashboard'),
      drawer: const AppDrawer(currentRoute: '/dashboard'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/dashboard'),
      backgroundColor: context.fomraPageBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Header(
              title: 'Management Dashboard',
              subtitle: 'Real-time overview of your land acquisition pipeline',
              icon: Icons.dashboard_outlined,
            ),
            const SizedBox(height: 16),
            _kpiGrid(context, [
              _KpiData(
                'Total Leads',
                '$totalLeads',
                Icons.location_on_outlined,
                AppColors.info,
                '+$totalLeads total',
                _KpiFilter.total,
                _openKpiLeads,
              ),
              _KpiData(
                'Active Leads',
                '$activeLeads',
                Icons.trending_up_outlined,
                AppColors.primary,
                'In pipeline',
                _KpiFilter.active,
                _openKpiLeads,
              ),
              _KpiData(
                'Acquired Land',
                '$acquired',
                Icons.check_circle_outline,
                AppColors.success,
                'Closed deals',
                _KpiFilter.acquired,
                _openKpiLeads,
              ),
              _KpiData(
                'Rejected Leads',
                '$rejected',
                Icons.cancel_outlined,
                AppColors.error,
                'Lost / rejected',
                _KpiFilter.rejected,
                _openKpiLeads,
              ),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openChangePassword,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Change Password',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiGrid(BuildContext context, List<_KpiData> kpis) {
    final width = MediaQuery.of(context).size.width;
    final cols = width > 900 ? 4 : width > 600 ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        childAspectRatio: width > 600 ? 1.7 : 1.55,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: kpis.length,
      itemBuilder: (_, i) => _KpiCard(kpis[i]),
    );
  }
}

// ── Header widget ──────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _Header({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.fomraTextPrimary)),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 11, color: context.fomraTextSecondary)),
          ]),
        ),
      ]);
}

// ── KPI card ───────────────────────────────────────────────────────────────────
class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String sub;
  final _KpiFilter filter;
  final void Function(_KpiData) onTap;

  const _KpiData(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.sub,
    this.filter,
    this.onTap,
  );
}

class _KpiCard extends StatelessWidget {
  final _KpiData d;
  const _KpiCard(this.d);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.fomraSurface,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: () => d.onTap(d),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: d.color, width: 4)),
            boxShadow: context.fomraCardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: d.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(d.icon, color: d.color, size: 18),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: context.fomraTextSecondary.withValues(alpha: 0.4)),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.value,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: d.color,
                          height: 1.1)),
                  const SizedBox(height: 2),
                  Text(d.label,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.fomraTextPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(d.sub,
                      style: TextStyle(
                          fontSize: 10, color: context.fomraTextSecondary)),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── KPI leads bottom sheet ─────────────────────────────────────────────────────
class _KpiLeadsSheet extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<LandLead> leads;

  const _KpiLeadsSheet({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.leads,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: context.fomraSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.fomraBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.list_alt, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: context.fomraTextPrimary)),
                      Text(
                        '${leads.length} lead${leads.length == 1 ? '' : 's'} · $subtitle',
                        style: TextStyle(
                            fontSize: 11, color: context.fomraTextSecondary),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: leads.isEmpty
                  ? Center(
                      child: Text(
                        'No leads in this category yet.',
                        style: TextStyle(color: context.fomraTextSecondary),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: leads.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final lead = leads[i];
                        return _KpiLeadTile(lead: lead);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiLeadTile extends StatelessWidget {
  final LandLead lead;
  const _KpiLeadTile({required this.lead});

  Color _statusColor(LeadStatus s) => switch (s) {
        LeadStatus.new_ => AppColors.info,
        LeadStatus.contacted => const Color(0xFF8B5CF6),
        LeadStatus.siteVisit => AppColors.warning,
        LeadStatus.negotiation => AppColors.accent,
        LeadStatus.closed => AppColors.success,
        LeadStatus.lost => AppColors.error,
      };

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(lead.status);
    final location = [lead.location, lead.village, lead.district]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return Material(
      color: context.fomraSurfaceVar,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LeadDetailScreen(lead: lead),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(lead.leadId,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.fomraTextPrimary)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(lead.status.label,
                      style: TextStyle(
                          fontSize: 10,
                          color: statusColor,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              if (lead.ownerName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(lead.ownerName,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.fomraTextSecondary)),
              ],
              if (location.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.location_on_outlined,
                      size: 13, color: context.fomraTextSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(location,
                        style: TextStyle(
                            fontSize: 12, color: context.fomraTextSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 4,
                children: [
                  if (lead.surveyNumber.isNotEmpty)
                    _DetailChip(Icons.tag, 'Survey: ${lead.surveyNumber}'),
                  if (lead.subDivision.isNotEmpty)
                    _DetailChip(
                        Icons.call_split, 'Sub: ${lead.subDivision}'),
                  if (lead.landExtent.isNotEmpty)
                    _DetailChip(Icons.straighten, lead.landExtent),
                  _DetailChip(Icons.terrain_outlined, lead.landType.label),
                ],
              ),
              const SizedBox(height: 6),
              Row(children: [
                Text('Tap for full details',
                    style: TextStyle(
                        fontSize: 10,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(Icons.chevron_right,
                    size: 16, color: context.fomraTextTertiary),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DetailChip(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.fomraTextSecondary),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(
                  fontSize: 11, color: context.fomraTextSecondary)),
        ],
      );
}
