import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'ui/app_feedback.dart';

/// Shows a new employee's login credentials for management to hand over
/// directly (there is no invite email). The password is shown once — it can't
/// be read back later, only reset — so the dialog makes it easy to copy.
Future<void> showCredentialsDialog(
  BuildContext context, {
  required String email,
  required String password,
  String title = 'Login created',
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      Future<void> copyAll() async {
        await Clipboard.setData(
          ClipboardData(text: 'Email: $email\nPassword: $password'),
        );
        if (ctx.mounted) AppFeedback.success(ctx, 'Login details copied');
      }

      return AlertDialog(
        backgroundColor: ctx.fomraSurface,
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.success),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ctx.fomraTextPrimary,
          ),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Share these with the employee directly (WhatsApp, message, in '
                'person). They can sign in right away and change the password '
                'later. This password is shown only once.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: ctx.fomraTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _CredRow(label: 'Email', value: email),
              const SizedBox(height: 10),
              _CredRow(label: 'Password', value: password),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: copyAll,
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Done'),
          ),
        ],
      );
    },
  );
}

class _CredRow extends StatelessWidget {
  final String label;
  final String value;

  const _CredRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.fomraBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.fomraTextSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: context.fomraTextPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy $label',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 16),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              if (context.mounted) AppFeedback.success(context, '$label copied');
            },
          ),
        ],
      ),
    );
  }
}
