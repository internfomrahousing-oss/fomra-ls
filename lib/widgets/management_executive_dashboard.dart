import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../analytics/management_bi_metrics.dart';
import '../analytics/management_intelligence.dart';
import '../models/app_notification.dart';
import '../models/land_lead.dart';
import '../services/dashboard_layout_prefs.dart';
import '../services/management_bi_activity_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import '../utils/lead_location_parser.dart';
import 'management_bi_sections.dart';
import 'management_intelligence_sections.dart';
import 'portal_home_sections.dart';
import 'terms_deal_selector.dart';
import 'ui/app_components.dart';

const _kCardRadius = 20.0;
const _kFocusDistricts = [
  'Chennai',
  'Kanchipuram',
  'Chengalpattu',
  'Thiruvallur',
];

const _kDealCategories = [
  'Outright Purchase',
  'Joint Venture',
  'Marketing',
  'Deferred Payment',
  'Others',
];

// ── Date / KPI helpers (from dashboard_screen patterns) ─────────────────────

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

int _countLeadsBetween(List<LandLead> leads, DateTime start, DateTime end) {
  final s = _dayOnly(start);
  final e = _dayOnly(end);
  return leads.where((l) {
    final d = _dayOnly(l.addedOn);
    return !d.isBefore(s) && !d.isAfter(e);
  }).length;
}

(int current, int previous) _weekOverWeekCounts(List<LandLead> leads) {
  final today = _dayOnly(DateTime.now());
  final thisWeekStart = today.subtract(const Duration(days: 6));
  final lastWeekEnd = today.subtract(const Duration(days: 7));
  final lastWeekStart = today.subtract(const Duration(days: 13));
  final current = _countLeadsBetween(leads, thisWeekStart, today);
  final previous = _countLeadsBetween(leads, lastWeekStart, lastWeekEnd);
  return (current, previous);
}

List<LandLead> _leadsWithStatus(List<LandLead> leads, LeadStatus status) =>
    leads.where((l) => l.status == status).toList();

List<LandLead> _signedLeads(List<LandLead> leads) =>
    leads.where((l) => l.status == LeadStatus.signed).toList();

double _acresFromSqft(double sqft) => sqft / 43560;

double _leadAcres(LandLead lead) {
  final sqft = parseLandExtentSqft(lead.landExtent);
  if (sqft == null) return 0;
  return _acresFromSqft(sqft);
}

String _relativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
  if (diff.inHours < 24) return '${diff.inHours} hours ago';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${time.day}/${time.month}/${time.year}';
}

String _dealCategory(String? primary) {
  if (primary == null || primary.trim().isEmpty) return 'Others';
  final p = primary.trim();
  for (final c in _kDealCategories) {
    if (c == 'Others') continue;
    if (p.toLowerCase() == c.toLowerCase()) return c;
  }
  return 'Others';
}

Map<String, int> _dealTermsDistribution(List<LandLead> leads) {
  final counts = {for (final c in _kDealCategories) c: 0};
  for (final lead in leads) {
    final parsed = parseTermsDeal(lead.accessDetails);
    final cat = _dealCategory(parsed.primary);
    counts[cat] = (counts[cat] ?? 0) + 1;
  }
  return counts;
}

({int signed, int total, double acres}) _employeeMetrics(
  String name,
  List<LandLead> leads,
) {
  final mine = leads
      .where((l) =>
          l.createdByName.trim().toLowerCase() == name.trim().toLowerCase())
      .toList();
  final signed = mine.where((l) => l.status == LeadStatus.signed).length;
  final acres = mine
      .where((l) => l.status == LeadStatus.signed)
      .fold<double>(0, (sum, l) => sum + _leadAcres(l));
  return (
    signed: signed,
    total: mine.length,
    acres: acres,
  );
}

double _conversionPercent(int signed, int total) =>
    total == 0 ? 0 : (signed / total) * 100;

int _starRating(double conversion) {
  if (conversion >= 80) return 5;
  if (conversion >= 60) return 4;
  if (conversion >= 40) return 3;
  if (conversion >= 20) return 2;
  return conversion > 0 ? 1 : 0;
}

