import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/change_password_section.dart';
import '../../widgets/portal_page_layout.dart';
import '../employee_management/employee_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isManagement = AuthService.instance.isManagement;

    return FomraAppShell(
      currentRoute: '/settings',
      appBar: const FomraAppBar(moduleName: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manage account and workspace options.',
            style: TextStyle(
              fontSize: 13,
              color: context.fomraTextSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SettingsTile(
                icon: Icons.lock_outline,
                label: 'Reset Password',
                accent: AppColors.purple,
                onTap: () => showResetPasswordDialog(context),
              ),
              if (isManagement)
                _SettingsTile(
                  icon: Icons.groups_outlined,
                  label: 'User Management',
                  accent: AppColors.secondary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const _UserManagementPage(),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        widget.accent.withValues(alpha: _hovered ? 0.45 : 0.25);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 148,
          height: 118,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.fomraSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: _hovered ? 1.5 : 1),
            boxShadow: _hovered ? context.fomraCardShadow : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.accent, size: 20),
              ),
              const Spacer(),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.fomraTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: context.fomraTextSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserManagementPage extends StatelessWidget {
  const _UserManagementPage();

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/settings',
      backgroundColor: context.fomraPageBg,
      appBar: FomraSubPageAppBar(
        title: 'User Management',
        breadcrumbs: FomraBreadcrumbs.fromSettings('User Management'),
      ),
      body: const EmployeeManagementScreen(isTab: true),
    );
  }
}
