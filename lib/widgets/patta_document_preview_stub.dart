import 'dart:typed_data';

import 'package:flutter/material.dart';

class PattaDocumentPreview extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    final len = pdfBytes?.length ??
        (pdfBase64 != null ? (pdfBase64!.length * 3 / 4).round() : 0);
    final sizeKb = (len / 1024).round();
    final name = fileName ?? 'Document.pdf';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFC62828).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
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
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1B3A6B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  sizeKb > 0 ? 'PDF · $sizeKb KB' : 'PDF document',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const Icon(Icons.open_in_new_rounded, size: 18, color: Color(0xFFC62828)),
        ],
      ),
    );
  }
}