// ── Main widget ─────────────────────────────────────────────────────────────

class ManagementExecutiveDashboard extends StatefulWidget {
  final List<LandLead> leads;
  final List<PortalTeamPerf> teamRows;
  final List<AppNotification> notifications;
  final ValueChanged<LandLead>? onViewLead;

  /// When provided, renders exactly these widgets in this order as a fixed
  /// (non-customizable) layout — no toolbar or executive KPI strip. Used to
  /// surface a specific subset of BI widgets on another screen (e.g. Dashboard).
  final List<String>? widgetIds;

  const ManagementExecutiveDashboard({
    super.key,
    required this.leads,
    required this.teamRows,
    required this.notifications,
    this.onViewLead,
    this.widgetIds,
  });

  @override
  State<ManagementExecutiveDashboard> createState() =>
      _ManagementExecutiveDashboardState();
}

class _ManagementExecutiveDashboardState
    extends State<ManagementExecutiveDashboard> {
  ManagementBiActivityBundle _activity = ManagementBiActivityBundle.empty;
  List<String> _order = List.of(DashboardLayoutPrefs.defaultOrder);
  bool _loadingActivity = true;
  bool _customizing = false;

  static const _widgetTitles = {
    'pipeline': 'Pipeline Dashboard',
    'reminders': 'Automatic Reminders',
    'escalations': 'Automatic Escalations',
    'approvals': 'Approval Queue',
    'recommendations': 'AI Recommendations',
    'predictive': 'Predictive Analytics',
    'duplicates': 'Duplicate Detection',
    'funnel': 'Conversion Funnel',
    'ageing': 'Lead Ageing',
    'bottlenecks': 'Bottlenecks',
    'sla': 'SLA Dashboard',
    'executives': 'Executive Performance',
    'heatmap': 'Activity Heat Map',
    'district': 'District Performance',
    'dealTerms': 'Deal Terms',
    'activities': 'Recent Activities',
  };

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant ManagementExecutiveDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leads.length != widget.leads.length) {
      // Refresh activity when lead set changes materially.
      _loadActivity();
    }
  }

  Future<void> _bootstrap() async {
    final order = await DashboardLayoutPrefs.loadOrder();
    if (mounted) setState(() => _order = order);
    await _loadActivity();
  }

  Future<void> _loadActivity() async {
    setState(() => _loadingActivity = true);
    final bundle = await ManagementBiActivityService.loadAll();
    if (!mounted) return;
    setState(() {
      _activity = bundle;
      _loadingActivity = false;
    });
  }

  Future<void> _persistOrder() async {
    await DashboardLayoutPrefs.saveOrder(_order);
  }

  Future<void> _resetOrder() async {
    await DashboardLayoutPrefs.reset();
    if (!mounted) return;
    setState(() {
      _order = List.of(DashboardLayoutPrefs.defaultOrder);
      _customizing = false;
    });
  }

  Widget _buildWidget(
    String id,
    ManagementBiSnapshot snap,
    ManagementIntelligenceSnapshot intel,
    bool isDesktop,
  ) {
    switch (id) {
      case 'pipeline':
        return BiPipelineSection(summary: snap.pipeline);
      case 'reminders':
        return IntelRemindersSection(
          items: intel.reminders,
          onViewLead: widget.onViewLead,
        );
      case 'escalations':
        return IntelEscalationsSection(
          items: intel.escalations,
          onViewLead: widget.onViewLead,
        );
      case 'approvals':
        return IntelApprovalQueueSection(
          items: intel.approvalQueue,
          onViewLead: widget.onViewLead,
        );
      case 'recommendations':
        return IntelSuggestionsSection(
          suggestions: intel.bestSuggestions,
          recommendations: intel.recommendations,
          onViewLead: widget.onViewLead,
        );
      case 'predictive':
        return IntelPredictiveSection(data: intel.predictive);
      case 'duplicates':
        return IntelDuplicatesSection(
          groups: intel.duplicates,
          onViewLead: widget.onViewLead,
        );
      case 'funnel':
        return BiFunnelSection(rows: snap.funnel);
      case 'ageing':
        return BiAgeingSection(
          rows: snap.ageing,
          onViewLead: widget.onViewLead,
        );
      case 'bottlenecks':
        return BiBottleneckSection(rows: snap.bottlenecks);
      case 'sla':
        return BiSlaSection(
          summary: snap.sla,
          onViewLead: widget.onViewLead,
        );
      case 'executives':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BiExecutiveSection(rows: snap.executives),
            const SizedBox(height: AppSpacing.md),
            _EmployeeLeaderboardCard(
              teamRows: widget.teamRows,
              leads: widget.leads,
            ),
          ],
        );
      case 'heatmap':
        return BiHeatmapSection(rows: snap.heatmap);
      case 'district':
        return _DistrictPerformanceCard(leads: widget.leads);
      case 'dealTerms':
        return _DealTermsDonutCard(leads: widget.leads);
      case 'activities':
        return _RecentActivitiesCard(notifications: widget.notifications);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.leads.isEmpty) {
      return const _DashboardCard(
        child: Column(
          children: [
            EmptyState(
              icon: Icons.analytics_outlined,
              title: 'No pipeline data yet',
              message:
                  'Leads added by your team will populate this executive dashboard automatically.',
            ),
            PortalEmptyHint(
              hint: 'Add leads or view the leads list to get started.',
            ),
          ],
        ),
      );
    }

    final snap = ManagementBiMetrics.build(
      leads: widget.leads,
      activity: _activity,
    );
    final intel = ManagementIntelligence.build(
      leads: widget.leads,
      activity: _activity,
    );
    const gap = AppSpacing.md;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;

    // Fixed subset layout (e.g. widgets relocated to the Dashboard screen):
    // no toolbar, no KPI strip, no customize — just the requested widgets.
    final fixed = widget.widgetIds;
    if (fixed != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < fixed.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            _buildWidget(fixed[i], snap, intel, isDesktop),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BiToolbar(
          loading: _loadingActivity,
          customizing: _customizing,
          onToggleCustomize: () => setState(() => _customizing = !_customizing),
          onRefresh: _loadActivity,
          onReset: _resetOrder,
        ),
        SizedBox(height: gap),
        // Keep classic KPI strip as a fixed executive snapshot.
        _ExecutiveTopRow(
          leads: widget.leads,
          isDesktop: isDesktop,
          isTablet: MediaQuery.sizeOf(context).width >= 640,
        ),
        SizedBox(height: gap),
        if (_customizing)
          _CustomizeOrderList(
            order: _order,
            titles: _widgetTitles,
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = _order.removeAt(oldIndex);
                _order.insert(newIndex, item);
              });
              _persistOrder();
            },
          )
        else
          for (var i = 0; i < _order.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            _buildWidget(_order[i], snap, intel, isDesktop),
          ],
      ],
    );
  }
}

