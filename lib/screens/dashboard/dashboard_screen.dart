import 'package:flutter/material.dart';
import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
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
      appBar: const FomraAppBar(moduleName: 'Dashboard'),
      drawer: const AppDrawer(currentRoute: '/dashboard'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/dashboard'),
      backgroundColor: context.fomraPageBg,
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
  const _KpiData(this.label, this.value, this.icon, this.color, this.sub);
}

class _KpiCard extends StatelessWidget {
  final _KpiData d;
  const _KpiCard(this.d);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.fomraSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: d.color, width: 4)),
          boxShadow: context.fomraCardShadow,
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
      );
}
