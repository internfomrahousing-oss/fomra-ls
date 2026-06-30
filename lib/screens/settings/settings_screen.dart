import 'package:flutter/material.dart';
import 'change_password_screen.dart';
import '../../services/auth_service.dart';
import '../../services/theme_controller.dart';
import '../../theme/app_theme.dart';
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
                previewDark: false,
                selected: !isDark,
                onTap: () => ThemeController.instance.setDark(false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ThemeOption(
                icon: Icons.dark_mode_outlined,
                label: 'Dark',
                previewDark: true,
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
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
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
              Icon(icon,
                  size: 14,
                  color: selected
                      ? cs.primary
                      : cs.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? cs.primary
                          : cs.onSurface.withValues(alpha: 0.8))),
            ],
          ),
          const SizedBox(height: 4),
          AnimatedOpacity(
            opacity: selected ? 1 : 0,
            duration: const Duration(milliseconds: 180),
            child: Icon(Icons.check_circle, size: 14, color: cs.primary),
          ),
        ]),
      ),
    );
  }
}

/// Tiny mock UI showing how each theme looks before selecting it.
class _ThemeMiniPreview extends StatelessWidget {
  final bool isDark;
  const _ThemeMiniPreview({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pageBg = isDark ? AppColors.darkBackground : AppColors.background;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final text = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtext =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
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
            child: _ThemeMiniPreviewContent(
              isDark: isDark,
              pageBg: pageBg,
              surface: surface,
              border: border,
              text: text,
              subtext: subtext,
              accent: accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeMiniPreviewContent extends StatelessWidget {
  final bool isDark;
  final Color pageBg;
  final Color surface;
  final Color border;
  final Color text;
  final Color subtext;
  final Color accent;

  const _ThemeMiniPreviewContent({
    required this.isDark,
    required this.pageBg,
    required this.surface,
    required this.border,
    required this.text,
    required this.subtext,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
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
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : AppColors.heroGradient,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 3,
                            decoration: BoxDecoration(
                              color: text,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: double.infinity,
                            height: 3,
                            decoration: BoxDecoration(
                              color: subtext.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 12,
                            height: 3,
                            decoration: BoxDecoration(
                              color: subtext.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.35)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: border),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
