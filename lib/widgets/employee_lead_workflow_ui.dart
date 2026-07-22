import 'package:flutter/material.dart';

import '../models/land_lead.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import '../utils/employee_lead_next_action.dart';

IconData _actionIcon(EmployeeNextActionKind kind) => switch (kind) {
      EmployeeNextActionKind.callOwner => Icons.phone_in_talk_outlined,
      EmployeeNextActionKind.landOwnerMeeting => Icons.handshake_outlined,
      EmployeeNextActionKind.siteVisit => Icons.place_outlined,
      EmployeeNextActionKind.legalVerification => Icons.balance_outlined,
      EmployeeNextActionKind.managementSiteVisit => Icons.apartment_outlined,
      EmployeeNextActionKind.projectSigning => Icons.task_alt_rounded,
      EmployeeNextActionKind.none => Icons.check_circle_outline,
    };

/// Next-action + pending-task banners for employee lead detail.
class EmployeeLeadGuidanceBanners extends StatelessWidget {
  final EmployeeLeadWorkflowInsight insight;
  final VoidCallback? onOpenTasks;
  final VoidCallback? onNextActionTap;

  const EmployeeLeadGuidanceBanners({
    super.key,
    required this.insight,
    this.onOpenTasks,
    this.onNextActionTap,
  });

  @override
  Widget build(BuildContext context) {
    // Priority is derived from the lead's own pending tasks — reusing existing
    // data, not a new field: overdue → High, due today → Medium, else Normal.
    final tasks = insight.tasks;
    final ({String label, Color color})? priority = !insight.nextAction.isPending
        ? null
        : tasks.overdue > 0
            ? (label: 'High', color: AppColors.error)
            : tasks.dueToday > 0
                ? (label: 'Medium', color: AppColors.warning)
                : (label: 'Normal', color: AppColors.info);

    return LayoutBuilder(
      builder: (context, c) {
        // Wide enough: Next Action on the left, the three KPIs stacked in a
        // single column to its right. Narrow: stack, KPIs as a 3-across row.
        final sideBySide = c.maxWidth >= 520;
        final nextAction = _NextActionBanner(
          action: insight.nextAction,
          stage: insight.stage,
          priority: priority,
          onTap: onNextActionTap,
        );
        final kpis = _PendingTaskBanner(
          summary: insight.tasks,
          onTap: onOpenTasks,
          vertical: sideBySide,
        );

        if (sideBySide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: nextAction),
              const SizedBox(width: 10),
              SizedBox(width: 190, child: kpis),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            nextAction,
            const SizedBox(height: 8),
            kpis,
          ],
        );
      },
    );
  }
}

/// The one activity the executive has to do next, its stage and a derived
/// priority — kept to a compact height (title, short description, stage,
/// priority) so it sits neatly beside / above the lead summary.
class _NextActionBanner extends StatelessWidget {
  final EmployeeNextAction action;
  final LeadStatus stage;
  final ({String label, Color color})? priority;
  final VoidCallback? onTap;

  const _NextActionBanner({
    required this.action,
    required this.stage,
    this.priority,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = action.isPending ? stage.color : AppColors.success;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Nothing to open once the pipeline is done.
        onTap: action.isPending ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 15, color: accent),
                  const SizedBox(width: 5),
                  Text(
                    'NEXT ACTION',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: accent,
                    ),
                  ),
                  const Spacer(),
                  if (priority != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: priority!.color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.flag_rounded,
                              size: 11, color: priority!.color),
                          const SizedBox(width: 4),
                          Text(
                            priority!.label,
                            style: TextStyle(
                              color: priority!.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_actionIcon(action.kind), size: 17, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          action.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Current Stage:',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: context.fomraTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: stage.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        stage.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: stage.color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingTaskBanner extends StatelessWidget {
  final EmployeePendingTaskSummary summary;
  final VoidCallback? onTap;

  /// When true, the three KPIs stack in a single column (used beside the Next
  /// Action on wide layouts); otherwise they sit in a 3-across row.
  final bool vertical;

  const _PendingTaskBanner({
    required this.summary,
    this.onTap,
    this.vertical = false,
  });

  @override
  Widget build(BuildContext context) {
    // Three compact KPI cards (point 5), each self-contained with its accent.
    final dueToday = _TaskStat(
      label: 'Due Today',
      value: '${summary.dueToday}',
      color: AppColors.warning,
    );
    final overdue = _TaskStat(
      label: 'Overdue',
      value: '${summary.overdue}',
      color: AppColors.error,
    );
    final pending = _TaskStat(
      label: 'Pending Since',
      value: summary.pendingSinceDays <= 0
          ? '—'
          : '${summary.pendingSinceDays}d',
      color: AppColors.info,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: vertical
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  dueToday,
                  const SizedBox(height: 8),
                  overdue,
                  const SizedBox(height: 8),
                  pending,
                ],
              )
            : Row(
                children: [
                  Expanded(child: dueToday),
                  const SizedBox(width: 8),
                  Expanded(child: overdue),
                  const SizedBox(width: 8),
                  Expanded(child: pending),
                ],
              ),
      ),
    );
  }
}

class _TaskStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _TaskStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 18,
                height: 1,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.fomraTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Expandable floating quick-action menu for employee lead detail.
class EmployeeLeadQuickFab extends StatefulWidget {
  final LandLead lead;
  final Future<void> Function(String scheme) onLaunchContact;
  final ValueChanged<String> onDetailAction;
  final ValueChanged<LandLead>? onLeadUpdated;
  final VoidCallback? onActivityChanged;

  const EmployeeLeadQuickFab({
    super.key,
    required this.lead,
    required this.onLaunchContact,
    required this.onDetailAction,
    this.onLeadUpdated,
    this.onActivityChanged,
  });

  @override
  State<EmployeeLeadQuickFab> createState() => _EmployeeLeadQuickFabState();
}

class _EmployeeLeadQuickFabState extends State<EmployeeLeadQuickFab>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  bool _busy = false;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _open = false;
    });
    _c.reverse();
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final actions = <({IconData icon, String label, Color color, VoidCallback onTap})>[
      (
        icon: Icons.call_outlined,
        label: 'Call',
        color: AppColors.success,
        onTap: () => _run(() => widget.onLaunchContact('tel')),
      ),
      (
        icon: Icons.location_on_outlined,
        label: 'Visit',
        color: AppColors.primary,
        onTap: () => _run(() async {
          widget.onDetailAction('Site visit');
        }),
      ),
      (
        icon: Icons.chat_rounded,
        label: 'WhatsApp',
        color: const Color(0xFF25D366),
        onTap: () => _run(() => widget.onLaunchContact('https://wa.me')),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open)
          ...[
            for (var i = 0; i < actions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: FadeTransition(
                  opacity: _c,
                  child: ScaleTransition(
                    scale: _c,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: context.fomraSurface,
                          elevation: 2,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Text(
                              actions[i].label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                          heroTag: 'lead_fab_${actions[i].label}',
                          backgroundColor: actions[i].color,
                          onPressed: actions[i].onTap,
                          child: Icon(actions[i].icon, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        FloatingActionButton(
          heroTag: 'lead_fab_main',
          onPressed: _busy ? null : _toggle,
          backgroundColor: AppColors.primary,
          child: _busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(_open ? Icons.close_rounded : Icons.bolt_rounded),
        ),
      ],
    );
  }
}
