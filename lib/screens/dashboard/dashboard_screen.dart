import 'package:flutter/material.dart';

import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
import '../../widgets/ui/app_components.dart';
import '../land_lead/lead_detail_screen.dart';

enum _KpiFilter { total, active, acquired, rejected }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _kRecentCollapsedCount = 6;
  static const _kAllEmployees = 'All';
  bool _showAllRecent = false;
  bool _generatingReport = false;
  LeadReportType _selectedReportType = LeadReportType.all;
  String _selectedEmployeeReport = _kAllEmployees;

  List<String> get _employeeNames {
    final names = <String>{};
    for (final e in AppStore.instance.employees) {
      final name = e.fullName.trim();
      if (name.isNotEmpty) names.add(name);
    }
    for (final l in AppStore.instance.leads) {
      final name = l.createdByName.trim();
      if (name.isNotEmpty) names.add(name);
    }
    final sorted = names.toList()..sort((a, b) => a.compareTo(b));
    return [_kAllEmployees, ...sorted];
  }

  Future<void> _createReport() async {
    if (_generatingReport) return;
    final opts = await showModalBottomSheet<_ReportOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReportOptionsSheet(
        initialType: _selectedReportType,
        initialEmployeeName: _selectedEmployeeReport,
        employeeNames: _employeeNames,
      ),
    );
    if (opts == null) return;

    _selectedReportType = opts.type;
    _selectedEmployeeReport = opts.employeeName;
    setState(() => _generatingReport = true);
    try {
      await ReportService.generateLeadsReport(
        AppStore.instance.leads,
        employees: AppStore.instance.employees,
        reportType: opts.type,
        employeeName: opts.type == LeadReportType.employeeLeads
            ? opts.employeeName
            : null,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Couldn’t create report: ${e.toString().replaceFirst('Exception: ', '')}'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

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

  int _countByStatus(LeadStatus status) =>
      AppStore.instance.leads.where((l) => l.status == status).length;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

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

  List<double> _trendByDays(int days, List<LandLead> leads) {
    final now = DateTime.now();
    final buckets = List<double>.filled(days, 0);
    for (final lead in leads) {
      final diff = now.difference(
        DateTime(lead.addedOn.year, lead.addedOn.month, lead.addedOn.day),
      );
      final idx = days - 1 - diff.inDays;
      if (idx >= 0 && idx < days) buckets[idx] += 1;
    }
    return buckets;
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int _countLeadsBetween(List<LandLead> leads, DateTime start, DateTime end) {
    final s = _dayOnly(start);
    final e = _dayOnly(end);
    return leads.where((l) {
      final d = _dayOnly(l.addedOn);
      return !d.isBefore(s) && !d.isAfter(e);
    }).length;
  }

  /// Week-over-week % change from real lead dates (not placeholders).
  ({String label, bool up, bool neutral}) _weekOverWeekTrend(
    List<LandLead> leads, {
    bool lowerIsBetter = false,
  }) {
    final today = _dayOnly(DateTime.now());
    final thisWeekStart = today.subtract(const Duration(days: 6));
    final lastWeekEnd = today.subtract(const Duration(days: 7));
    final lastWeekStart = today.subtract(const Duration(days: 13));

    final thisWeek = _countLeadsBetween(leads, thisWeekStart, today);
    final lastWeek = _countLeadsBetween(leads, lastWeekStart, lastWeekEnd);

    if (thisWeek == 0 && lastWeek == 0) {
      return (label: '0%', up: true, neutral: true);
    }
    if (lastWeek == 0) {
      final up = lowerIsBetter ? false : true;
      return (label: '+100%', up: up, neutral: false);
    }

    final pct = (((thisWeek - lastWeek) / lastWeek) * 100).round();
    if (pct == 0) return (label: '0%', up: true, neutral: true);

    final improved = pct > 0;
    final up = lowerIsBetter ? !improved : improved;
    final sign = pct > 0 ? '+' : '';
    return (label: '$sign$pct%', up: up, neutral: false);
  }

  void _openKpiLeads(_KpiData kpi) {
    final leads = _leadsForFilter(kpi.filter);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KpiLeadsSheet(
        title: kpi.label,
        subtitle: kpi.secondary,
        color: kpi.accent,
        leads: leads,
      ),
    );
  }

  void _goTo(String route) => Navigator.pushNamed(context, route);

  @override
  Widget build(BuildContext context) {
    final leads = AppStore.instance.leads;
    final now = DateTime.now();
    final isDark = context.isDarkMode;

    final totalLeads = leads.length;
    final activeLeads = _leadsForFilter(_KpiFilter.active).length;
    final acquired = _leadsForFilter(_KpiFilter.acquired).length;
    final rejected = _leadsForFilter(_KpiFilter.rejected).length;

    final newLeads = _countByStatus(LeadStatus.new_);
    final contacted = _countByStatus(LeadStatus.contacted);
    final negotiation = _countByStatus(LeadStatus.negotiation);
    final pendingActions = newLeads + negotiation;
    final addedToday = leads.where((l) => _isSameDay(l.addedOn, now)).length;
    final addedThisMonth =
        leads.where((l) => _isSameMonth(l.addedOn, now)).length;
    final acquiredToday = _leadsForFilter(_KpiFilter.acquired)
        .where((l) => _isSameDay(l.addedOn, now))
        .length;

    final totalLeadsList = _leadsForFilter(_KpiFilter.total);
    final activeLeadsList = _leadsForFilter(_KpiFilter.active);
    final acquiredList = _leadsForFilter(_KpiFilter.acquired);
    final rejectedList = _leadsForFilter(_KpiFilter.rejected);

    final totalTrend = _weekOverWeekTrend(totalLeadsList);
    final activeTrend = _weekOverWeekTrend(activeLeadsList);
    final acquiredTrend = _weekOverWeekTrend(acquiredList);
    final rejectedTrend =
        _weekOverWeekTrend(rejectedList, lowerIsBetter: true);

    final weeklyTrend = _trendByDays(7, totalLeadsList);
    final maxPipeline = [newLeads, contacted, negotiation, acquired]
        .fold<int>(1, (a, b) => a > b ? a : b);

    final kpis = [
      _KpiData(
        label: 'Total Leads',
        value: '$totalLeads',
        accent: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
        icon: Icons.location_on_outlined,
        trend: totalTrend.label,
        trendUp: totalTrend.up,
        trendNeutral: totalTrend.neutral,
        secondary: 'Compared with last week',
        todayLabel: 'Today',
        todayValue: '$addedToday',
        periodLabel: 'This month',
        periodValue: '$addedThisMonth',
        sparkline: weeklyTrend,
        filter: _KpiFilter.total,
      ),
      _KpiData(
        label: 'Active Leads',
        value: '$activeLeads',
        accent: isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6),
        icon: Icons.bolt_outlined,
        trend: activeTrend.label,
        trendUp: activeTrend.up,
        trendNeutral: activeTrend.neutral,
        secondary: 'Pipeline in motion',
        todayLabel: 'Pending',
        todayValue: '$pendingActions',
        periodLabel: 'Contacted',
        periodValue: '$contacted',
        sparkline: _trendByDays(7, activeLeadsList),
        filter: _KpiFilter.active,
      ),
      _KpiData(
        label: 'Acquired Land',
        value: '$acquired',
        accent: AppColors.success,
        icon: Icons.check_circle_outline,
        trend: acquiredTrend.label,
        trendUp: acquiredTrend.up,
        trendNeutral: acquiredTrend.neutral,
        secondary: 'Closed conversions',
        todayLabel: 'Today',
        todayValue: '$acquiredToday',
        periodLabel: 'Conversion',
        periodValue: '${totalLeads == 0 ? 0 : ((acquired / totalLeads) * 100).round()}%',
        sparkline: _trendByDays(7, acquiredList),
        filter: _KpiFilter.acquired,
      ),
      _KpiData(
        label: 'Rejected Leads',
        value: '$rejected',
        accent: AppColors.error,
        icon: Icons.cancel_outlined,
        trend: rejectedTrend.label,
        trendUp: rejectedTrend.up,
        trendNeutral: rejectedTrend.neutral,
        secondary: 'Needs follow-up review',
        todayLabel: 'Recovery',
        todayValue: '${(totalLeads - rejected).clamp(0, totalLeads)}',
        periodLabel: 'Loss rate',
        periodValue: '${totalLeads == 0 ? 0 : ((rejected / totalLeads) * 100).round()}%',
        sparkline: _trendByDays(7, rejectedList),
        filter: _KpiFilter.rejected,
      ),
    ];

    return Scaffold(
      appBar: const FomraAppBar(moduleName: 'Dashboard'),
      drawer: const AppDrawer(currentRoute: '/dashboard'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/dashboard'),
      backgroundColor: context.fomraPageBg,
      body: SingleChildScrollView(
        padding: FomraLayout.pagePadding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Overview',
                  subtitle: 'Pipeline KPIs with trends and drill-down detail.',
                  icon: Icons.analytics_outlined,
                ),
                _KpiGrid(
                  kpis: kpis,
                  onTap: _openKpiLeads,
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Reports',
                  subtitle:
                      'Export a PDF covering all leads, acquired leads, broker leads, and each employee’s lead performance.',
                  icon: Icons.picture_as_pdf_outlined,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PrimaryButton(
                      label: _generatingReport
                          ? 'Preparing PDF…'
                          : 'Create PDF Report',
                      icon: Icons.download_rounded,
                      loading: _generatingReport,
                      onPressed: leads.isEmpty ? null : _createReport,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Pipeline funnel',
                  subtitle:
                      'Track lead progression from new to acquired.',
                  icon: Icons.filter_alt_outlined,
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
                const SizedBox(height: 20),
                _SectionCard(
                  title: 'Recent activity',
                  subtitle: 'Latest updates across your land acquisition pipeline.',
                  icon: Icons.history_rounded,
                  child: _recentLeads.isEmpty
                      ? EmptyState(
                          icon: Icons.inbox_outlined,
                          title: 'No leads yet',
                          message:
                              'Create your first lead to start tracking activity on the dashboard.',
                          action: PrimaryButton(
                            label: 'Add Lead',
                            icon: Icons.add_location_alt_outlined,
                            onPressed: () => _goTo('/land-lead'),
                          ),
                        )
                      : Column(
                          children: [
                            for (final lead in _recentLeads) ...[
                              _ActivityRow(lead: lead),
                              if (lead != _recentLeads.last)
                                const SizedBox(height: 12),
                            ],
                            if (_sortedLeads.length > _kRecentCollapsedCount) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => setState(
                                    () => _showAllRecent = !_showAllRecent,
                                  ),
                                  icon: Icon(
                                    _showAllRecent
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                  ),
                                  label: Text(
                                    _showAllRecent
                                        ? 'Show less'
                                        : 'Show all (${_sortedLeads.length})',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KpiData {
  final String label;
  final String value;
  final Color accent;
  final IconData icon;
  final String trend;
  final bool trendUp;
  final bool trendNeutral;
  final String secondary;
  final String todayLabel;
  final String todayValue;
  final String periodLabel;
  final String periodValue;
  final List<double> sparkline;
  final _KpiFilter filter;

  const _KpiData({
    required this.label,
    required this.value,
    required this.accent,
    required this.icon,
    required this.trend,
    required this.trendUp,
    this.trendNeutral = false,
    required this.secondary,
    required this.todayLabel,
    required this.todayValue,
    required this.periodLabel,
    required this.periodValue,
    required this.sparkline,
    required this.filter,
  });
}

class _KpiGrid extends StatelessWidget {
  final List<_KpiData> kpis;
  final void Function(_KpiData) onTap;

  const _KpiGrid({required this.kpis, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cols = width > 1100 ? 4 : width > 760 ? 2 : 1;
    final cardHeight = width > 1100 ? 296.0 : width > 760 ? 288.0 : 272.0;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: kpis.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisExtent: cardHeight,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (_, i) => _KpiCard(data: kpis[i], onTap: () => onTap(kpis[i])),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  final VoidCallback onTap;

  const _KpiCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(20),
      radius: AppColors.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: data.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(data.icon, color: data.accent),
                  ),
                  const Spacer(),
                  StatusChip(
                    label: data.trend,
                    tone: data.trendNeutral
                        ? StatusTone.neutral
                        : data.trendUp
                            ? StatusTone.success
                            : StatusTone.danger,
                    icon: data.trendNeutral
                        ? Icons.remove_rounded
                        : data.trendUp
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              AnimatedCounter(
                value: int.tryParse(data.value) ?? 0,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: context.fomraTextPrimary,
                      height: 1.05,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.fomraTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.secondary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: context.fomraTextSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 28,
                child: _MiniSparkline(values: data.sparkline, color: data.accent),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _KpiMetaBlock(
                  label: data.todayLabel,
                  value: data.todayValue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _KpiMetaBlock(
                  label: data.periodLabel,
                  value: data.periodValue,
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

class _KpiMetaBlock extends StatelessWidget {
  final String label;
  final String value;

  const _KpiMetaBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.fomraTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.fomraTextPrimary,
            ),
          ),
        ],
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
    if (values.isEmpty) return const SizedBox.shrink();

    final maxV = values.fold<double>(0, (a, b) => a > b ? a : b);
    if (maxV <= 0) {
      return Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          height: 3,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values.map((v) {
        final height = v <= 0 ? 3.0 : ((v / maxV) * 28).clamp(6.0, 28.0);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: height,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: v <= 0 ? 0.22 : 0.88),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(22),
      radius: AppColors.radiusLg,
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            padding: const EdgeInsets.only(bottom: 16),
          ),
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.fomraTextPrimary,
                  ),
                ),
              ),
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.fomraTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: factor,
              minHeight: 10,
              backgroundColor: color.withValues(alpha: 0.12),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final LandLead lead;

  const _ActivityRow({required this.lead});

  @override
  Widget build(BuildContext context) {
    final statusColor = lead.status.color;
    final location = [lead.location, lead.village, lead.district]
        .where((s) => s.isNotEmpty)
        .join(', ');

    return Material(
      color: context.fomraSurfaceVar,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.location_on_outlined,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${lead.leadId} · ${lead.ownerName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.fomraTextPrimary,
                            ),
                          ),
                        ),
                        StatusChip(
                          label: lead.status.label,
                          tone: switch (lead.status) {
                            LeadStatus.closed => StatusTone.success,
                            LeadStatus.lost => StatusTone.danger,
                            LeadStatus.negotiation => StatusTone.purple,
                            _ => StatusTone.primary,
                          },
                        ),
                      ],
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      children: [
                        if (lead.surveyNumber.isNotEmpty)
                          _DetailChip(Icons.tag, 'Survey ${lead.surveyNumber}'),
                        if (lead.landExtent.isNotEmpty)
                          _DetailChip(Icons.straighten, lead.landExtent),
                        _DetailChip(Icons.terrain_outlined, lead.landType.label),
                      ],
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
}

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

class _ReportOptions {
  final LeadReportType type;
  final String employeeName;

  const _ReportOptions({
    required this.type,
    required this.employeeName,
  });
}

class _ReportOptionsSheet extends StatefulWidget {
  final LeadReportType initialType;
  final String initialEmployeeName;
  final List<String> employeeNames;

  const _ReportOptionsSheet({
    required this.initialType,
    required this.initialEmployeeName,
    required this.employeeNames,
  });

  @override
  State<_ReportOptionsSheet> createState() => _ReportOptionsSheetState();
}

class _ReportOptionsSheetState extends State<_ReportOptionsSheet> {
  late LeadReportType _type;
  late String _employeeName;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _employeeName = widget.employeeNames.contains(widget.initialEmployeeName)
        ? widget.initialEmployeeName
        : widget.employeeNames.first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fomraSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.fomraBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Create PDF Report',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: context.fomraTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose what to include in the exported report.',
              style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
            ),
            const SizedBox(height: 16),
            ...LeadReportType.values.map((type) {
              final selected = _type == type;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _labelFor(type),
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: context.fomraTextPrimary,
                  ),
                ),
                trailing: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.primary : context.fomraTextTertiary,
                  size: 20,
                ),
                onTap: () => setState(() => _type = type),
              );
            }),
            if (_type == LeadReportType.employeeLeads) ...[
              const SizedBox(height: 4),
              Text(
                'Employee',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.fomraTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: widget.employeeNames.contains(_employeeName)
                    ? _employeeName
                    : widget.employeeNames.first,
                items: widget.employeeNames
                    .map(
                      (name) => DropdownMenuItem<String>(
                        value: name,
                        child: Text(name),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _employeeName = value);
                },
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Generate PDF',
                icon: Icons.picture_as_pdf_outlined,
                onPressed: () => Navigator.pop(
                  context,
                  _ReportOptions(type: _type, employeeName: _employeeName),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelFor(LeadReportType type) {
    return switch (type) {
      LeadReportType.all => 'All',
      LeadReportType.totalLeads => 'Total Leads',
      LeadReportType.acquiredLeads => 'Acquired Leads',
      LeadReportType.brokerLeads => 'Broker Leads',
      LeadReportType.employeeLeads => 'Employee Leads',
    };
  }
}
