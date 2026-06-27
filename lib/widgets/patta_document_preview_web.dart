import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// PDF preview with inline iframe + open-in-tab button (web).
class PattaDocumentPreview extends StatefulWidget {
  final Uint8List? pdfBytes;
  final String? pdfBase64;
  final String? fileName;
  final double height;

  const PattaDocumentPreview({
    super.key,
    this.pdfBytes,
    this.pdfBase64,
    this.fileName,
    this.height = 520,
  }) : assert(pdfBytes != null || pdfBase64 != null);

  @override
  State<PattaDocumentPreview> createState() => _PattaDocumentPreviewState();
}

class _PattaDocumentPreviewState extends State<PattaDocumentPreview> {
  String? _blobUrl;
  int _bytesLen = 0;
  String _viewType = '';
  static int _viewCounter = 0;

  @override
  void initState() {
    super.initState();
    _prepareBlob();
  }

  @override
  void didUpdateWidget(covariant PattaDocumentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLen = oldWidget.pdfBytes?.length ?? oldWidget.pdfBase64?.length ?? 0;
    final newLen = widget.pdfBytes?.length ?? widget.pdfBase64?.length ?? 0;
    if (oldWidget.pdfBytes != widget.pdfBytes
        || oldWidget.pdfBase64 != widget.pdfBase64
        || oldLen != newLen) {
      _revokeBlob();
      _prepareBlob();
    }
  }

  Uint8List _bytes() {
    return widget.pdfBytes ??
        Uint8List.fromList(base64.decode(widget.pdfBase64 ?? ''));
  }

  void _prepareBlob() {
    final bytes = _bytes();
    _bytesLen = bytes.length;
    if (_bytesLen < 100) return;
    final blob = html.Blob([bytes], 'application/pdf');
    _blobUrl = html.Url.createObjectUrlFromBlob(blob);
    _viewType = 'pdf-preview-${_viewCounter++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = html.IFrameElement()
        ..src = '$_blobUrl#toolbar=1&navpanes=0'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;
      return iframe;
    });
    if (mounted) setState(() {});
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

  void _openInNewTab() {
    if (_blobUrl != null) html.window.open(_blobUrl!, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    final fileName = widget.fileName ?? 'Document.pdf';
    final sizeKb = (_bytesLen / 1024).round();
    final hasPreview = _blobUrl != null && _bytesLen >= 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                fileName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B3A6B),
                ),
              ),
            ),
            if (hasPreview)
              TextButton.icon(
                onPressed: _openInNewTab,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open in tab', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        if (sizeKb > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'PDF · $sizeKb KB',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        if (hasPreview)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: _viewType.isNotEmpty
                  ? HtmlElementView(viewType: _viewType)
                  : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _openInNewTab,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.35)),
                ),
                child: const Text('PDF loaded — click to open'),
              ),
            ),
          ),
      ],
    );
  }
}
