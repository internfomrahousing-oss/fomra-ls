import 'package:flutter/material.dart';
import 'change_password_screen.dart';
import '../../services/auth_service.dart';
import '../../services/theme_controller.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FomraAppBar(moduleName: 'Settings'),
      drawer: const AppDrawer(currentRoute: '/settings'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/settings'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const _ThemeSection(),
          const SizedBox(height: 18),
          _ChangePasswordButtonSection(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
            ),
          ),
          const SizedBox(height: 18),
          const _SignOutSection(),
        ],
      ),
    );
  }
}

// ── Section shell ──────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

// ── Theme ────────────────────────────────────────────────────────────────────

class _ThemeSection extends StatelessWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      icon: Icons.palette_outlined,
      title: 'Appearance',
      subtitle: 'Choose how FomraLS looks',
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance.mode,
        builder: (context, mode, _) {
          final isDark = mode == ThemeMode.dark;
          return Row(children: [
            Expanded(
              child: _ThemeOption(
                icon: Icons.light_mode_outlined,
                label: 'Light',
                selected: !isDark,
                onTap: () => ThemeController.instance.setDark(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ThemeOption(
                icon: Icons.dark_mode_outlined,
                label: 'Dark',
                selected: isDark,
                onTap: () => ThemeController.instance.setDark(true),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.12)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? cs.primary
                : cs.outline.withValues(alpha: 0.4),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(children: [
          Icon(icon,
              size: 26,
              color: selected
                  ? cs.primary
                  : cs.onSurface.withValues(alpha: 0.6)),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.8))),
          const SizedBox(height: 6),
          AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Icon(Icons.check_circle, size: 16, color: cs.primary),
          ),
        ]),
      ),
    );
  }
}

class _ChangePasswordButtonSection extends StatelessWidget {
  final VoidCallback onTap;

  const _ChangePasswordButtonSection({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      icon: Icons.lock_outline,
      title: 'Change Password',
      subtitle: 'Open password update form',
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.lock_open_outlined, size: 18),
          label: const Text('Change Password'),
        ),
      ),
    );
  }
}

class _SignOutSection extends StatelessWidget {
  const _SignOutSection();

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return _SettingsCard(
      icon: Icons.logout_rounded,
      title: 'Sign Out',
      subtitle: 'End your current session',
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {
            AuthService.instance.logout();
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          },
          icon: Icon(Icons.logout_rounded, size: 18, color: error),
          label: Text('Sign Out', style: TextStyle(color: error)),
          style: OutlinedButton.styleFrom(
            foregroundColor: error,
            side: BorderSide(color: error.withValues(alpha: 0.45)),
          ),
        ),
      ),
    );
  }
}
