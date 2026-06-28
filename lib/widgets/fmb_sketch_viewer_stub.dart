import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'patta_document_preview.dart';

/// Non-web fallback — opens document preview card.
class FmbSketchViewer {
  static Future<void> show(
    BuildContext context, {
    required Uint8List pdfBytes,
    String fileName = 'FMB Sketch.pdf',
    String? survey,
    String? subDivision,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 640,
          height: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'FMB Sketch',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PattaDocumentPreview(
                  pdfBytes: pdfBytes,
                  fileName: fileName,
                  height: 420,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
