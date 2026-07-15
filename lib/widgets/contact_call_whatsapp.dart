import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';
import 'ui/app_feedback.dart';

/// The one contact-action component: compact circular Call + WhatsApp buttons.
///
/// Styled to match the floating action buttons on the lead workspace — a solid
/// accent circle with a white glyph — and icon-only, with the label moved into
/// a hover tooltip on desktop / long-press on mobile.
///
/// Renders nothing when [contact] has no dialable digits, so callers can drop
/// it into a row unconditionally.
class ContactCallWhatsApp extends StatelessWidget {
  final String contact;

  /// Accent for the Call button. WhatsApp always uses its brand green so the
  /// action is recognisable wherever it appears.
  final Color accent;

  /// Diameter of each button. Defaults to the same size as
  /// [FloatingActionButton.small].
  final double size;

  final double iconSize;

  const ContactCallWhatsApp({
    super.key,
    required this.contact,
    required this.accent,
    this.size = 36,
    this.iconSize = 18,
  });

  /// WhatsApp brand green, matching the lead workspace quick-action FAB.
  static const whatsAppGreen = Color(0xFF25D366);

  static String normalize(String contact) =>
      contact.replaceAll(RegExp(r'[^\d+]'), '');

  Future<void> _launch(BuildContext context, String scheme) async {
    final raw = normalize(contact);
    if (raw.isEmpty) {
      AppFeedback.warning(context, 'No contact number available');
      return;
    }
    final uri = scheme.startsWith('https://wa.me')
        ? Uri.parse('https://wa.me/$raw')
        : Uri.parse('$scheme:$raw');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        AppFeedback.error(context, 'Could not open contact action');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (normalize(contact).isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircleActionButton(
          tooltip: 'Call',
          icon: Icons.call_outlined,
          color: accent,
          size: size,
          iconSize: iconSize,
          onTap: () => _launch(context, 'tel'),
        ),
        const SizedBox(width: 8),
        _CircleActionButton(
          tooltip: 'WhatsApp',
          icon: Icons.chat_rounded,
          color: whatsAppGreen,
          size: size,
          iconSize: iconSize,
          onTap: () => _launch(context, 'https://wa.me'),
        ),
      ],
    );
  }
}

class _CircleActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          width: size,
          height: size,
          child: Material(
            color: color,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            elevation: 1,
            shadowColor: color.withValues(alpha: 0.4),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              hoverColor: Colors.white.withValues(alpha: 0.16),
              child: Icon(icon, size: iconSize, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

/// Same contact actions, sized for dense rows (lists, table cells).
class ContactCallWhatsAppCompact extends StatelessWidget {
  final String contact;
  final Color accent;

  const ContactCallWhatsAppCompact({
    super.key,
    required this.contact,
    this.accent = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) => ContactCallWhatsApp(
        contact: contact,
        accent: accent,
        size: 30,
        iconSize: 15,
      );
}
