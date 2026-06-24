import 'package:flutter/material.dart';
import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';

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

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    final leads = store.leads;
    final totalLeads = leads.length;
    final activeLeads = leads
        .where((l) => [
              LeadStatus.new_,
              LeadStatus.contacted,
              LeadStatus.siteVisit,
              LeadStatus.negotiation,
            ].contains(l.status))
        .length;
    final acquired = leads.where((l) => l.status == LeadStatus.closed).length;
    final rejected = leads.where((l) => l.status == LeadStatus.lost).length;
    final pendingLegal = leads
        .where((l) =>
            l.status == LeadStatus.siteVisit ||
            l.status == LeadStatus.negotiation)
        .length;

    return Scaffold(
      appBar: const FomraAppBar(moduleName: 'Dashboard & Reports'),
      drawer: const AppDrawer(currentRoute: '/dashboard'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/dashboard'),
      backgroundColor: const Color(0xFFF4F6FB),
      body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Dashboard header ──────────────────────────────
                const _Header(
                  title: 'Management Dashboard',
                  subtitle: 'Real-time overview of your land acquisition pipeline',
                  icon: Icons.dashboard_outlined,
                ),
                const SizedBox(height: 16),

                // ── KPI grid ──────────────────────────────────────
                _kpiGrid(context, [
                  _KpiData('Total Leads', '$totalLeads',
                      Icons.location_on_outlined, AppColors.info, '+$totalLeads total'),
                  _KpiData('Active Leads', '$activeLeads',
                      Icons.trending_up_outlined, AppColors.primary, 'In pipeline'),
                  _KpiData('Acquired Land', '$acquired',
                      Icons.check_circle_outline, AppColors.success, 'Closed deals'),
                  _KpiData('Rejected Leads', '$rejected',
                      Icons.cancel_outlined, AppColors.error, 'Lost / rejected'),
                  _KpiData('Pending Legal Reviews', '$pendingLegal',
                      Icons.gavel_outlined, const Color(0xFF7C3AED), 'Awaiting review'),
                  const _KpiData('Avg Acquisition Cost', '—',
                      Icons.currency_rupee_outlined, AppColors.warning, 'Per land parcel'),
                  const _KpiData('Pipeline Value', '—',
                      Icons.account_balance_wallet_outlined, AppColors.secondary, 'Active deals'),
                  const _KpiData('Expected Revenue', '—',
                      Icons.insights_outlined, Color(0xFF0891B2), 'Projected'),
                ]),

                const SizedBox(height: 28),

                // ── Reports header ────────────────────────────────
                const _Header(
                  title: 'Reports',
                  subtitle: 'Generate and download detailed reports',
                  icon: Icons.assessment_outlined,
                ),
                const SizedBox(height: 16),

                // ── Report cards ──────────────────────────────────
                _reportGrid(context, [
                  const _ReportData('Lead Report',
                      'Full list of leads with status, source and contact details',
                      Icons.people_outline, AppColors.info),
                  const _ReportData('Competitor Report',
                      'Nearby projects, pricing benchmarks and market positioning',
                      Icons.business_outlined, AppColors.error),
                  const _ReportData('Pricing Report',
                      'Land valuation, market rate comparison and price trends',
                      Icons.price_change_outlined, AppColors.success),
                  const _ReportData('Legal Status Report',
                      'Legal verification outcomes and pending approvals',
                      Icons.gavel_outlined, Color(0xFF7C3AED)),
                  const _ReportData('Acquisition Pipeline Report',
                      'Stage-wise breakdown of all deals in the pipeline',
                      Icons.account_tree_outlined, AppColors.primary),
                  const _ReportData('Broker Performance Report',
                      'Lead conversion rates and revenue generated per broker',
                      Icons.handshake_outlined, AppColors.warning),
                  const _ReportData('Field Executive Report',
                      'Site visits completed, leads added and task completion rate',
                      Icons.directions_walk_outlined, AppColors.secondary),
                  const _ReportData('ROI Report',
                      'Return on investment analysis across all acquisitions',
                      Icons.show_chart_outlined, Color(0xFF0891B2)),
                ]),

                const SizedBox(height: 20),
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

  Widget _reportGrid(BuildContext context, List<_ReportData> reports) {
    final width = MediaQuery.of(context).size.width;
    if (width > 700) {
      // 2-column grid on wide screens
      final rows = <Widget>[];
      for (int i = 0; i < reports.length; i += 2) {
        rows.add(Row(children: [
          Expanded(child: _ReportCard(reports[i])),
          const SizedBox(width: 12),
          Expanded(child: i + 1 < reports.length ? _ReportCard(reports[i + 1]) : const SizedBox()),
        ]));
        if (i + 2 < reports.length) rows.add(const SizedBox(height: 12));
      }
      return Column(children: rows);
    }
    return Column(
      children: reports
          .map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ReportCard(r),
              ))
          .toList(),
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
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
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
  const _KpiData(this.label, this.value, this.icon, this.color, this.sub);
}

class _KpiCard extends StatelessWidget {
  final _KpiData d;
  const _KpiCard(this.d);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: d.color, width: 4)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
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
                  size: 12, color: AppColors.textSecondary.withValues(alpha: 0.4)),
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
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(d.sub,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
            ]),
          ],
        ),
      );
}

// ── Report card ────────────────────────────────────────────────────────────────
class _ReportData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  const _ReportData(this.title, this.description, this.icon, this.color);
}

class _ReportCard extends StatelessWidget {
  final _ReportData d;
  const _ReportCard(this.d);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: d.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(d.icon, color: d.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(d.description,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(mainAxisSize: MainAxisSize.min, children: [
            _ActionBtn(Icons.download_outlined, 'PDF', d.color),
            const SizedBox(height: 6),
            const _ActionBtn(Icons.table_chart_outlined, 'XLS', AppColors.success),
          ]),
        ]),
      );
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _ActionBtn(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: color, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
}
