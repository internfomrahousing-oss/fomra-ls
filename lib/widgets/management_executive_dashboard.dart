import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/land_lead.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import '../utils/lead_location_parser.dart';
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

const _kMonthLabels = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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

List<int> _monthlySignedCounts(List<LandLead> leads, int year) {
  final signed = _signedLeads(leads);
  return List.generate(12, (i) {
    final month = i + 1;
    return signed
        .where((l) => l.addedOn.year == year && l.addedOn.month == month)
        .length;
  });
}

List<int> _monthlyAddedCounts(List<LandLead> leads, int year) =>
    List.generate(12, (i) {
      final month = i + 1;
      return leads
          .where((l) => l.addedOn.year == year && l.addedOn.month == month)
          .length;
    });

double _momGrowthPercent(List<int> monthly, int monthIndex) {
  if (monthIndex <= 0 || monthIndex >= monthly.length) return 0;
  final prev = monthly[monthIndex - 1];
  final curr = monthly[monthIndex];
  if (prev == 0) return curr > 0 ? 100 : 0;
  return ((curr - prev) / prev) * 100;
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

class ManagementExecutiveDashboard extends StatelessWidget {
  final List<LandLead> leads;
  final List<PortalTeamPerf> teamRows;
  final List<AppNotification> notifications;
  final ValueChanged<LandLead>? onViewLead;

  const ManagementExecutiveDashboard({
    super.key,
    required this.leads,
    required this.teamRows,
    required this.notifications,
    this.onViewLead,
  });

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) {
      return _DashboardCard(
        child: Column(
          children: [
            EmptyState(
              icon: Icons.analytics_outlined,
              title: 'No pipeline data yet',
              message:
                  'Leads added by your team will populate this executive dashboard automatically.',
            ),
            const PortalEmptyHint(
              hint: 'Add leads or view the leads list to get started.',
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final isDesktop = w >= 1024;
        final isTablet = w >= 640;
        final gap = AppSpacing.md;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DealTermsDonutCard(leads: leads),
            SizedBox(height: gap),
            _HeroKpiStrip(
              leads: leads,
              isDesktop: isDesktop,
              isTablet: isTablet,
            ),
            SizedBox(height: gap),
            _AcquisitionAnalyticsCard(leads: leads),
            SizedBox(height: gap),
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: _DistrictPerformanceCard(leads: leads),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    flex: 5,
                    child: _RecentActivitiesCard(notifications: notifications),
                  ),
                ],
              )
            else ...[
              _DistrictPerformanceCard(leads: leads),
              SizedBox(height: gap),
              _RecentActivitiesCard(notifications: notifications),
            ],
            SizedBox(height: gap),
            _EmployeeLeaderboardCard(
              teamRows: teamRows,
              leads: leads,
            ),
          ],
        );
      },
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
    this.borderColor,
  });

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

// ── Row 2: Hero KPI strip ─────────────────────────────────────────────────────

class _HeroKpiStrip extends StatelessWidget {
  final List<LandLead> leads;
  final bool isDesktop;
  final bool isTablet;

