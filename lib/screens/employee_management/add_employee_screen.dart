import 'package:flutter/material.dart';

import '../../models/employee_profile.dart';
import '../../services/employee_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_input.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/credentials_dialog.dart';
import '../../widgets/ui/app_feedback.dart';
import '../../widgets/portal_home_sections.dart';
import '../../widgets/portal_page_layout.dart';
import '../../widgets/ui/app_components.dart';

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  static const _designations = <String>[
    'Executive',
    'Reporting Manager',
    'Head',
    'Management',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  String? _designation;
  bool _saving = false;

  /// How the new employee gets their login. Email invite = they set their own
  /// password via a link; otherwise management generates one and hands it over.
  bool _emailInvite = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_designation == null) {
      AppFeedback.warning(context, 'Select a designation');
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = await EmployeeService.create(
        fullName: _nameCtrl.text,
        email: _emailCtrl.text,
        designation: _designation!,
      );
      if (_emailInvite) {
        await _finishWithEmailInvite(profile);
      } else {
        await _finishWithGeneratedPassword(profile);
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Email the employee a link to set their own password. The profile is saved
  /// regardless; if the email can't be sent (e.g. SMTP not configured) that's
  /// surfaced and a password can still be set later from User Management.
  Future<void> _finishWithEmailInvite(EmployeeProfile profile) async {
    String? inviteError;
    String kind = 'invite';
    try {
      kind = await EmployeeService.inviteEmployee(
        profile.email,
        designation: profile.designation,
        fullName: profile.fullName,
      );
    } catch (e) {
      inviteError = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    Navigator.pop(context, profile);
    if (inviteError == null) {
      AppFeedback.success(
        context,
        kind == 'recovery'
            ? '${profile.fullName} already had a login — a set-password email '
                'was sent to ${profile.email}.'
            : 'Invite sent — ${profile.fullName} can set their password from '
                'the email at ${profile.email}.',
      );
    } else {
      AppFeedback.errorDetails(
        context,
        title: 'Employee saved, but the invite email could not be sent',
        message: '${profile.fullName} (${profile.email}) was created as '
            '${profile.designation}, but the set-password email failed:\n\n'
            '$inviteError\n\n'
            'Re-send from User Management, or set a password there directly.',
      );
    }
  }

  /// Generate a password now and show it once so management can hand it over.
  Future<void> _finishWithGeneratedPassword(EmployeeProfile profile) async {
    final password = EmployeeService.generatePassword();
    String? loginError;
    try {
      await EmployeeService.provisionLogin(profile.email, password: password);
    } catch (e) {
      loginError = e.toString().replaceFirst('Exception: ', '');
    }
    if (!mounted) return;
    Navigator.pop(context, profile);
    if (loginError == null) {
      await showCredentialsDialog(
        context,
        email: profile.email,
        password: password,
        title: '${profile.fullName} added',
      );
    } else {
      AppFeedback.errorDetails(
        context,
        title: 'Employee saved, but the login could not be created',
        message: '${profile.fullName} (${profile.email}) was created as '
            '${profile.designation}, but their login could not be set up:\n\n'
            '$loginError\n\n'
            'Set a password from User Management → Set password.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/settings',
      backgroundColor: context.fomraPageBg,
      appBar: const FomraSubPageAppBar(title: 'Add Employee'),
      body: portalScrollBody(
        context,
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
                child: PortalFadeSection(
                  index: 0,
                  child: AppCard(
                    padding: const EdgeInsets.all(24),
                    radius: 16,
                    interactive: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.badge_outlined,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create Employee Profile',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Add team member access credentials',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _field(
                          controller: _nameCtrl,
                          label: 'Employee Name',
                          icon: Icons.person_outline,
                          required: true,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _emailCtrl,
                          label: 'Work Email',
                          icon: Icons.email_outlined,
                          keyboard: TextInputType.emailAddress,
                          required: true,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _designation,
                          decoration: FomraInput.decoration(
                            context: context,
                            label: 'Designation',
                            icon: Icons.workspace_premium_outlined,
                            required: true,
                          ),
                          items: [
                            for (final d in _designations)
                              DropdownMenuItem(value: d, child: Text(d)),
                          ],
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Designation is required'
                              : null,
                          onChanged: (v) => setState(() => _designation = v),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'LOGIN SETUP',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _LoginSetupToggle(
                          emailInvite: _emailInvite,
                          onChanged: _saving
                              ? null
                              : (v) => setState(() => _emailInvite = v),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _emailInvite
                              ? 'The employee gets an email with a link to set '
                                  'their own password. Needs email (SMTP) set up '
                                  'in Supabase.'
                              : 'A password is generated now and shown once for '
                                  'you to hand over — no email needed.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _emailInvite
                                        ? Icons.mark_email_read_outlined
                                        : Icons.add_circle_outline,
                                    size: 18,
                                  ),
                            label: Text(
                              _emailInvite
                                  ? 'Create & Send Invite'
                                  : 'Create & Show Password',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboard,
    bool required = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator ??
          (required
              ? (v) =>
                  (v == null || v.trim().isEmpty) ? '$label is required' : null
              : null),
      decoration: FomraInput.decoration(
        context: context,
        label: label,
        icon: icon,
        required: required,
      ),
    );
  }
}

/// Two-way choice for how a new employee receives their login: an email invite
/// (they set their own password) or a generated password shown once.
class _LoginSetupToggle extends StatelessWidget {
  final bool emailInvite;
  final ValueChanged<bool>? onChanged;

  const _LoginSetupToggle({required this.emailInvite, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.fomraBorder),
      ),
      child: Row(
        children: [
          _option(
            context,
            selected: emailInvite,
            icon: Icons.mail_outline_rounded,
            label: 'Email invite',
            onTap: () => onChanged?.call(true),
          ),
          _option(
            context,
            selected: !emailInvite,
            icon: Icons.password_rounded,
            label: 'Set password now',
            onTap: () => onChanged?.call(false),
          ),
        ],
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : context.fomraTextSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : context.fomraTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
