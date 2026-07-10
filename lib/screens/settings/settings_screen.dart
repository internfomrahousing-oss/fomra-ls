import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/theme_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/portal_page_layout.dart';
import '../../widgets/ui/app_components.dart';
import '../employee_management/employee_management_screen.dart';
import 'change_password_screen.dart';

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
            'Manage appearance, account, and workspace options.',
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
                icon: Icons.palette_outlined,
                label: 'Appearance',
                accent: AppColors.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const _AppearanceSettingsPage(),
                  ),
                ),
              ),
              _SettingsTile(
                icon: Icons.lock_outline,
                label: 'Reset Password',
                accent: AppColors.purple,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordScreen(),
                  ),
                ),
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
              _SettingsTile(
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                accent: AppColors.error,
                danger: true,
                onTap: () async {
                  final confirmed = await confirmSignOut(context);
                  if (!confirmed || !context.mounted) return;
                  AuthService.instance.logout();
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (_) => false,
                  );
                },
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
  final bool danger;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.danger = false,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.danger
        ? AppColors.error.withValues(alpha: 0.35)
        : widget.accent.withValues(alpha: _hovered ? 0.45 : 0.25);

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
                  color: widget.danger
                      ? AppColors.error
                      : context.fomraTextPrimary,
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

class _AppearanceSettingsPage extends StatelessWidget {
  const _AppearanceSettingsPage();

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/settings',
      backgroundColor: context.fomraPageBg,
      appBar: FomraSubPageAppBar(
        title: 'Appearance',
        breadcrumbs: FomraBreadcrumbs.fromSettings('Appearance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            interactive: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose how FomraLS looks',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.fomraTextPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.instance.mode,
                  builder: (context, mode, _) {
                    final isDark = mode == ThemeMode.dark;
                    return Row(
                      children: [
                        Expanded(
                          child: _ThemeOption(
                            icon: Icons.wb_sunny_outlined,
                            label: 'Light',
                            previewDark: false,
                            selected: !isDark,
                            onTap: () =>
                                ThemeController.instance.setDark(false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ThemeOption(
                            icon: Icons.nightlight_round,
                            label: 'Dark',
                            previewDark: true,
                            selected: isDark,
                            onTap: () =>
                                ThemeController.instance.setDark(true),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
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

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool previewDark;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.previewDark,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: 56,
                child: _ThemeMiniPreview(isDark: previewDark),
              ),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: Icon(Icons.check_circle, size: 14, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeMiniPreview extends StatelessWidget {
  final bool isDark;
  const _ThemeMiniPreview({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pageBg = isDark ? AppColors.darkBackground : AppColors.background;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final accent = isDark ? AppColors.primaryLight : AppColors.primary;

    return AspectRatio(
      aspectRatio: 1.9,
      child: Container(
        decoration: BoxDecoration(
          color: pageBg,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: FittedBox(
          fit: BoxFit.contain,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 88,
            height: 88 / 1.9,
            child: ColoredBox(
              color: pageBg,
              child: Column(
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF152A52),
                                Color(0xFF1E293B),
                                Color(0xFF231B4A),
                              ],
                            )
                          : AppColors.heroGradient,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: border),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
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
