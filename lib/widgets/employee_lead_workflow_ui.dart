import 'package:flutter/material.dart';

import '../models/land_lead.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_layout.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _NextActionBanner(
          action: insight.nextAction,
          stage: insight.stage,
          onTap: onNextActionTap,
        ),
        const SizedBox(height: 8),
        _PendingTaskBanner(
          summary: insight.tasks,
          onTap: onOpenTasks,
        ),
      ],
    );
  }
}

/// The one activity the executive has to do next, why it is next, and the stage
/// the lead is in. Deliberately carries no due date, pending count, priority or
/// overdue badge — the pending activity itself is the message.
class _NextActionBanner extends StatelessWidget {
  final EmployeeNextAction action;
  final LeadStatus stage;
  final VoidCallback? onTap;

  const _NextActionBanner({
    required this.action,
    required this.stage,
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
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    'NEXT ACTION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_actionIcon(action.kind), size: 20, color: accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      action.title,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                action.description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: context.fomraTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Current Stage:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.fomraTextSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: stage.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      stage.label,
                      style: TextStyle(
                        color: stage.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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

  const _PendingTaskBanner({required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: context.fomraSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.fomraBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: _TaskStat(
                  label: 'Due Today',
                  value: '${summary.dueToday}',
                  color: AppColors.warning,
                ),
              ),
              Container(width: 1, height: 28, color: context.fomraBorder),
              Expanded(
                child: _TaskStat(
                  label: 'Overdue',
                  value: '${summary.overdue}',
                  color: AppColors.error,
                ),
              ),
              Container(width: 1, height: 28, color: context.fomraBorder),
              Expanded(
                child: _TaskStat(
                  label: 'Pending Since',
                  value: summary.pendingSinceDays <= 0
                      ? '—'
                      : '${summary.pendingSinceDays}d',
                  color: AppColors.info,
                ),
              ),
            ],
          ),
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
    // Keep the number prominent on phones and stop the label from wrapping to
    // an awkward second line in the narrow column.
    final mobile = FomraLayout.isMobile(context);
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: mobile ? 18 : 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: context.fomraTextSecondary,
          ),
        ),
      ],
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
