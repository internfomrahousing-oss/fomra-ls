import 'package:flutter/material.dart';

import '../models/land_lead.dart';
import '../services/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_layout.dart';
import '../theme/fomra_theme_context.dart';
import 'ui/app_components.dart';

/// Full date for the home hero — e.g. Monday, 6 July 2026.
String portalHomeDateLabel(DateTime date) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

bool portalIsSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Display name for greeting — management portal uses "Management".
String portalHomeDisplayName({
  required String fullName,
  required bool isManagement,
}) {
  if (isManagement) return 'Management';
  final first = fullName.trim().split(RegExp(r'\s+')).firstWhere(
        (s) => s.isNotEmpty,
        orElse: () => '',
      );
  return first.isEmpty ? 'User' : first;
}

/// Time-of-day greeting per product brief.
String portalTimeGreeting(DateTime now, String displayName) {
  final hour = now.hour;
  final salutation = switch (hour) {
    >= 5 && < 12 => 'Happy Morning',
    >= 12 && < 17 => 'Happy Afternoon',
    _ => 'Happy Evening',
  };
  return '$salutation, $displayName!👋';
}

/// Staggered fade-in for home sections (150–250ms).
class PortalFadeSection extends StatefulWidget {
  final Widget child;
  final int index;

  const PortalFadeSection({
    super.key,
    required this.child,
    this.index = 0,
  });

  @override
  State<PortalFadeSection> createState() => _PortalFadeSectionState();
}

class _PortalFadeSectionState extends State<PortalFadeSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );
  late final Animation<double> _opacity =
      CurvedAnimation(parent: _c, curve: AppMotion.curve);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: AppMotion.curve));

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 40 * widget.index), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class PortalWelcomeHeader extends StatelessWidget {
  final String greeting;
  final String dateLabel;
  final String profileName;
  final String profileRole;
  final int totalLeads;
  final int activeLeads;
  final int brokerLeads;
  final ValueChanged<TapDownDetails>? onProfileTapDown;

  const PortalWelcomeHeader({
    super.key,
    required this.greeting,
    required this.dateLabel,
    required this.profileName,
    required this.profileRole,
    required this.totalLeads,
    required this.activeLeads,
    required this.brokerLeads,
    this.onProfileTapDown,
  });

  @override
  Widget build(BuildContext context) {
    final initial = profileName.trim().isNotEmpty
        ? profileName.trim()[0].toUpperCase()
        : '?';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppColors.radiusLg,
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: AppMotion.slow,
                      switchInCurve: AppMotion.curve,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: Text(
                        greeting,
                        key: ValueKey(greeting),
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: context.fomraTextPrimary,
                                  height: 1.2,
                                ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _PortalProfileChip(
                initial: initial,
                name: profileName,
                role: profileRole,
                onTapDown: onProfileTapDown,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 640;
              final tiles = [
                PortalSummaryTile(
                  label: 'Total leads',
                  value: totalLeads,
                  icon: Icons.location_on_outlined,
                  accent: AppColors.primary,
                ),
                PortalSummaryTile(
                  label: 'Active leads',
                  value: activeLeads,
                  icon: Icons.trending_up_rounded,
                  accent: AppColors.success,
                ),
                PortalSummaryTile(
                  label: 'Broker leads',
                  value: brokerLeads,
                  icon: Icons.handshake_outlined,
                  accent: AppColors.warning,
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      tiles[i],
                      if (i < tiles.length - 1)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    Expanded(child: tiles[i]),
                    if (i < tiles.length - 1)
                      const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PortalProfileChip extends StatelessWidget {
  final String initial;
  final String name;
  final String role;
  final ValueChanged<TapDownDetails>? onTapDown;

  const _PortalProfileChip({
    required this.initial,
    required this.name,
    required this.role,
    this.onTapDown,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppColors.coloredShadow(AppColors.primary),
              ),
              alignment: Alignment.center,
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.fomraSurface,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.fomraTextPrimary,
              ),
            ),
            Text(
              role,
              style: TextStyle(
                fontSize: 11,
                color: context.fomraTextSecondary,
              ),
            ),
          ],
        ),
      ],
    );

    if (onTapDown == null) return chip;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTapDown: onTapDown, child: chip),
    );
  }
}

class PortalSummaryTile extends StatefulWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color accent;

  const PortalSummaryTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  State<PortalSummaryTile> createState() => _PortalSummaryTileState();
}

class _PortalSummaryTileState extends State<PortalSummaryTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        transform: _hovered
            ? Matrix4.translationValues(0, -2, 0)
            : Matrix4.identity(),
        decoration: BoxDecoration(
          color: widget.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          border: Border.all(
            color: widget.accent.withValues(alpha: _hovered ? 0.28 : 0.14),
          ),
          boxShadow: _hovered ? context.fomraCardShadow : null,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.fomraSurface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                widget.icon,
                color: widget.accent,
                size: AppIconSize.small,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedCounter(
                    value: widget.value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: context.fomraTextPrimary,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.fomraTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PortalQuickAction {
  final String label;
  final String? subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const PortalQuickAction({
    required this.label,
    this.subtitle,
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
    if (width < 640) {
      return SizedBox(
        height: 132,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: actions.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (_, i) => SizedBox(
            width: 156,
            child: _QuickActionCard(data: actions[i]),
          ),
        ),
      );
    }

    final columns = width >= 1200 ? 5 : width >= 900 ? 3 : 2;
    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        mainAxisExtent: 124,
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
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppColors.radiusMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              data.icon,
              color: data.accent,
              size: AppIconSize.secondary,
            ),
          ),
          const Spacer(),
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: context.fomraTextPrimary,
            ),
          ),
          if ((data.subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              data.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: context.fomraTextSecondary,
              ),
            ),
          ],
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

class PortalPerformanceRow extends StatefulWidget {
  final PortalTeamPerf data;

  const PortalPerformanceRow({super.key, required this.data});

  @override
  State<PortalPerformanceRow> createState() => _PortalPerformanceRowState();
}

class _PortalPerformanceRowState extends State<PortalPerformanceRow> {
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
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
      padding: const EdgeInsets.all(AppSpacing.md),
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
          const SizedBox(width: AppSpacing.sm),
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
                const SizedBox(height: AppSpacing.sm),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: data.percent),
                  duration: AppMotion.slow,
                  curve: AppMotion.curve,
                  builder: (_, value, __) => Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: value,
                            minHeight: 10,
                            backgroundColor: accent.withValues(alpha: 0.12),
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '${(value * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.fomraTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
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
  final String? subtitle;
  final IconData icon;
  final Widget child;

  const PortalSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppColors.radiusLg,
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
          ),
          child,
        ],
      ),
    );
  }
}

/// Wider home content — ~94% of viewport on desktop.
Widget portalHomeWidthConstraint(BuildContext context, Widget child) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final isWide = FomraLayout.isDesktop(context);
      final maxW = isWide ? constraints.maxWidth * 0.94 : constraints.maxWidth;
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: child,
        ),
      );
    },
  );
}

class PortalEmptyHint extends StatelessWidget {
  final String hint;

  const PortalEmptyHint({super.key, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Text(
        hint,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: context.fomraTextTertiary,
        ),
      ),
    );
  }
}
