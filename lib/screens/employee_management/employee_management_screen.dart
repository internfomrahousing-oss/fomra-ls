import 'package:flutter/material.dart';

import '../../models/employee_profile.dart';
import '../../services/app_store.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_input.dart';
import '../../theme/fomra_theme_context.dart';
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

  Future<void> _confirmRemoveAccess(EmployeeProfile employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Employee management is available to management only.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  style: TextStyle(color: context.fomraTextPrimary),
                  decoration: FomraInput.decoration(
                    context: context,
                    hint: 'Search employees…',
                    icon: Icons.search,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _openAddEmployee,
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Add Employee'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const _EmployeeLoadingSkeleton()
              : _loadError != null
                  ? EmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Couldn’t load employees',
                      message: _loadError,
                      action: PrimaryButton(
                        label: 'Retry',
                        icon: Icons.refresh,
                        onPressed: _loadEmployees,
                      ),
                    )
                  : _filtered.isEmpty
                      ? EmptyState(
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
                        )
                      : RefreshIndicator(
                          onRefresh: _loadEmployees,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) => _EmployeeCard(
                              employee: _filtered[i],
                              onRemoveAccess: () =>
                                  _confirmRemoveAccess(_filtered[i]),
                            ),
                          ),
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: List.generate(
        6,
        (_) => const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: LoadingSkeleton(height: 92, radius: AppColors.radiusSm),
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final EmployeeProfile employee;
  final VoidCallback onRemoveAccess;

  const _EmployeeCard({
    required this.employee,
    required this.onRemoveAccess,
  });

  @override
  Widget build(BuildContext context) {
    final active = employee.status == EmployeeStatus.active;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.fomraBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                employee.fullName.isNotEmpty
                    ? employee.fullName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
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
                          employee.fullName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.success.withValues(alpha: 0.12)
                              : context.fomraSurfaceVar,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          employee.status.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: active
                                ? AppColors.success
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    employee.email,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (employee.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(employee.phone,
                        style: TextStyle(
                            fontSize: 12, color: context.fomraTextSecondary)),
                  ],
                  if (employee.designation.isNotEmpty ||
                      employee.department.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (employee.designation.isNotEmpty)
                          employee.designation,
                        if (employee.department.isNotEmpty)
                          employee.department,
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.fomraTextTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove access',
              onPressed: onRemoveAccess,
              icon: const Icon(Icons.person_remove_outlined),
              color: AppColors.error,
            ),
          ],
        ),
      ),
    );
  }
}