  const _HeroKpiStrip({
    required this.leads,
    required this.isDesktop,
    required this.isTablet,
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

// ── Row 3: Acquisition Analytics ──────────────────────────────────────────────

class _AcquisitionAnalyticsCard extends StatefulWidget {
  final List<LandLead> leads;

  const _AcquisitionAnalyticsCard({required this.leads});

  @override
  State<_AcquisitionAnalyticsCard> createState() =>
      _AcquisitionAnalyticsCardState();
}

class _AcquisitionAnalyticsCardState extends State<_AcquisitionAnalyticsCard> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    final monthlySigned = _monthlySignedCounts(widget.leads, year);
    final monthlyAdded = _monthlyAddedCounts(widget.leads, year);
    final maxSigned = monthlySigned.fold<int>(0, math.max);
    final target = (maxSigned * 1.2).ceil().clamp(1, 9999);
    final currentMonth = DateTime.now().month - 1;
    final mom = _momGrowthPercent(monthlySigned, currentMonth);

    return _DashboardCard(
      title: 'Acquisition Analytics',
      subtitle: 'Monthly signed deals vs target',
      icon: Icons.trending_up_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MomBadge(percent: mom),
              const Spacer(),
              Text(
                'Target: $target / month',
                style: TextStyle(
                  fontSize: 12,
                  color: context.fomraTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(12, (i) {
            final count = monthlySigned[i];
            final isCurrent = i == currentMonth;
            final progress = target == 0 ? 0.0 : (count / target).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      _kMonthLabels[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                        color: isCurrent
                            ? AppColors.primary
                            : context.fomraTextSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: progress),
                        duration: AppMotion.slow,
                        curve: AppMotion.curve,
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          backgroundColor: context.fomraSurfaceVar,
                          color: isCurrent
                              ? AppColors.primary
                              : AppColors.primary.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '$count',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Monthly trend — leads added',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: (monthlyAdded.fold<int>(0, math.max) + 1).toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: context.fomraBorder.withValues(alpha: 0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: context.fomraTextTertiary,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= 12) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _kMonthLabels[i],
                            style: TextStyle(
                              fontSize: 9,
                              color: context.fomraTextTertiary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: context.fomraSurface,
                    getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                      '${_kMonthLabels[group.x]}: ${rod.toY.toInt()}',
                      TextStyle(
                        color: context.fomraTextPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  touchCallback: (event, response) {
                    setState(() {
                      if (response?.spot == null) {
                        _touchedIndex = -1;
                      } else {
                        _touchedIndex = response!.spot!.touchedBarGroupIndex;
                      }
                    });
                  },
                ),
                barGroups: List.generate(12, (i) {
                  final val = monthlyAdded[i].toDouble();
                  final touched = i == _touchedIndex;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        width: touched ? 14 : 10,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.7),
                            AppColors.primary,
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MomBadge extends StatelessWidget {
  final double percent;

  const _MomBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    final isUp = percent > 0;
    final isDown = percent < 0;
    final color = isUp
        ? AppColors.success
        : isDown
            ? AppColors.error
            : context.fomraTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp
                ? Icons.north_east_rounded
                : isDown
                    ? Icons.south_east_rounded
                    : Icons.remove_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            '${percent >= 0 ? '+' : ''}${percent.round()}% MoM',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
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

  const _DealTermsDonutCard({required this.leads});

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
    AppColors.textTertiary,
  ];

  @override
  Widget build(BuildContext context) {
    final dist = _dealTermsDistribution(widget.leads);
    final total = dist.values.fold<int>(0, (a, b) => a + b);
    final sections = <PieChartSectionData>[];

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
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: context.fomraTextPrimary,
          ),
          color: _colors[i % _colors.length],
          radius: touched ? 52 : 46,
          titlePositionPercentageOffset: 0.55,
        ),
      );
    }

    if (sections.isEmpty) {
      sections.add(
        PieChartSectionData(
          value: 1,
          color: context.fomraSurfaceVar,
          radius: 46,
          title: '',
        ),
      );
    }

    return _DashboardCard(
      title: 'Deal Terms Distribution',
      subtitle: 'Parsed from access details',
      icon: Icons.pie_chart_outline_rounded,
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 42,
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
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: List.generate(_kDealCategories.length, (i) {
              final cat = _kDealCategories[i];
              final count = dist[cat] ?? 0;
              final pct = total == 0 ? 0 : ((count / total) * 100).round();
              return _LegendChip(
                color: _colors[i % _colors.length],
                label: cat,
                value: '$pct%',
                selected: i == _touchedIndex,
              );
            }),
          ),
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

  const _LegendChip({
    required this.color,
    required this.label,
    required this.value,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  style: TextStyle(
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
      borderColor: isTop ? AppColors.accentLight.withValues(alpha: 0.6) : null,
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
                    style: TextStyle(
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
