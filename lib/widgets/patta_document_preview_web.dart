import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Clickable PDF card — opens the document in a new browser tab (no inline iframe).
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
    final blob = html.Blob([bytes], 'application/pdf');
    _blobUrl = html.Url.createObjectUrlFromBlob(blob);
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openInNewTab,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFC62828).withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 28,
                  color: Color(0xFFC62828),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B3A6B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sizeKb > 0
                          ? 'PDF document · $sizeKb KB · Click to open'
                          : 'PDF document · Click to open in new tab',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFFC62828)),
                    SizedBox(width: 4),
                    Text(
                      'Open',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC62828),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
