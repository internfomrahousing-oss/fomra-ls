import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui/app_feedback.dart';

/// Compact Call + WhatsApp action buttons for a contact number.
///
/// Renders nothing when [contact] has no dialable digits, so callers can drop
/// it into a row unconditionally.
class ContactCallWhatsApp extends StatelessWidget {
  final String contact;
  final Color accent;
  final double iconSize;

  const ContactCallWhatsApp({
    super.key,
    required this.contact,
    required this.accent,
    this.iconSize = 20,
  });

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
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Call',
          onPressed: () => _launch(context, 'tel'),
          icon: Icon(Icons.call_outlined, size: iconSize, color: accent),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'WhatsApp',
          onPressed: () => _launch(context, 'https://wa.me'),
          icon: Icon(Icons.chat_outlined, size: iconSize, color: accent),
        ),
      ],
    );
  }
}