class _BiToolbar extends StatelessWidget {
  final bool loading;
  final bool customizing;
  final VoidCallback onToggleCustomize;
  final VoidCallback onRefresh;
  final VoidCallback onReset;

  const _BiToolbar({
    required this.loading,
    required this.customizing,
    required this.onToggleCustomize,
    required this.onRefresh,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Business Intelligence',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.fomraTextPrimary,
          ),
        ),
        if (loading) ...[
          const SizedBox(width: 10),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
        const Spacer(),
        if (customizing)
          TextButton(
            onPressed: onReset,
            child: const Text('Reset layout'),
          ),
        IconButton(
          tooltip: 'Refresh activity data',
          onPressed: loading ? null : onRefresh,
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
        FilledButton.tonalIcon(
          onPressed: onToggleCustomize,
          icon: Icon(
            customizing ? Icons.check_rounded : Icons.dashboard_customize_outlined,
            size: 18,
          ),
          label: Text(customizing ? 'Done' : 'Customize'),
        ),
      ],
    );
  }
}

class _CustomizeOrderList extends StatelessWidget {
  final List<String> order;
  final Map<String, String> titles;
  final void Function(int oldIndex, int newIndex) onReorderItem;

  const _CustomizeOrderList({
    required this.order,
    required this.titles,
    required this.onReorderItem,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      radius: _kCardRadius,
      interactive: false,
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: order.length,
        onReorderItem: onReorderItem,
        buildDefaultDragHandles: false,
        itemBuilder: (context, index) {
          final id = order[index];
          return ListTile(
            key: ValueKey(id),
            leading: ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_indicator, color: context.fomraTextSecondary),
            ),
            title: Text(
              titles[id] ?? id,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text('Widget ${index + 1} of ${order.length}'),
          );
        },
      ),
    );
  }
}

