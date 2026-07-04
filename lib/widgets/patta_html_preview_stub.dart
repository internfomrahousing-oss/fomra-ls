import 'dart:convert';

import 'package:flutter/material.dart';

String decodePattaHtml(String htmlOrBase64) {
  if (htmlOrBase64.trimLeft().startsWith('<')) return htmlOrBase64;
  try {
    return utf8.decode(base64.decode(htmlOrBase64));
  } catch (_) {
    return htmlOrBase64;
  }
}

class PattaHtmlPreview extends StatelessWidget {
  final String html;
  final String? title;
  final double height;

  const PattaHtmlPreview({
    super.key,
    required this.html,
    this.title,
    this.height = 420,
  });

  @override
  Widget build(BuildContext context) {
    final text = decodePattaHtml(html).replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        child: Text(text.isEmpty ? 'Patta document loaded' : text, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
