import 'package:flutter/material.dart';

import '../../models/employee_profile.dart';
import '../../services/app_store.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../services/team_hierarchy.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/credentials_dialog.dart';
import '../../widgets/employee_management_ui.dart';
import '../../widgets/ui/app_feedback.dart';
import '../../widgets/portal_home_sections.dart';
import '../../widgets/portal_page_layout.dart';
import '../../widgets/ui/app_components.dart';
import 'add_employee_screen.dart';

class EmployeeManagementScreen extends StatefulWidget {
  final bool isTab;
  const EmployeeManagementScreen({super.key, this.isTab = true});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  bool _loading = true;
  String? _loadError;
  String _search = '';

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_onStoreUpdate);
    _loadEmployees();
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() => setState(() {});

  Future<void> _loadEmployees() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final list = await EmployeeService.getAll();
      AppStore.instance.setEmployees(list);
    } catch (e) {
      setState(() => _loadError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddEmployee() async {
    final created = await Navigator.push<EmployeeProfile>(
      context,
      MaterialPageRoute(builder: (_) => const AddEmployeeScreen()),
    );
    if (created != null) {
      AppStore.instance.addEmployee(created);
    }
  }

  /// Set (or reset) an employee's login to a freshly generated password and
  /// show it so management can hand it over. Works whether or not they already
  /// had a login — no invite email involved.
  Future<void> _setPassword(EmployeeProfile employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set password'),
        content: Text(
          'Generate a new password for ${employee.email}? You\'ll see it once '
          'to share with them; it replaces any existing password.',
          style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Generate')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final password = EmployeeService.generatePassword();
    try {
      await EmployeeService.provisionLogin(employee.email, password: password);
      if (!mounted) return;
      await showCredentialsDialog(
        context,
        email: employee.email,
        password: password,
        title: 'Password set for ${employee.fullName}',
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.errorDetails(
        context,
        title: 'Could not set the password',
        message: 'Setting a login for ${employee.email} failed:\n\n'
            '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _confirmRemoveAccess(EmployeeProfile employee) async {
    final reports = TeamHierarchy.directReports(employee.email).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete user?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${employee.fullName} (${employee.email}) will be permanently '
              'deleted — their login, their profile, and their place in every '
              'dropdown, team, report and dashboard. They will not be able to '
              'sign in again.',
            ),
            if (reports > 0) ...[
              const SizedBox(height: 12),
              Text(
                '$reports team member${reports == 1 ? '' : 's'} reporting to '
                'them will become unassigned, ready to move to another manager '
                'in Team Management.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Sites they added are kept for the record.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete user'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await EmployeeService.deleteEmployee(employee.id);
      AppStore.instance.removeEmployee(employee.id);
      if (!mounted) return;
      AppFeedback.success(context, '${employee.fullName} deleted');
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  List<EmployeeProfile> get _employees => AppStore.instance.employees;

  List<EmployeeProfile> get _filtered {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _employees;
    return _employees.where((e) {
      return e.fullName.toLowerCase().contains(q) ||
          e.email.toLowerCase().contains(q) ||
          e.phone.contains(q) ||
          e.designation.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isManagement) {
      return Center(
        child: Padding(
          padding: FomraLayout.pagePadding(context),
          child: Text(
            'Employee management is available to management only.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.fomraTextSecondary),
          ),
        ),
      );
    }

    final pagePad = FomraLayout.pagePadding(context);

    final header = Padding(
      padding: pagePad.copyWith(bottom: 8),
      child: PortalFadeSection(
        index: 0,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 640;
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EmployeeManagementSearchBar(
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 10),
                  EmployeeManagementAddButton(
                    onPressed: _openAddEmployee,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: EmployeeManagementSearchBar(
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 12),
                EmployeeManagementAddButton(
                  onPressed: _openAddEmployee,
                ),
              ],
            );
          },
        ),
      ),
    );

    // Full-width list so the scrollbar sits at the window edge; the header and
    // list items stay centered (~94% width) like the home page.
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            FomraLayout.isDesktop(context) ? constraints.maxWidth * 0.03 : 0.0;
        final listPad = pagePad.copyWith(top: 0, bottom: 24);
        return Column(
          children: [
            portalPageWidthConstraint(context, header),
            Expanded(
              child: _loading
                  ? const _EmployeeLoadingSkeleton()
                  : _loadError != null
                      ? portalPageWidthConstraint(
                          context,
                          EmptyState(
                            icon: Icons.cloud_off_outlined,
                            title: 'Couldn’t load employees',
                            message: _loadError,
                            action: PrimaryButton(
                              label: 'Retry',
                              icon: Icons.refresh,
                              onPressed: _loadEmployees,
                            ),
                          ),
                        )
                      : _filtered.isEmpty
                          ? portalPageWidthConstraint(
                              context,
                              EmptyState(
                                icon: Icons.groups_outlined,
                                title: _employees.isEmpty
                                    ? 'No employees yet'
                                    : 'No matches',
                                message: _employees.isEmpty
                                    ? 'Add an employee profile to get started.'
                                    : 'Try a different search term.',
                                action: _employees.isEmpty
                                    ? PrimaryButton(
                                        label: 'Add Employee',
                                        icon: Icons.person_add_outlined,
                                        onPressed: _openAddEmployee,
                                      )
                                    : null,
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadEmployees,
                              child: ListView.builder(
                                padding: EdgeInsets.fromLTRB(
                                    listPad.left + side,
                                    listPad.top,
                                    listPad.right + side,
                                    listPad.bottom),
                                itemCount: _filtered.length,
                                itemBuilder: (_, i) => PortalFadeSection(
                                  index: i.clamp(0, 6),
                                  child: EmployeeManagementCard(
                                    employee: _filtered[i],
                                    onRemoveAccess: () =>
                                        _confirmRemoveAccess(_filtered[i]),
                                    onSetPassword: () =>
                                        _setPassword(_filtered[i]),
                                  ),
                                ),
                              ),
                            ),
            ),
          ],
        );
      },
    );
  }

}

class _EmployeeLoadingSkeleton extends StatelessWidget {
  const _EmployeeLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: FomraLayout.pagePadding(context),
      children: List.generate(
        6,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: LoadingSkeleton(height: 96, radius: 16),
        ),
      ),
    );
  }
}