// ── Shared card shell ───────────────────────────────────────────────────────

class _DashboardCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color? borderColor;

  const _DashboardCard({
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
  }) : borderColor = null;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: _kCardRadius,
      interactive: false,
      borderColor: borderColor,
      borderWidth: borderColor != null ? 1.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && icon != null) ...[
            SectionHeader(
              title: title!,
              subtitle: subtitle,
              icon: icon!,
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
            ),
          ],
          child,
        ],
      ),
    );
  }
}

// ── Row 1: KPIs left, deal terms right ────────────────────────────────────────

class _ExecutiveTopRow extends StatelessWidget {
  final List<LandLead> leads;
  final bool isDesktop;
  final bool isTablet;

  const _ExecutiveTopRow({
    required this.leads,
    required this.isDesktop,
    required this.isTablet,
  });

  @override
  Widget build(BuildContext context) {
    const gap = AppSpacing.md;

    if (!isTablet) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroKpiStrip(
            leads: leads,
            isDesktop: isDesktop,
            isTablet: isTablet,
            inRow: false,
          ),
          SizedBox(height: gap),
          _DealTermsDonutCard(leads: leads),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: isDesktop ? 6 : 5,
          child: _HeroKpiStrip(
            leads: leads,
            isDesktop: isDesktop,
            isTablet: isTablet,
            inRow: true,
          ),
        ),
        SizedBox(width: gap),
        Expanded(
          flex: isDesktop ? 4 : 5,
          child: _DealTermsDonutCard(leads: leads, inline: true),
        ),
      ],
    );
  }
}

// ── Row 2: Hero KPI strip ─────────────────────────────────────────────────────

class _HeroKpiStrip extends StatelessWidget {
  final List<LandLead> leads;
  final bool isDesktop;
  final bool isTablet;
  final bool inRow;

  const _HeroKpiStrip({
    required this.leads,
    required this.isDesktop,
    required this.isTablet,
    this.inRow = false,
  });

  @override
  Widget build(BuildContext context) {
    final signed = _signedLeads(leads);
    final signedPct =
        leads.isEmpty ? 0.0 : (signed.length / leads.length) * 100;

    final kpiDefs = [
      _CompactKpiDef(
        label: 'Negotiation',
        filterLeads: _leadsWithStatus(leads, LeadStatus.negotiation),
        allLeads: _leadsWithStatus(leads, LeadStatus.negotiation),
        icon: Icons.handshake_outlined,
        accent: const Color(0xFFEA580C),
        todayLabel: 'Today',
        periodLabel: 'This month',
      ),
      _CompactKpiDef(
        label: 'Legal Verification',
        filterLeads: _leadsWithStatus(leads, LeadStatus.legal),
        allLeads: _leadsWithStatus(leads, LeadStatus.legal),
        icon: Icons.gavel_outlined,
        accent: AppColors.secondary,
        todayLabel: 'Today',
        periodLabel: 'This month',
      ),
    ];

    if (inRow) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _SignedLeadsRing(percent: signedPct, count: signed.length),
          const SizedBox(width: AppSpacing.md),
          for (var i = 0; i < kpiDefs.length; i++) ...[
            Expanded(child: _CompactKpiCard(def: kpiDefs[i])),
            if (i < kpiDefs.length - 1) const SizedBox(width: AppSpacing.md),
          ],
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _SignedLeadsRing(percent: signedPct, count: signed.length),
        for (final def in kpiDefs)
          SizedBox(
            width: isDesktop ? 220 : isTablet ? 240 : double.infinity,
            child: _CompactKpiCard(def: def),
          ),
      ],
    );
  }
}

class _SignedLeadsRing extends StatelessWidget {
  final double percent;
  final int count;

