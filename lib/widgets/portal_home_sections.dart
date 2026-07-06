import 'package:flutter/material.dart';

import '../models/land_lead.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'ui/app_components.dart';

String portalDateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
}

bool portalIsSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class PortalWelcomeHeader extends StatelessWidget {
  final String userName;
  final String dateLabel;
  final int todayTasks;
  final int activeLeads;
  final int pendingActions;
  final VoidCallback? onProfileTap;

  const PortalWelcomeHeader({
    super.key,
    required this.userName,
    required this.dateLabel,
    required this.todayTasks,
    required this.activeLeads,
    required this.pendingActions,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final firstName = userName.trim().split(RegExp(r'\s+')).firstWhere(
          (s) => s.isNotEmpty,
          orElse: () => '',
        );
    final greeting =
        firstName.isEmpty ? 'Welcome back' : 'Welcome back, $firstName';
    final initial =
        firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return AppCard(
      padding: const EdgeInsets.all(24),
      radius: AppColors.radiusLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: context.fomraTextPrimary,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dateLabel · Your land acquisition command center.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onProfileTap != null)
                GestureDetector(
                  onTap: onProfileTap,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.coloredShadow(AppColors.primary),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppColors.coloredShadow(AppColors.primary),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.home_work_outlined,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              PortalSummaryBadge(
                label: 'Today’s tasks',
                value: '$todayTasks',
                icon: Icons.today_outlined,
                accent: AppColors.primary,
              ),
              PortalSummaryBadge(
                label: 'Active leads',
                value: '$activeLeads',
                icon: Icons.trending_up_rounded,
                accent: AppColors.success,
              ),
              PortalSummaryBadge(
                label: 'Pending actions',
                value: '$pendingActions',
                icon: Icons.pending_actions_outlined,
                accent: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PortalSummaryBadge extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const PortalSummaryBadge({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.fomraTextPrimary,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: context.fomraTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PortalQuickAction {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const PortalQuickAction({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
}

class PortalQuickActionsGrid extends StatelessWidget {
  final List<PortalQuickAction> actions;

  const PortalQuickActionsGrid({super.key, required this.actions});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100 ? 5 : width >= 860 ? 3 : 2;
    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: width >= 860 ? 1.65 : 1.35,
      ),
      itemBuilder: (_, i) => _QuickActionCard(data: actions[i]),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final PortalQuickAction data;

  const _QuickActionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: data.onTap,
      padding: const EdgeInsets.all(20),
      radius: AppColors.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(data.icon, color: data.accent, size: 22),
          ),
          const Spacer(),
          Text(
            data.label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.subtitle,
            style: TextStyle(
              fontSize: 12,
              color: context.fomraTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class PortalTeamPerf {
  final String name;
  final String designation;
  final int total;
  final int today;
  final double percent;
  final int rank;
  final String statusLabel;
  final StatusTone tone;

  const PortalTeamPerf({
    required this.name,
    required this.designation,
    required this.total,
    required this.today,
    required this.percent,
    required this.rank,
    required this.statusLabel,
    required this.tone,
  });

  PortalTeamPerf copyWith({int? rank}) => PortalTeamPerf(
        name: name,
        designation: designation,
        total: total,
        today: today,
        percent: percent,
        rank: rank ?? this.rank,
        statusLabel: statusLabel,
        tone: tone,
      );
}

List<PortalTeamPerf> buildPortalTeamPerformance(List<LandLead> leads) {
  final employeeMap = <String, String>{};
  for (final employee in AppStore.instance.employees) {
    if (employee.fullName.trim().isEmpty) continue;
    employeeMap[employee.fullName.trim()] = employee.designation.trim();
  }

  final now = DateTime.now();
  final byUser = <String, List<LandLead>>{};
  for (final lead in leads) {
    final name = lead.createdByName.trim();
    if (name.isEmpty || name.toLowerCase() == 'management') continue;
    byUser.putIfAbsent(name, () => []).add(lead);
  }

  final maxCount = byUser.values.isEmpty
      ? 1
      : byUser.values.map((e) => e.length).reduce((a, b) => a > b ? a : b);

  final rows = byUser.entries.map((entry) {
    final personLeads = entry.value;
    final total = personLeads.length;
    final today =
        personLeads.where((l) => portalIsSameDay(l.addedOn, now)).length;
    final pct = (total / maxCount).clamp(0.0, 1.0);
    final status = switch (pct) {
      >= 0.8 => ('Top performer', StatusTone.success),
      >= 0.55 => ('On track', StatusTone.primary),
      >= 0.3 => ('Needs boost', StatusTone.warning),
      _ => ('Low activity', StatusTone.danger),
    };
    return PortalTeamPerf(
      name: entry.key,
      designation: employeeMap[entry.key] ?? '',
      total: total,
      today: today,
      percent: pct,
      rank: 0,
      statusLabel: status.$1,
      tone: status.$2,
    );
  }).toList()
    ..sort((a, b) => b.total.compareTo(a.total));

  for (var i = 0; i < rows.length; i++) {
    rows[i] = rows[i].copyWith(rank: i + 1);
  }
  return rows;
}

class PortalPerformanceRow extends StatelessWidget {
  final PortalTeamPerf data;

  const PortalPerformanceRow({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final accent = data.rank == 1
        ? AppColors.warning
        : data.rank == 2
            ? AppColors.primary
            : AppColors.purple;
    final initials = data.name.trim().isEmpty
        ? '?'
        : data.name
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((e) => e[0])
            .join();

    return AppCard(
      padding: const EdgeInsets.all(18),
      radius: AppColors.radiusMd,
      interactive: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              initials.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w800, color: accent),
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
                        data.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: context.fomraTextPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '#${data.rank}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                if (data.designation.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    data.designation,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.fomraTextSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: data.percent,
                          minHeight: 10,
                          backgroundColor: accent.withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation<Color>(accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${(data.percent * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(label: data.statusLabel, tone: data.tone),
                    _TinyStat(label: 'Lead count', value: '${data.total}'),
                    _TinyStat(label: 'Today', value: '${data.today}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyStat extends StatelessWidget {
  final String label;
  final String value;

  const _TinyStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: context.fomraTextSecondary,
        ),
      ),
    );
  }
}

class PortalSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const PortalSectionCard({
    super.key,
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

class PortalFunnelRow extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final Color color;

  const PortalFunnelRow({
    super.key,
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
