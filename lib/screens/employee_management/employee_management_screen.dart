import 'package:flutter/material.dart';

import '../../models/employee_profile.dart';
import '../../services/app_store.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/employee_management_ui.dart';
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

  /// Give a pre-invite employee an immediate login with the shared password
  /// fomra@2024 (they can change it later). For migrating existing staff.
  Future<void> _provisionLogin(EmployeeProfile employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Set login to fomra@2024'),
        content: Text(
          'Create a login for ${employee.email} with the password fomra@2024? '
          'They can sign in immediately and change it later.',
          style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Set password')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await EmployeeService.provisionLogin(employee.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${employee.email} can now log in with fomra@2024'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Re-send the "set your password" invite email. The employee then chooses
  /// their own new password — management never sets or sees it.
  Future<void> _resetPassword(EmployeeProfile employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Resend invite'),
        content: Text(
          'Send a new password-setup email to ${employee.email}? '
          'They will set their own password from the link.',
          style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send invite')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await EmployeeService.inviteEmployee(employee.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Invitation re-sent to ${employee.email}'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _confirmRemoveAccess(EmployeeProfile employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove access?'),
        content: Text(
          '${employee.fullName} (${employee.email}) will no longer be able to sign in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remove access'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await EmployeeService.removeAccess(employee.id);
      AppStore.instance.removeEmployee(employee.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Access removed for ${employee.fullName}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                                    onResetPassword: () =>
                                        _resetPassword(_filtered[i]),
                                    onProvisionLogin: () =>
                                        _provisionLogin(_filtered[i]),
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