  const _SignedLeadsRing({required this.percent, required this.count});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: percent.clamp(0, 100)),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      builder: (context, animatedPct, _) {
        return SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: CircularProgressIndicator(
                  value: animatedPct / 100,
                  strokeWidth: 10,
                  backgroundColor:
                      context.fomraSurfaceVar.withValues(alpha: 0.6),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${animatedPct.round()}%',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                  Text(
                    'Signed Leads',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.fomraTextSecondary,
                    ),
                  ),
                  Text(
                    '$count total',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.fomraTextTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CompactKpiDef {
  final String label;
  final List<LandLead> filterLeads;
  final List<LandLead> allLeads;
  final IconData icon;
  final Color accent;
  final String todayLabel;
  final String periodLabel;

  const _CompactKpiDef({
    required this.label,
    required this.filterLeads,
    required this.allLeads,
    required this.icon,
    required this.accent,
    required this.todayLabel,
    required this.periodLabel,
  });
}

class _CompactKpiCard extends StatelessWidget {
  final _CompactKpiDef def;

  const _CompactKpiCard({required this.def});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final trend = _weekOverWeekCounts(def.allLeads);
    final today =
        def.allLeads.where((l) => _isSameDay(l.addedOn, now)).length;
    final period =
        def.allLeads.where((l) => _isSameMonth(l.addedOn, now)).length;

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: def.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(def.icon, color: def.accent, size: 18),
              ),
              const Spacer(),
              KpiPerformanceBadge(
                currentValue: trend.$1,
                previousValue: trend.$2,
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedCounter(
            value: def.filterLeads.length,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          Text(
            def.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _KpiMetaChip(label: def.todayLabel, value: '$today'),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _KpiMetaChip(label: def.periodLabel, value: '$period'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiMetaChip extends StatelessWidget {
  final String label;
  final String value;

  const _KpiMetaChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: context.fomraTextSecondary),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.fomraTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row 1: Deal Terms Donut ───────────────────────────────────────────────────

class _DealTermsDonutCard extends StatefulWidget {
  final List<LandLead> leads;
  final bool inline;

  const _DealTermsDonutCard({
    required this.leads,
    this.inline = false,
  });

  @override
  State<_DealTermsDonutCard> createState() => _DealTermsDonutCardState();
}

class _DealTermsDonutCardState extends State<_DealTermsDonutCard> {
  int _touchedIndex = -1;

  static const _colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.warning,
    AppColors.success,
    AppColors.cyan,
  ];

  @override
  Widget build(BuildContext context) {
    final dist = _dealTermsDistribution(widget.leads);
    final total = dist.values.fold<int>(0, (a, b) => a + b);
    final sections = <PieChartSectionData>[];

    final chartSize = widget.inline ? 120.0 : 180.0;
    final pieRadius = widget.inline ? 36.0 : 46.0;
    final touchedRadius = widget.inline ? 40.0 : 52.0;
    final centerRadius = widget.inline ? 28.0 : 42.0;

    for (var i = 0; i < _kDealCategories.length; i++) {
      final cat = _kDealCategories[i];
      final count = dist[cat] ?? 0;
      if (count == 0 && total > 0) continue;
      final pct = total == 0 ? 0.0 : (count / total) * 100;
      final touched = i == _touchedIndex;
      sections.add(
        PieChartSectionData(
          value: count == 0 ? 1 : count.toDouble(),
          title: touched ? '${pct.round()}%' : '',
          titleStyle: TextStyle(
            fontSize: widget.inline ? 9 : 11,
            fontWeight: FontWeight.w700,
            color: context.fomraTextPrimary,
          ),
          color: _colors[i % _colors.length],
          radius: touched ? touchedRadius : pieRadius,
          titlePositionPercentageOffset: 0.55,
        ),
      );
    }

    if (sections.isEmpty) {
      sections.add(
        PieChartSectionData(
          value: 1,
          color: context.fomraSurfaceVar,
          radius: pieRadius,
          title: '',
        ),
      );
    }

    final legend = Wrap(
      spacing: widget.inline ? 6 : 8,
      runSpacing: widget.inline ? 4 : 6,
      children: List.generate(_kDealCategories.length, (i) {
        final cat = _kDealCategories[i];
        final count = dist[cat] ?? 0;
        final pct = total == 0 ? 0 : ((count / total) * 100).round();
        return _LegendChip(
          color: _colors[i % _colors.length],
          label: cat,
          value: '$pct%',
          selected: i == _touchedIndex,
          compact: widget.inline,
        );
      }),
    );

    final chart = SizedBox(
      width: widget.inline ? chartSize : null,
      height: chartSize,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: centerRadius,
          sections: sections,
          pieTouchData: PieTouchData(
            touchCallback: (event, response) {
              setState(() {
                if (response?.touchedSection == null) {
                  _touchedIndex = -1;
                } else {
                  _touchedIndex =
                      response!.touchedSection!.touchedSectionIndex;
                }
              });
            },
          ),
        ),
      ),
    );

    return _DashboardCard(
      title: 'Deal Terms Distribution',
      subtitle: widget.inline ? null : 'Parsed from access details',
      icon: Icons.pie_chart_outline_rounded,
      child: widget.inline
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                chart,
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: legend),
              ],
            )
          : Column(
              children: [
                chart,
                const SizedBox(height: AppSpacing.sm),
                legend,
              ],
            ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  final bool selected;
  final bool compact;

  const _LegendChip({
    required this.color,
    required this.label,
    required this.value,
    this.selected = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: selected ? color.withValues(alpha: 0.14) : context.fomraSurfaceVar,
        borderRadius: BorderRadius.circular(8),
        border: selected ? Border.all(color: color.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: context.fomraTextSecondary),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: context.fomraTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row 4: District Performance ───────────────────────────────────────────────

enum _DistrictSort { district, acres, deals, rate }

class _DistrictPerformanceCard extends StatefulWidget {
  final List<LandLead> leads;

  const _DistrictPerformanceCard({required this.leads});

  @override
  State<_DistrictPerformanceCard> createState() =>
      _DistrictPerformanceCardState();
}

class _DistrictRow {
  final String district;
  final double acres;
  final int total;
  final int signed;
  final double rate;
  final bool isFocus;

  const _DistrictRow({
    required this.district,
    required this.acres,
    required this.total,
    required this.signed,
    required this.rate,
    required this.isFocus,
  });
}

class _DistrictPerformanceCardState extends State<_DistrictPerformanceCard> {
  _DistrictSort _sort = _DistrictSort.rate;
  bool _asc = false;

  List<_DistrictRow> _buildRows() {
    final byDistrict = <String, List<LandLead>>{};
    for (final lead in widget.leads) {
      final d = lead.district.trim();
      if (d.isEmpty) continue;
      byDistrict.putIfAbsent(d, () => []).add(lead);
    }

    final rows = <_DistrictRow>[];
    for (final entry in byDistrict.entries) {
      final signed =
          entry.value.where((l) => l.status == LeadStatus.signed).toList();
      final acres = signed.fold<double>(0, (s, l) => s + _leadAcres(l));
      final total = entry.value.length;
      final rate = _conversionPercent(signed.length, total);
      final isFocus = _kFocusDistricts.any(
        (f) => f.toLowerCase() == entry.key.toLowerCase(),
      );
      rows.add(_DistrictRow(
        district: entry.key,
        acres: acres,
        total: total,
        signed: signed.length,
        rate: rate,
        isFocus: isFocus,
      ));
    }

    rows.sort((a, b) {
      int cmp;
      switch (_sort) {
        case _DistrictSort.district:
          cmp = a.district.compareTo(b.district);
        case _DistrictSort.acres:
          cmp = a.acres.compareTo(b.acres);
        case _DistrictSort.deals:
          cmp = a.total.compareTo(b.total);
        case _DistrictSort.rate:
          cmp = a.rate.compareTo(b.rate);
      }
      if (a.isFocus != b.isFocus) return a.isFocus ? -1 : 1;
      return _asc ? cmp : -cmp;
    });

    return rows;
  }

  void _toggleSort(_DistrictSort col) {
    setState(() {
      if (_sort == col) {
        _asc = !_asc;
      } else {
        _sort = col;
        _asc = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _buildRows();
    final maxAcres = rows.fold<double>(0, (m, r) => math.max(m, r.acres));

    return _DashboardCard(
      title: 'District Performance',
      subtitle: 'Chennai region focus districts',
      icon: Icons.map_outlined,
      child: rows.isEmpty
          ? Text(
              'No district data available.',
              style: TextStyle(color: context.fomraTextSecondary),
            )
          : Column(
              children: [
                _DistrictTableHeader(onSort: _toggleSort, sort: _sort),
                const SizedBox(height: 6),
                for (final row in rows.take(12)) ...[
                  _DistrictTableRow(
                    row: row,
                    maxAcres: maxAcres == 0 ? 1 : maxAcres,
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
    );
  }
}

class _DistrictTableHeader extends StatelessWidget {
  final void Function(_DistrictSort) onSort;
  final _DistrictSort sort;

  const _DistrictTableHeader({required this.onSort, required this.sort});

  @override
  Widget build(BuildContext context) {
    Widget hdr(String label, _DistrictSort col, {int flex = 1}) {
      final active = sort == col;
      return Expanded(
        flex: flex,
        child: InkWell(
          onTap: () => onSort(col),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: active
                    ? AppColors.primary
                    : context.fomraTextSecondary,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        hdr('District', _DistrictSort.district, flex: 2),
        hdr('Acres', _DistrictSort.acres),
        hdr('Deals', _DistrictSort.deals),
        hdr('Rate', _DistrictSort.rate),
      ],
    );
  }
}

class _DistrictTableRow extends StatelessWidget {
  final _DistrictRow row;
  final double maxAcres;

  const _DistrictTableRow({required this.row, required this.maxAcres});

  @override
  Widget build(BuildContext context) {
    final progress = (row.acres / maxAcres).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: row.isFocus
            ? AppColors.primary.withValues(alpha: 0.04)
            : context.fomraSurfaceVar.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: row.isFocus
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : context.fomraSurfaceVar,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        row.district,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.fomraTextPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  row.acres.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.fomraTextPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${row.total}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.fomraTextPrimary,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${row.rate.round()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: context.fomraBorder.withValues(alpha: 0.3),
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row 4: Recent Activities ──────────────────────────────────────────────────

class _RecentActivitiesCard extends StatelessWidget {
  final List<AppNotification> notifications;

  const _RecentActivitiesCard({required this.notifications});

  (IconData, Color) _activityStyle(AppNotification n) {
    final t = '${n.title} ${n.message}'.toLowerCase();
    if (t.contains('assigned')) {
      return (Icons.person_add_alt_1_outlined, AppColors.info);
    }
    if (n.type == NotificationType.siteVisit || t.contains('site visit')) {
      return (Icons.apartment_outlined, AppColors.primary);
    }
    if (t.contains('legal') || t.contains('document')) {
      return (Icons.description_outlined, AppColors.success);
    }
    if (t.contains('joint venture') || t.contains('jv')) {
      return (Icons.handshake_outlined, AppColors.secondary);
    }
    if (t.contains('registration')) {
      return (Icons.assignment_turned_in_outlined, AppColors.warning);
    }
    if (t.contains('agreement') || t.contains('signed')) {
      return (Icons.verified_outlined, AppColors.success);
    }
    return switch (n.type) {
      NotificationType.lead => (Icons.location_on_outlined, AppColors.info),
      NotificationType.assignedLead =>
        (Icons.assignment_ind_outlined, AppColors.info),
      NotificationType.pendingLead =>
        (Icons.hourglass_bottom_outlined, AppColors.warning),
      NotificationType.pendingApproval =>
        (Icons.approval_outlined, AppColors.warning),
      NotificationType.slaBreach =>
        (Icons.timer_off_outlined, AppColors.error),
      NotificationType.overdueTask =>
        (Icons.assignment_late_outlined, AppColors.error),
      NotificationType.reminder =>
        (Icons.notifications_active_outlined, AppColors.info),
      NotificationType.task => (Icons.task_alt_outlined, AppColors.warning),
      NotificationType.document =>
        (Icons.description_outlined, AppColors.success),
      NotificationType.verification =>
        (Icons.verified_outlined, AppColors.secondary),
      NotificationType.siteVisit =>
        (Icons.apartment_outlined, AppColors.primary),
      NotificationType.alert => (Icons.warning_amber, AppColors.error),
    };
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...notifications]
      ..sort((a, b) => b.time.compareTo(a.time));
    final items = sorted.take(10).toList();

    return _DashboardCard(
      title: 'Recent Activities',
      subtitle: 'Latest team updates',
      icon: Icons.history_rounded,
      child: items.isEmpty
          ? Text(
              'No recent activity.',
              style: TextStyle(color: context.fomraTextSecondary),
            )
          : Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _ActivityTile(
                    notification: items[i],
                    style: _activityStyle(items[i]),
                    isLast: i == items.length - 1,
                  ),
                ],
              ],
            ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final AppNotification notification;
  final (IconData, Color) style;
  final bool isLast;

  const _ActivityTile({
    required this.notification,
    required this.style,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color) = style;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: context.fomraBorder.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.fomraTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(notification.time),
                    style: TextStyle(
                      fontSize: 10,
                      color: context.fomraTextTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Row 5: Employee Leaderboard ─────────────────────────────────────────────

class _EmployeeLeaderboardCard extends StatelessWidget {
  final List<PortalTeamPerf> teamRows;
  final List<LandLead> leads;

  const _EmployeeLeaderboardCard({
    required this.teamRows,
    required this.leads,
  });

  @override
  Widget build(BuildContext context) {
    final top = teamRows.take(10).toList();

    return _DashboardCard(
      title: 'Employee Leaderboard',
      subtitle: 'Top performers by conversion',
      icon: Icons.emoji_events_outlined,
      child: top.isEmpty
          ? Text(
              'No employee activity yet.',
              style: TextStyle(color: context.fomraTextSecondary),
            )
          : Column(
              children: [
                for (final row in top) ...[
                  _LeaderboardRow(row: row, leads: leads),
                  if (row != top.last) const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final PortalTeamPerf row;
  final List<LandLead> leads;

  const _LeaderboardRow({required this.row, required this.leads});

  @override
  Widget build(BuildContext context) {
    final metrics = _employeeMetrics(row.name, leads);
    final conversion = _conversionPercent(metrics.signed, metrics.total);
    final stars = _starRating(conversion);
    final isTop = row.rank == 1;
    final accent = isTop ? AppColors.accentLight : AppColors.primary;

    final initials = row.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return _DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: accent.withValues(alpha: 0.15),
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isTop ? AppColors.warning : AppColors.primary,
                      ),
                    ),
                  ),
                  if (isTop)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppColors.accentLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.fomraTextPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isTop
                                ? AppColors.accentLight.withValues(alpha: 0.2)
                                : context.fomraSurfaceVar,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '#${row.rank}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isTop
                                  ? const Color(0xFFB45309)
                                  : context.fomraTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      row.designation.isNotEmpty
                          ? row.designation
                          : row.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(row.percent * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Score',
                    style: TextStyle(
                      fontSize: 9,
                      color: context.fomraTextTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _LeaderStat(label: 'Leads', value: '${metrics.total}'),
              _LeaderStat(label: 'Closed', value: '${metrics.signed}'),
              _LeaderStat(
                label: 'Acres',
                value: metrics.acres.toStringAsFixed(1),
              ),
              _LeaderStat(
                label: 'Conv.',
                value: '${conversion.round()}%',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(5, (i) {
                return Icon(
                  i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 14,
                  color: i < stars
                      ? AppColors.warning
                      : context.fomraTextTertiary,
                );
              }),
              const Spacer(),
              Text(
                '${conversion.round()}% conversion',
                style: TextStyle(
                  fontSize: 10,
                  color: context.fomraTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: row.percent.clamp(0.0, 1.0)),
            duration: AppMotion.slow,
            curve: AppMotion.curve,
            builder: (_, v, __) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: v,
                minHeight: 6,
                backgroundColor: context.fomraSurfaceVar,
                color: isTop ? AppColors.accentLight : AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderStat extends StatelessWidget {
  final String label;
  final String value;

  const _LeaderStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 10, color: context.fomraTextSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: context.fomraTextPrimary,
          ),
        ),
      ],
    );
  }
}
