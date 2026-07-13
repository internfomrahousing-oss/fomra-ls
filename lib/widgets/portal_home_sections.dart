import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/land_lead.dart';
import '../models/land_lead_site_visit.dart';
import '../models/lead_list_filter.dart';
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
  final ValueChanged<LeadListFilter>? onSummaryTap;

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
    this.onSummaryTap,
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
                  label: 'Total sites',
                  value: totalLeads,
                  icon: Icons.location_on_outlined,
                  accent: AppColors.primary,
                  onTap: onSummaryTap == null
                      ? null
                      : () => onSummaryTap!(LeadListFilter.totalLeads),
                ),
                PortalSummaryTile(
                  label: 'Active sites',
                  value: activeLeads,
                  icon: Icons.trending_up_rounded,
                  accent: AppColors.success,
                  onTap: onSummaryTap == null
                      ? null
                      : () => onSummaryTap!(LeadListFilter.activeLeads),
                ),
                PortalSummaryTile(
                  label: 'Broker sites',
                  value: brokerLeads,
                  icon: Icons.handshake_outlined,
                  accent: AppColors.warning,
                  onTap: onSummaryTap == null
                      ? null
                      : () => onSummaryTap!(LeadListFilter.brokerLeads),
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
  final VoidCallback? onTap;

  const PortalSummaryTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  @override
  State<PortalSummaryTile> createState() => _PortalSummaryTileState();
}

