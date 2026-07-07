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

  Future<void> _resetPassword(EmployeeProfile employee) async {
    final ctrl = TextEditingController(text: 'fomra@2024');
    final newPw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Set a new login password for ${employee.fullName}.',
                style: TextStyle(fontSize: 13, color: context.fomraTextSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Reset')),
        ],
      ),
    );
    if (newPw == null || newPw.length < 6 || !mounted) {
      if (newPw != null && newPw.length < 6 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Password must be at least 6 characters.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }
    try {
      await EmployeeService.resetAuthPassword(employee.email, newPw);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Password reset for ${employee.fullName}'),
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

  Future<void> _provisionAllLogins() async {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Provisioning employee logins…'),
      behavior: SnackBarBehavior.floating,
    ));
    try {
      final n = await EmployeeService.provisionAllEmployees();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Provisioned logins for $n employee(s).'),
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
                  Row(
                    children: [
                      Expanded(
                        child: EmployeeManagementAddButton(
                          onPressed: _openAddEmployee,
                        ),
                      ),
                      _moreMenu(),
                    ],
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
                _moreMenu(),
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

  Widget _moreMenu() {
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(Icons.more_vert_rounded, color: context.fomraTextSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 8,
      onSelected: (v) {
        if (v == 'provision') _provisionAllLogins();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'provision',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.key_outlined, size: 20),
            title: Text('Provision logins for all'),
            subtitle: Text('One-time: give every employee a login'),
          ),
        ),
      ],
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
