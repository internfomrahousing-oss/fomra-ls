import 'package:flutter/material.dart';
import '../../services/api_client.dart';
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
        children: const [
          _ThemeSection(),
          SizedBox(height: 18),
          _ChangePasswordSection(),
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

// ── Change Password ──────────────────────────────────────────────────────────

class _ChangePasswordSection extends StatefulWidget {
  const _ChangePasswordSection();

  @override
  State<_ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends State<_ChangePasswordSection> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _saving = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await AuthService.instance.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );
      if (!mounted) return;
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
      _formKey.currentState!.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              e is ApiException ? e.message : 'Could not change password.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      icon: Icons.lock_outline,
      title: 'Change Password',
      subtitle: 'Update your sign-in password',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PasswordField(
              controller: _currentCtrl,
              label: 'Current password',
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your current password' : null,
            ),
            const SizedBox(height: 14),
            _PasswordField(
              controller: _newCtrl,
              label: 'New password',
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a new password';
                if (v.trim().length < 6) {
                  return 'Must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _PasswordField(
              controller: _confirmCtrl,
              label: 'Confirm new password',
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) =>
                  v != _newCtrl.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Update Password',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline, size: 20, color: cs.primary),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