class _PortalSummaryTileState extends State<PortalSummaryTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
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

    if (widget.onTap == null) return tile;
    return GestureDetector(onTap: widget.onTap, child: tile);
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

  static const _cardWidth = 272.0;
  static const _cardHeight = 92.0;
  static const _gridGap = 16.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 640) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: _gridGap),
            itemBuilder: (_, i) => SizedBox(
              width: _cardWidth,
              height: _cardHeight,
              child: _QuickActionCard(data: actions[i]),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Fit as many cards per row as the min card width allows, then widen
          // each computed card so the row fills the full width (no trailing gap).
          // Uses a Wrap with explicit widths — never Expanded — so an unbounded
          // width constraint can't crash the layout (which blanked the page).
          final maxW = constraints.maxWidth;
          if (!maxW.isFinite || maxW <= 0) {
            return Wrap(
              spacing: _gridGap,
              runSpacing: _gridGap,
              children: [
                for (final action in actions)
                  SizedBox(
                    width: _cardWidth,
                    height: _cardHeight,
                    child: _QuickActionCard(data: action),
                  ),
              ],
            );
          }
          var perRow = ((maxW + _gridGap) / (_cardWidth + _gridGap)).floor();
          if (perRow < 1) perRow = 1;
          if (perRow > actions.length) perRow = actions.length;
          final cardW = (maxW - _gridGap * (perRow - 1)) / perRow;

          return Wrap(
            spacing: _gridGap,
            runSpacing: _gridGap,
            children: [
              for (final action in actions)
                SizedBox(
                  width: cardW,
                  height: _cardHeight,
                  child: _QuickActionCard(data: action),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final PortalQuickAction data;

  const _QuickActionCard({required this.data});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _hovered = false;

  static const _motion = Duration(milliseconds: 190);
  static const _curve = Curves.easeInOut;

  PortalQuickAction get data => widget.data;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final cardColor = isDark
        ? context.fomraSurface.withValues(alpha: 0.88)
        : context.fomraSurface;
    final borderColor = _hovered && isDark
        ? AppColors.primary.withValues(alpha: 0.55)
        : context.fomraBorder;
    final iconTint = data.accent.withValues(alpha: _hovered ? 0.18 : 0.12);
    final shadowAlpha = isDark
        ? (_hovered ? 0.42 : 0.28)
        : (_hovered ? 0.12 : 0.08);
    final shadowBlur = _hovered ? 28.0 : 20.0;
    final shadowOffset = _hovered ? 10.0 : 6.0;

    final card = AnimatedContainer(
      duration: _motion,
      curve: _curve,
      transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
          width: _hovered && isDark ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (_hovered && isDark
                    ? AppColors.primary
                    : const Color(0xFF0F172A))
                .withValues(alpha: shadowAlpha),
            blurRadius: shadowBlur,
            offset: Offset(0, shadowOffset),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          AnimatedScale(
            scale: _hovered ? 1.05 : 1,
            duration: _motion,
            curve: _curve,
            child: AnimatedContainer(
              duration: _motion,
              curve: _curve,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconTint,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Icon(
                data.icon,
                size: 21,
                color: data.accent,
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Text(
              data.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                height: 1.2,
                color: context.fomraTextPrimary,
              ),
            ),
          ),
          AnimatedOpacity(
            opacity: _hovered ? 1 : 0,
            duration: _motion,
            curve: _curve,
            child: AnimatedSlide(
              duration: _motion,
              curve: _curve,
              offset: _hovered ? Offset.zero : const Offset(-0.2, 0),
              child: Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: _hovered && isDark
                    ? AppColors.primary
                    : context.fomraTextSecondary.withValues(
                        alpha: _hovered ? 0.9 : 0,
                      ),
              ),
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: data.onTap,
        behavior: HitTestBehavior.opaque,
        child: isDark
            ? ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: card,
                ),
              )
            : card,
      ),
    );
  }
}

String _portalFormatVisitDateTime(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final ampm = d.hour >= 12 ? 'PM' : 'AM';
  return '${months[d.month - 1]} ${d.day}, ${d.year} · $hour:$minute $ampm';
}

class PortalApprovalsSection extends StatelessWidget {
  final List<LandLeadSiteVisit> visits;
  final List<LandLead> leads;
  final bool loading;
  final Future<void> Function(LandLeadSiteVisit visit) onReview;
  final Future<void> Function(LandLeadSiteVisit visit) onApprove;
  final Future<void> Function(LandLeadSiteVisit visit) onReject;

  const PortalApprovalsSection({
    super.key,
    required this.visits,
    required this.leads,
    required this.loading,
    required this.onReview,
    required this.onApprove,
    required this.onReject,
  });

  LandLead? _leadFor(String leadId) {
    for (final l in leads) {
      if (l.leadId == leadId) return l;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      radius: AppColors.radiusLg,
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Approvals',
            subtitle: 'Pending management site visit requests',
            icon: Icons.verified_outlined,
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (visits.isEmpty)
            const PortalEmptyHint(
              hint: 'No pending approvals — new requests will appear here.',
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Scrollbar(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (var i = 0; i < visits.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        _ApprovalVisitRow(
                          visit: visits[i],
                          lead: _leadFor(visits[i].leadId),
                          onReview: () => onReview(visits[i]),
                          onApprove: () => onApprove(visits[i]),
                          onReject: () => onReject(visits[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ApprovalVisitRow extends StatefulWidget {
  final LandLeadSiteVisit visit;
  final LandLead? lead;
  final Future<void> Function() onReview;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  const _ApprovalVisitRow({
    required this.visit,
    required this.lead,
    required this.onReview,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<_ApprovalVisitRow> createState() => _ApprovalVisitRowState();
}

class _ApprovalVisitRowState extends State<_ApprovalVisitRow> {
  bool _busy = false;

  Future<void> _act(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visit = widget.visit;
    final lead = widget.lead;
    final ownerLabel = lead != null && lead.ownerName.trim().isNotEmpty
        ? lead.ownerName.trim()
        : null;
    final subtitleParts = <String>[
      'Lead #${visit.leadId}',
      if (ownerLabel != null) ownerLabel,
      if (visit.loggedByName.isNotEmpty) 'Requested by ${visit.loggedByName}',
      _portalFormatVisitDateTime(visit.visitedAt.toLocal()),
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : () => _act(widget.onReview),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: context.fomraSurfaceVar.withValues(
              alpha: context.isDarkMode ? 0.55 : 0.65,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.fomraBorder),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 520;
              final info = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.apartment_outlined,
                      color: AppColors.warning,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Management site visit',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleParts.join(' · '),
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.2,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final actions = _busy
                  ? const Padding(
                      padding: EdgeInsets.all(6),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OutlinedButton(
                          onPressed: () => _act(widget.onReject),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(
                              color: AppColors.error.withValues(alpha: 0.45),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: () => _act(widget.onApprove),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('Approve'),
                        ),
                      ],
                    );

              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    info,
                    const SizedBox(height: 8),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            },
          ),
        ),
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

int _leadStatusPerformanceWeight(LeadStatus status) {
  return switch (status) {
    LeadStatus.signed => 100,
    LeadStatus.legal => 80,
    LeadStatus.negotiation => 65,
    LeadStatus.prospectMeetingCompleted => 45,
    LeadStatus.prospectMeetingPending => 25,
    LeadStatus.dropped => 0,
  };
}

double _conversionScore(List<LandLead> leads) {
  if (leads.isEmpty) return 0;
  final signed = leads.where((l) => l.status == LeadStatus.signed).length;
  return signed / leads.length;
}

double _statusScore(List<LandLead> leads) {
  if (leads.isEmpty) return 0;
  final sum = leads.fold<double>(
    0,
    (acc, lead) => acc + _leadStatusPerformanceWeight(lead.status),
  );
  return (sum / leads.length) / 100;
}

double _compositePerformanceScore({
  required List<LandLead> leads,
  required int maxCount,
}) {
  final conversionScore = _conversionScore(leads);
  final statusScore = _statusScore(leads);
  final volumeScore = maxCount == 0 ? 0.0 : leads.length / maxCount;
  return (0.40 * conversionScore +
          0.35 * statusScore +
          0.25 * volumeScore)
      .clamp(0.0, 1.0);
}

(String, StatusTone) _performanceStatusFromScore(double score) {
  return switch (score) {
    >= 0.80 => ('Top performer', StatusTone.success),
    >= 0.55 => ('On track', StatusTone.primary),
    >= 0.30 => ('Needs boost', StatusTone.warning),
    _ => ('Low activity', StatusTone.danger),
  };
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
    final composite = _compositePerformanceScore(
      leads: personLeads,
      maxCount: maxCount,
    );
    final status = _performanceStatusFromScore(composite);
    return PortalTeamPerf(
      name: entry.key,
      designation: employeeMap[entry.key] ?? '',
      total: total,
      today: today,
      percent: composite,
      rank: 0,
      statusLabel: status.$1,
      tone: status.$2,
    );
  }).toList()
    ..sort((a, b) => b.percent.compareTo(a.percent));

  for (var i = 0; i < rows.length; i++) {
    rows[i] = rows[i].copyWith(rank: i + 1);
  }
  return rows;
}

class PortalPerformanceRow extends StatefulWidget {
  final PortalTeamPerf data;
  final List<LandLead> leads;
  final ValueChanged<LandLead>? onViewLead;

  const PortalPerformanceRow({
    super.key,
    required this.data,
    this.leads = const [],
    this.onViewLead,
  });

  @override
  State<PortalPerformanceRow> createState() => _PortalPerformanceRowState();
}

class _PortalPerformanceRowState extends State<PortalPerformanceRow> {
  static const _expandMs = Duration(milliseconds: 280);
  bool _expanded = false;
  bool _hovered = false;

  String _priorityLabel(LandLead lead) {
    return switch (lead.status) {
      LeadStatus.signed => 'Low',
      LeadStatus.dropped => 'Low',
      LeadStatus.prospectMeetingCompleted => 'Medium',
      LeadStatus.legal => 'Medium',
      _ => 'High',
    };
  }

  StatusTone _priorityTone(LandLead lead) {
    return switch (lead.status) {
      LeadStatus.signed => StatusTone.success,
      LeadStatus.dropped => StatusTone.neutral,
      LeadStatus.prospectMeetingCompleted => StatusTone.warning,
      LeadStatus.legal => StatusTone.warning,
      _ => StatusTone.danger,
    };
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

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

    final leads = widget.leads;
    final activeLeads = leads.where((l) => l.status.isActive).length;
    final closedLeads = leads.where((l) => l.status.isAcquired).length;
    final conversionRate = leads.isEmpty ? 0 : ((closedLeads / leads.length) * 100).round();

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: _expandMs,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: context.fomraSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _expanded
                ? AppColors.primary.withValues(alpha: 0.26)
                : context.fomraBorder.withValues(alpha: _hovered ? 0.9 : 0.75),
          ),
          boxShadow: _hovered || _expanded ? context.fomraCardShadow : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Row(
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
                                        backgroundColor:
                                            accent.withValues(alpha: 0.12),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(accent),
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
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: _expandMs,
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 24,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: _expandMs,
                    curve: Curves.easeOutCubic,
                    child: !_expanded
                        ? const SizedBox.shrink()
                        : Column(
                            children: [
                              const SizedBox(height: 14),
                              const Divider(height: 1),
                              const SizedBox(height: 14),
                              _PerformanceSummaryRow(
                                totalLeads: leads.length,
                                activeLeads: activeLeads,
                                closedDeals: closedLeads,
                                conversionRate: conversionRate,
                              ),
                              const SizedBox(height: 12),
                              if (leads.isEmpty)
                                _PerformanceEmptyState(name: data.name)
                              else
                                _PerformanceLeadList(
                                  leads: leads,
                                  fmtDate: _fmtDate,
                                  priorityLabel: _priorityLabel,
                                  priorityTone: _priorityTone,
                                  onViewLead: widget.onViewLead,
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PerformanceSummaryRow extends StatelessWidget {
  final int totalLeads;
  final int activeLeads;
  final int closedDeals;
  final int conversionRate;

  const _PerformanceSummaryRow({
    required this.totalLeads,
    required this.activeLeads,
    required this.closedDeals,
    required this.conversionRate,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _TinyStat(label: 'Total Sites', value: '$totalLeads'),
        _TinyStat(label: 'Active Sites', value: '$activeLeads'),
        _TinyStat(label: 'Closed Deals', value: '$closedDeals'),
        _TinyStat(label: 'Conversion Rate', value: '$conversionRate%'),
      ],
    );
  }
}

StatusTone _statusTone(LeadStatus status) {
  return switch (status) {
    LeadStatus.prospectMeetingPending => StatusTone.primary,
    LeadStatus.prospectMeetingCompleted => StatusTone.warning,
    LeadStatus.negotiation => StatusTone.danger,
    LeadStatus.legal => StatusTone.warning,
    LeadStatus.signed => StatusTone.success,
    LeadStatus.dropped => StatusTone.neutral,
  };
}

class _PerformanceLeadList extends StatelessWidget {
  final List<LandLead> leads;
  final String Function(DateTime) fmtDate;
  final String Function(LandLead) priorityLabel;
  final StatusTone Function(LandLead) priorityTone;
  final ValueChanged<LandLead>? onViewLead;

  const _PerformanceLeadList({
    required this.leads,
    required this.fmtDate,
    required this.priorityLabel,
    required this.priorityTone,
    required this.onViewLead,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LeadHeaderRow(),
        const SizedBox(height: 8),
        for (final lead in leads) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.fomraSurfaceVar.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.fomraBorder.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 19,
                  child: Text(
                    lead.ownerName.trim().isEmpty ? 'Lead #${lead.leadId}' : lead.ownerName.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 22,
                  child: Text(
                    '${lead.landType.label} • ${lead.village.isNotEmpty ? lead.village : lead.location}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.fomraTextSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 12,
                  child: StatusChip(label: lead.status.label, tone: _statusTone(lead.status)),
                ),
                Expanded(
                  flex: 10,
                  child: StatusChip(label: priorityLabel(lead), tone: priorityTone(lead)),
                ),
                Expanded(
                  flex: 12,
                  child: Text(
                    fmtDate(lead.addedOn.toLocal()),
                    style: TextStyle(fontSize: 11, color: context.fomraTextSecondary),
                  ),
                ),
                Expanded(
                  flex: 12,
                  child: Text(
                    fmtDate(lead.addedOn.toLocal()),
                    style: TextStyle(fontSize: 11, color: context.fomraTextSecondary),
                  ),
                ),
                Expanded(
                  flex: 8,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onViewLead == null ? null : () => onViewLead!(lead),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('View'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (lead != leads.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _LeadHeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    TextStyle style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: context.fomraTextSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(flex: 19, child: Text('Lead Name', style: style)),
          Expanded(flex: 22, child: Text('Property / Location', style: style)),
          Expanded(flex: 12, child: Text('Current Stage', style: style)),
          Expanded(flex: 10, child: Text('Priority', style: style)),
          Expanded(flex: 12, child: Text('Last Activity', style: style)),
          Expanded(flex: 12, child: Text('Assigned Date', style: style)),
          Expanded(flex: 8, child: Text('Action', style: style)),
        ],
      ),
    );
  }
}

class _PerformanceEmptyState extends StatelessWidget {
  final String name;
  const _PerformanceEmptyState({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.fomraBorder.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, color: context.fomraTextSecondary),
          const SizedBox(height: 8),
          Text(
            'No leads assigned to $name',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Leads assigned to this employee will appear here.',
            style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
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

/// Premium profile dropdown anchored to a tap on the home header chip.
Future<String?> showPortalProfileMenu({
  required BuildContext context,
  required Offset anchor,
  required String name,
  required String role,
  required String initial,
}) {
  final media = MediaQuery.of(context);
  const menuWidth = 252.0;
  var left = anchor.dx - menuWidth + 48;
  left = left.clamp(12.0, media.size.width - menuWidth - 12.0);
  final top = (anchor.dy + 10).clamp(
    media.padding.top + 8,
    media.size.height - 280,
  );

  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss profile menu',
    barrierColor: Colors.black.withValues(alpha: 0.08),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: _PortalProfileMenuPanel(
              name: name,
              role: role,
              initial: initial,
              onSelect: (value) => Navigator.of(context).pop(value),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          alignment: Alignment.topCenter,
          child: child,
        ),
      );
    },
  );
}

class _PortalProfileMenuPanel extends StatelessWidget {
  final String name;
  final String role;
  final String initial;
  final ValueChanged<String> onSelect;

  const _PortalProfileMenuPanel({
    required this.name,
    required this.role,
    required this.initial,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: context.fomraSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.fomraBorder),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F0F172A),
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.fomraTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            role,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.fomraTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.fomraBorder),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: _PortalProfileMenuItem(
                  icon: Icons.lock_outline_rounded,
                  label: 'Change Password',
                  subtitle: 'Update your password',
                  onTap: () => onSelect('change_password'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Divider(height: 1, color: context.fomraBorder),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: _PortalProfileMenuItem(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  destructive: true,
                  onTap: () => onSelect('sign_out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalProfileMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool destructive;
  final VoidCallback onTap;

  const _PortalProfileMenuItem({
    required this.icon,
    required this.label,
    this.subtitle,
    this.destructive = false,
    required this.onTap,
  });

  @override
  State<_PortalProfileMenuItem> createState() => _PortalProfileMenuItemState();
}

class _PortalProfileMenuItemState extends State<_PortalProfileMenuItem> {
  bool _hovered = false;

  static const _destructive = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.destructive ? _destructive : context.fomraTextPrimary;
    final iconColor = widget.destructive ? _destructive : AppColors.primary;
    final hoverBg = context.fomraHoverBg;
    final iconBg = context.fomraIconChipBg;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: widget.subtitle == null ? 50 : 52,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _hovered ? hoverBg : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  scale: _hovered ? 1.06 : 1,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: widget.destructive
                          ? _destructive.withValues(alpha: 0.08)
                          : iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.fomraTextSecondary,
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
