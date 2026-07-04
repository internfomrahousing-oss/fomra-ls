import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// Embeds Patta/Chitta HTML inline via blob URL iframe.
class PattaHtmlPreview extends StatefulWidget {
  final String html;
  final String? title;
  final double height;

  const PattaHtmlPreview({
    super.key,
    required this.html,
    this.title,
    this.height = 520,
  });

  @override
  State<PattaHtmlPreview> createState() => _PattaHtmlPreviewState();
}

class _PattaHtmlPreviewState extends State<PattaHtmlPreview> {
  late String _viewType;
  String? _blobUrl;

  @override
  void initState() {
    super.initState();
    _viewType = 'patta-html-${DateTime.now().microsecondsSinceEpoch}';
    _mountHtml(widget.html);
  }

  @override
  void didUpdateWidget(covariant PattaHtmlPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.html != widget.html) {
      _revokeBlob();
      _viewType = 'patta-html-${DateTime.now().microsecondsSinceEpoch}';
      _mountHtml(widget.html);
    }
  }

  void _mountHtml(String raw) {
    final content = decodePattaHtml(raw);
    final blob = html.Blob([utf8.encode(content)], 'text/html');
    _blobUrl = html.Url.createObjectUrlFromBlob(blob);
    final blobUrl = _blobUrl!;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      return html.IFrameElement()
        ..src = blobUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }

  void _revokeBlob() {
    if (_blobUrl != null) {
      html.Url.revokeObjectUrl(_blobUrl!);
      _blobUrl = null;
    }
  }

  @override
  void dispose() {
    _revokeBlob();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.title != null) ...[
          Row(
            children: [
              const Icon(Icons.article_outlined, size: 16, color: Color(0xFF1B5E20)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.title!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF1B5E20).withValues(alpha: 0.25)),
              color: Colors.white,
            ),
            child: HtmlElementView(viewType: _viewType),
          ),
        ),
      ],
    );
  }
}

String decodePattaHtml(String htmlOrBase64) {
  if (htmlOrBase64.trimLeft().startsWith('<')) return htmlOrBase64;
  try {
    return utf8.decode(base64.decode(htmlOrBase64));
  } catch (_) {
    return htmlOrBase64;
  }
}
