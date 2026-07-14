import 'package:flutter/material.dart';

import '../../models/employee_profile.dart';
import '../../services/app_store.dart';
import '../../services/employee_service.dart';
import '../../services/team_hierarchy.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/portal_page_layout.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/app_feedback.dart';
import '../../widgets/ui/profile_avatar.dart';

/// "Manage Team": a Reporting Manager assigns Executives; a Head assigns
/// Reporting Managers (each expandable to its Executives). Uses the existing
/// employee roster + reports_to line — no new pages/routes.
class TeamManagementScreen extends StatefulWidget {
  const TeamManagementScreen({super.key});

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final list = await EmployeeService.getAll();
      if (list.isNotEmpty) AppStore.instance.setEmployees(list);
    } catch (_) {/* keep whatever is cached */}
    if (mounted) setState(() => _loading = false);
  }

  EmployeeProfile? get _me => TeamHierarchy.currentProfile;

  Future<void> _assign(String employeeEmail, String managerEmail) async {
    await EmployeeService.assignReportsTo(employeeEmail, managerEmail);
    await _reload();
  }

  Future<void> _pickAndAdd({
    required String title,
    required List<EmployeeProfile> options,
    required String managerEmail,
  }) async {
    if (options.isEmpty) {
      AppFeedback.info(context, 'No unassigned members available to add.');
      return;
    }
    final picked = await showModalBottomSheet<EmployeeProfile>(
      context: context,
      backgroundColor: context.fomraSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in options)
                    ListTile(
                      leading: ProfileAvatar(
                        email: e.email,
                        name: e.fullName,
                        radius: 18,
                      ),
                      title: Text(e.fullName),
                      subtitle: Text(e.designation.isEmpty
                          ? EmployeeDesignations.executive
                          : e.designation),
                      onTap: () => Navigator.pop(ctx, e),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) await _assign(picked.email, managerEmail);
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return FomraAppShell(
      currentRoute: '/home',
      backgroundColor: context.fomraPageBg,
      appBar: FomraSubPageAppBar(
        title: 'Manage Team',
        breadcrumbs: FomraBreadcrumbs.fromWorkspace('Manage Team'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (me == null)
                  const AppCard(
                    child: EmptyState(
                      icon: Icons.group_off_outlined,
                      title: 'Team management unavailable',
                      message:
                          'Your profile could not be found. Ask management to set your designation.',
                    ),
                  )
                else if (me.isReportingManager)
                  _reportingManagerView(me)
                else if (me.isHead)
                  _headView(me)
                else
                  const AppCard(
                    child: EmptyState(
                      icon: Icons.info_outline_rounded,
                      title: 'No team to manage',
                      message:
                          'Team management is available to Reporting Managers and Heads.',
                    ),
                  ),
              ],
            ),
    );
  }

  // ── Reporting Manager: assign executives ───────────────────────────────────
  Widget _reportingManagerView(EmployeeProfile me) {
    final execs = TeamHierarchy.executivesUnder(me.email);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'My Executives',
          subtitle: '${execs.length} assigned',
          icon: Icons.groups_2_outlined,
          trailing: TextButton.icon(
            onPressed: () => _pickAndAdd(
              title: 'Add executive',
              options: TeamHierarchy.unassignedExecutives(),
              managerEmail: me.email,
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Add'),
          ),
        ),
        const SizedBox(height: 12),
        if (execs.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.person_search_outlined,
              title: 'No executives yet',
              message: 'Use Add to assign executives to your team.',
            ),
          )
        else
          for (final e in execs) _memberTile(e, onRemove: () => _assign(e.email, '')),
      ],
    );
  }

  // ── Head: assign reporting managers, expand to executives ──────────────────
  Widget _headView(EmployeeProfile me) {
    final rms = TeamHierarchy.managersUnder(me.email);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'My Reporting Managers',
          subtitle: '${rms.length} assigned',
          icon: Icons.supervisor_account_outlined,
          trailing: TextButton.icon(
            onPressed: () => _pickAndAdd(
              title: 'Add reporting manager',
              options: TeamHierarchy.unassignedManagers(),
              managerEmail: me.email,
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Add'),
          ),
        ),
        const SizedBox(height: 12),
        if (rms.isEmpty)
          const AppCard(
            child: EmptyState(
              icon: Icons.person_search_outlined,
              title: 'No reporting managers yet',
              message: 'Use Add to assign reporting managers to your team.',
            ),
          )
        else
          for (final rm in rms)
            _ManagerExpansionCard(
              manager: rm,
              executives: TeamHierarchy.executivesUnder(rm.email),
              onRemove: () => _assign(rm.email, ''),
            ),
      ],
    );
  }

  Widget _memberTile(EmployeeProfile e, {VoidCallback? onRemove}) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: AppColors.radiusMd,
      interactive: false,
      child: Row(
        children: [
          ProfileAvatar(email: e.email, name: e.fullName, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.fullName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.fomraTextPrimary,
                  ),
                ),
                Text(
                  e.designation.isEmpty
                      ? EmployeeDesignations.executive
                      : e.designation,
                  style:
                      TextStyle(fontSize: 12, color: context.fomraTextSecondary),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove from team',
              onPressed: onRemove,
              icon: const Icon(Icons.person_remove_outlined, size: 20),
              color: AppColors.error,
            ),
        ],
      ),
    );
  }
}

class _ManagerExpansionCard extends StatefulWidget {
  final EmployeeProfile manager;
  final List<EmployeeProfile> executives;
  final VoidCallback onRemove;

  const _ManagerExpansionCard({
    required this.manager,
    required this.executives,
    required this.onRemove,
  });

  @override
  State<_ManagerExpansionCard> createState() => _ManagerExpansionCardState();
}

class _ManagerExpansionCardState extends State<_ManagerExpansionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final execs = widget.executives;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.fomraSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.fomraBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ProfileAvatar(
                    email: widget.manager.email,
                    name: widget.manager.fullName,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.manager.fullName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                        Text(
                          'Reporting Manager · ${execs.length} executive${execs.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove from team',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.person_remove_outlined, size: 20),
                    color: AppColors.error,
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: context.fomraTextSecondary),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            if (execs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'No executives assigned to this reporting manager.',
                  style: TextStyle(color: context.fomraTextSecondary),
                ),
              )
            else
              for (final e in execs)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                  child: Row(
                    children: [
                      ProfileAvatar(
                          email: e.email, name: e.fullName, radius: 15),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.fullName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                      ),
                      Text(
                        'Executive',
                        style: TextStyle(
                            fontSize: 11, color: context.fomraTextSecondary),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}
