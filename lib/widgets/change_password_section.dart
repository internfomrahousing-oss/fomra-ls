import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'ui/app_feedback.dart';

/// Opens reset password as a compact dialog (e.g. from Settings).
Future<void> showResetPasswordDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    builder: (_) => const ResetPasswordDialog(),
  );
}

class ResetPasswordDialog extends StatelessWidget {
  const ResetPasswordDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: context.fomraSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: AppColors.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reset Password',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                        Text(
                          'We will email you a secure reset link',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const ChangePasswordSection(compact: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// Email-based password reset — sends a Supabase reset link to the user.
class ChangePasswordSection extends StatefulWidget {
  final bool compact;

  const ChangePasswordSection({super.key, this.compact = false});

  @override
  State<ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends State<ChangePasswordSection> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final email = AuthService.instance.currentUser?.email.trim() ?? '';
    _emailCtrl = TextEditingController(text: email);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await AuthService.instance.sendPasswordReset(_emailCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.success(
        context,
        'If that email has an account, a password reset link is on its way.',
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(
        context,
        e is ApiException ? e.message : 'Could not send reset email.',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Enter your account email and we'll send a secure link to set a new password.",
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: widget.compact
                  ? context.fomraTextSecondary
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (v) {
              final email = v?.trim() ?? '';
              if (email.isEmpty || !email.contains('@')) {
                return 'Enter a valid email address';
              }
              return null;
            },
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@company.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _submit,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Icon(Icons.mail_outline_rounded, size: 20),
              label: Text(
                _sending ? 'Sending…' : 'Send reset link',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Check your inbox and spam folder. The link opens the set-password page where you can choose a new password.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.compact) return form;

    return ChangePasswordCard(child: form);
  }
}

class ChangePasswordCard extends StatelessWidget {
  final Widget child;

  const ChangePasswordCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.lock_reset_rounded, color: cs.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'We will email you a link to set a new password',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}
