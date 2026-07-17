import 'package:flutter/material.dart';

import '../../models/employee_profile.dart';
import '../../services/access_as_user.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/employee_management_ui.dart' show EmployeeStatusBadge;
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/profile_avatar.dart';

/// Human label for a profile's role (empty designation reads as Executive).
String _roleLabel(EmployeeProfile e) =>
    e.designation.trim().isEmpty ? EmployeeDesignations.executive : e.designation.trim();

/// Management-only "Access as User": search active users, filter by role, and
/// temporarily access the app as one of them (no password) via [AccessAsUser].
class AccessAsUserPage extends StatefulWidget {
  const AccessAsUserPage({super.key});

  @override
  State<AccessAsUserPage> createState() => _AccessAsUserPageState();
}

enum _RoleFilter { all, executive, reportingManager, head }

extension on _RoleFilter {
  String get label => switch (this) {
        _RoleFilter.all => 'All',
        _RoleFilter.executive => 'Executive',
        _RoleFilter.reportingManager => 'Reporting Manager',
        _RoleFilter.head => 'Head',
      };

  bool matches(EmployeeProfile e) => switch (this) {
        _RoleFilter.all => true,
        _RoleFilter.executive => e.isExecutive,
        _RoleFilter.reportingManager => e.isReportingManager,
        _RoleFilter.head => e.isHead,
      };
}

class _AccessAsUserPageState extends State<AccessAsUserPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _RoleFilter _filter = _RoleFilter.all;
  List<EmployeeProfile> _all = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
        () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await EmployeeService.getAll();
    if (!mounted) return;
    setState(() {
      _all = list.where((e) => e.status == EmployeeStatus.active).toList()
        ..sort((a, b) =>
            a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
      _loading = false;
    });
  }

  List<EmployeeProfile> get _visible {
    return _all.where((e) {
      if (!_filter.matches(e)) return false;
      if (_query.isEmpty) return true;
      return e.fullName.toLowerCase().contains(_query) ||
          e.email.toLowerCase().contains(_query);
    }).toList();
  }

  Future<void> _access(EmployeeProfile user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.visibility_outlined, color: AppColors.warning),
        title: const Text('Access as this user?'),
        content: Text(
          'You will use the app exactly as ${user.fullName} '
          '(${_roleLabel(user)}) sees it — their dashboard, menus, leads '
          'and reports. A banner will let you return to management anytime.',
          style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Access'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AccessAsUser.start(user);
    if (!mounted) return;
    // Reload the whole app as the accessed user.
    fomraNavigateHome(context);
  }

  @override
  Widget build(BuildContext context) {
    // Defensive: only management may access this page.
    if (!AuthService.instance.isManagement) {
      return const FomraAppShell(
        currentRoute: '/settings',
        appBar: FomraAppBar(moduleName: 'Access as User'),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: AppCard(
            child: EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Management only',
              message: 'Access as User is available to the management account.',
            ),
          ),
        ),
      );
    }

    final visible = _visible;
    return FomraAppShell(
      currentRoute: '/settings',
      appBar: const FomraAppBar(moduleName: 'Access as User'),
      backgroundColor: context.fomraPageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader(
                  title: 'Access as User',
                  subtitle:
                      'Temporarily use the app as another user to see exactly '
                      'what they see. Every session is recorded in the audit log.',
                  icon: Icons.visibility_outlined,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: context.fomraSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.fomraBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.fomraBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final f in _RoleFilter.values) ...[
                        ChoiceChip(
                          label: Text(f.label),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _filter == f
                                ? Colors.white
                                : context.fomraTextSecondary,
                          ),
                          backgroundColor:
                              context.fomraSurfaceVar.withValues(alpha: 0.7),
                          selectedColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide.none,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                    ? const Center(
                        child: EmptyState(
                          icon: Icons.person_search_outlined,
                          title: 'No matching users',
                          message: 'Try a different search or role filter.',
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) =>
                            _UserRow(user: visible[i], onAccess: () => _access(visible[i])),
                      ),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final EmployeeProfile user;
  final VoidCallback onAccess;

  const _UserRow({required this.user, required this.onAccess});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      interactive: false,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ProfileAvatar(email: user.email, name: user.fullName, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.fomraTextPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    EmployeeStatusBadge(status: user.status),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _roleLabel(user),
                    if (user.department.trim().isNotEmpty) user.department.trim(),
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onAccess,
            icon: const Icon(Icons.login_rounded, size: 16),
            label: const Text('Access'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
