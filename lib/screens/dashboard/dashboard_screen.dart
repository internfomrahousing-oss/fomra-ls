import 'package:flutter/material.dart';
import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../land_lead/lead_detail_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
import '../../widgets/fomra_portal_body.dart';

enum _KpiFilter { total, active, acquired, rejected }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _kRecentCollapsedCount = 6;
  bool _showAllRecent = false;

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

  int _countByStatus(LeadStatus status) =>
      AppStore.instance.leads.where((l) => l.status == status).length;

  List<LandLead> get _sortedLeads {
    final leads = List<LandLead>.from(AppStore.instance.leads);
    leads.sort((a, b) => b.addedOn.compareTo(a.addedOn));
    return leads;
  }

  List<LandLead> get _recentLeads {
    final leads = _sortedLeads;
    if (_showAllRecent) return leads;
    return leads.take(_kRecentCollapsedCount).toList();
  }

  List<double> _trendByDays(int days) {
    final now = DateTime.now();
    final buckets = List<double>.filled(days, 0);
    for (final lead in AppStore.instance.leads) {
      final diff = now.difference(DateTime(
        lead.addedOn.year,
        lead.addedOn.month,
        lead.addedOn.day,
      ));
      final idx = days - 1 - diff.inDays;
      if (idx >= 0 && idx < days) buckets[idx] += 1;
    }
    return buckets;
  }

  @override
  Widget build(BuildContext context) {
    final leads = AppStore.instance.leads;
    final totalLeads = leads.length;
    final activeLeads = _leadsForFilter(_KpiFilter.active).length;
    final acquired = _leadsForFilter(_KpiFilter.acquired).length;
    final rejected = _leadsForFilter(_KpiFilter.rejected).length;

    final newLeads = _countByStatus(LeadStatus.new_);
    final contacted = _countByStatus(LeadStatus.contacted);
    final negotiation = _countByStatus(LeadStatus.negotiation);
    final weeklyTrend = _trendByDays(7);
    final maxPipeline = [newLeads, contacted, negotiation, acquired]
        .fold<int>(1, (a, b) => a > b ? a : b);

    final accentBlue =
        context.isDarkMode ? const Color(0xFF4A6FA5) : AppColors.primaryDark;

    // KPI accent colors — tuned to stay clearly visible on BOTH light and dark
    // themes (saturated 600-shade on light, brighter 400-shade on dark).
    final isDark = context.isDarkMode;
    final kpiBlue   = isDark ? AppColors.primaryLight : AppColors.primary;
    final kpiIndigo = isDark ? AppColors.accentLight : AppColors.secondary;
    final kpiGreen  = isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final kpiRed    = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);

    return Scaffold(
      appBar: const FomraAppBar(moduleName: 'Dashboard'),
      drawer: const AppDrawer(currentRoute: '/dashboard'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/dashboard'),
      backgroundColor: context.fomraPageBg,
      body: FomraPortalBody(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              title: 'Management Dashboard',
              subtitle: 'Real-time overview of your land acquisition pipeline',
              icon: Icons.dashboard_outlined,
              accentColor: accentBlue,
            ),
            const SizedBox(height: 16),
            _kpiGrid(context, [
              _KpiData(
                'Total Leads',
                '$totalLeads',
                Icons.location_on_outlined,
                kpiBlue,
                '+$totalLeads total',
                '+18%',
                weeklyTrend,
                _KpiFilter.total,
                _openKpiLeads,
              ),
              _KpiData(
                'Active Leads',
                '$activeLeads',
                Icons.trending_up_outlined,
                kpiIndigo,
                'In pipeline',
                '+8%',
                [newLeads.toDouble(), contacted.toDouble(), negotiation.toDouble(), activeLeads.toDouble()],
                _KpiFilter.active,
                _openKpiLeads,
              ),
              _KpiData(
                'Acquired Land',
                '$acquired',
                Icons.check_circle_outline,
                kpiGreen,
                'Closed deals',
                '+4%',
                [0, 1, 1, 2, 2, 3, acquired.toDouble()],
                _KpiFilter.acquired,
                _openKpiLeads,
              ),
              _KpiData(
                'Rejected Leads',
                '$rejected',
                Icons.cancel_outlined,
                kpiRed,
                'Lost / rejected',
                '-2%',
                [0, 0, 1, 0, 1, 1, rejected.toDouble()],
                _KpiFilter.rejected,
                _openKpiLeads,
              ),
            ]),
            const SizedBox(height: 20),
            _AnalyticsCard(
              title: 'Pipeline Funnel',
              subtitle: 'Track lead progression from new to acquired',
              child: Column(
                children: [
                  _FunnelRow(
                    label: 'New',
                    value: newLeads,
                    maxValue: maxPipeline,
                    color: LeadStatus.new_.color,
                  ),
                  _FunnelRow(
                    label: 'Contacted',
                    value: contacted,
                    maxValue: maxPipeline,
                    color: LeadStatus.contacted.color,
                  ),
                  _FunnelRow(
                    label: 'Negotiation',
                    value: negotiation,
                    maxValue: maxPipeline,
                    color: LeadStatus.negotiation.color,
                  ),
                  _FunnelRow(
                    label: 'Acquired',
                    value: acquired,
                    maxValue: maxPipeline,
                    color: LeadStatus.closed.color,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _AnalyticsCard(
              title: 'Recent Lead Activity',
              subtitle: 'Latest updates in your pipeline',
              child: _recentLeads.isEmpty
                  ? Text('No lead activity yet.',
                      style: TextStyle(color: context.fomraTextSecondary))
                  : Column(
                      children: [
                        ..._recentLeads.map((lead) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ActivityRow(
                                lead: lead,
                                accentColor: accentBlue,
                              ),
                            )),
                        if (_sortedLeads.length > _kRecentCollapsedCount)
                          Align(
                            alignment: Alignment.center,
                            child: TextButton.icon(
                              onPressed: () => setState(
                                  () => _showAllRecent = !_showAllRecent),
                              icon: Icon(
                                _showAllRecent
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 18,
                              ),
                              label: Text(_showAllRecent
                                  ? 'Show less'
                                  : 'Show all (${_sortedLeads.length})'),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
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
        childAspectRatio: width > 900 ? 1.45 : width > 600 ? 1.35 : 1.05,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
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
  final Color accentColor;
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: accentColor, size: 22),
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
  final String trend;
  final List<double> sparkline;
  final _KpiFilter filter;
  final void Function(_KpiData) onTap;

  const _KpiData(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.sub,
    this.trend,
    this.sparkline,
    this.filter,
    this.onTap,
  );
}

class _KpiCard extends StatefulWidget {
  final _KpiData d;
  const _KpiCard(this.d);

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final radius = BorderRadius.circular(AppColors.radiusSm);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: context.fomraSurface,
        borderRadius: radius,
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: () => d.onTap(d),
          borderRadius: radius,
          child: AnimatedContainer(
            duration: AppMotion.normal,
            curve: AppMotion.curve,
            transform: _hovered
                ? Matrix4.translationValues(0, -3, 0)
                : Matrix4.identity(),
            decoration: BoxDecoration(
              color: context.fomraSurface,
              borderRadius: radius,
              border: Border(left: BorderSide(color: d.color, width: 4)),
              boxShadow: _hovered
                  ? AppColors.elevatedShadow
                  : context.fomraCardShadow,
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: d.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(d.icon, color: d.color, size: 18),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: d.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      d.trend,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: d.color,
                      ),
                    ),
                  ),
                ]),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: double.tryParse(d.value) ?? 0),
                    duration: const Duration(milliseconds: 600),
                    builder: (_, value, __) => Text('${value.toInt()}',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: d.color,
                            height: 1.1)),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 22,
                    child: _MiniSparkline(values: d.sparkline, color: d.color),
                  ),
                  const SizedBox(height: 6),
                  Text(d.label,
                      style: TextStyle(
                          fontSize: 12,
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
      ),
    );
  }
}

class _MiniSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  const _MiniSparkline({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return const SizedBox.shrink();
    final maxV = values.fold<double>(1, (a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values
          .map((v) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    height: ((v / maxV) * 20).clamp(4, 20),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _AnalyticsCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.fomraSurface,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: context.fomraBorder),
        boxShadow: context.fomraCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.fomraTextPrimary)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(fontSize: 12, color: context.fomraTextSecondary)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _FunnelRow extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;
  const _FunnelRow({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final factor =
        maxValue <= 0 ? 0.0 : (value / maxValue).toDouble().clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: context.fomraTextSecondary)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: factor,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$value',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: context.fomraTextPrimary)),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final LandLead lead;
  final Color accentColor;
  const _ActivityRow({required this.lead, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final location = [lead.location, lead.village]
        .where((s) => s.isNotEmpty)
        .join(', ');
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: accentColor.withValues(alpha: 0.12),
          child: Icon(Icons.location_on_outlined,
              size: 16, color: accentColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${lead.leadId} · ${lead.ownerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.fomraTextPrimary)),
              if (location.isNotEmpty)
                Text(location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: context.fomraTextSecondary)),
            ],
          ),
        ),
        Text(
          '${lead.addedOn.day}/${lead.addedOn.month}',
          style: TextStyle(fontSize: 11, color: context.fomraTextSecondary),
        ),
      ],
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
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppColors.radiusLg)),
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
                    borderRadius: BorderRadius.circular(12),
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

  @override
  Widget build(BuildContext context) {
    final statusColor = lead.status.color;
    final accentColor = context.isDarkMode
        ? const Color(0xFF4A6FA5)
        : AppColors.primaryDark;
    final location = [lead.location, lead.village, lead.district]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return Material(
      color: context.fomraSurfaceVar,
      borderRadius: BorderRadius.circular(16),
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
        borderRadius: BorderRadius.circular(16),
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
                        color: accentColor,
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
