import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

/// TNGIS-style full-screen FMB sketch viewer (web).
class FmbSketchViewer {
  static Future<void> show(
    BuildContext context, {
    required Uint8List pdfBytes,
    String fileName = 'FMB Sketch.pdf',
    String? survey,
    String? subDivision,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'FMB Sketch',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) => _FmbSketchViewerDialog(
        pdfBytes: pdfBytes,
        fileName: fileName,
        survey: survey,
        subDivision: subDivision,
      ),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(anim), child: child),
      ),
    );
  }
}

class _FmbSketchViewerDialog extends StatefulWidget {
  final Uint8List pdfBytes;
  final String fileName;
  final String? survey;
  final String? subDivision;

  const _FmbSketchViewerDialog({
    required this.pdfBytes,
    required this.fileName,
    this.survey,
    this.subDivision,
  });

  @override
  State<_FmbSketchViewerDialog> createState() => _FmbSketchViewerDialogState();
}

class _FmbSketchViewerDialogState extends State<_FmbSketchViewerDialog> {
  String? _blobUrl;
  String _viewType = '';
  bool _fullscreen = false;
  static int _viewCounter = 0;

  @override
  void initState() {
    super.initState();
    _preparePdfView();
  }

  void _preparePdfView() {
    final blob = html.Blob([widget.pdfBytes], 'application/pdf');
    _blobUrl = html.Url.createObjectUrlFromBlob(blob);
    _viewType = 'fmb-sketch-${_viewCounter++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      final iframe = html.IFrameElement()
        ..src = '$_blobUrl#toolbar=1&navpanes=0&view=FitH'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true
        ..title = widget.fileName;
      return iframe;
    });
  }

  @override
  void dispose() {
    if (_blobUrl != null) html.Url.revokeObjectUrl(_blobUrl!);
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _download() {
    if (_blobUrl == null) return;
    html.AnchorElement(href: _blobUrl)
      ..download = widget.fileName
      ..click();
  }

  void _print() {
    if (_blobUrl == null) return;
    html.window.open('$_blobUrl#print-dialog', '_blank');
  }

  void _openTab() {
    if (_blobUrl == null) return;
    html.window.open(_blobUrl!, '_blank');
  }

  void _toggleFullscreen() => setState(() => _fullscreen = !_fullscreen);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = _fullscreen ? size.width : (size.width * 0.92).clamp(720.0, 1200.0);
    final h = _fullscreen ? size.height : (size.height * 0.88).clamp(520.0, 900.0);

    final subtitle = [
      if (widget.survey != null && widget.survey!.isNotEmpty) 'Survey ${widget.survey}',
      if (widget.subDivision != null && widget.subDivision!.isNotEmpty) 'Sub ${widget.subDivision}',
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: const Color(0xFF263238),
            borderRadius: _fullscreen ? BorderRadius.zero : BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title bar — matches TNGIS dark header
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A237E), Color(0xFF283593)],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'FMB Sketch',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: _fullscreen ? 'Exit fullscreen' : 'Fullscreen',
                      onPressed: _toggleFullscreen,
                      icon: Icon(
                        _fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _close,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Toolbar — download / print / open
              Container(
                height: 40,
                color: const Color(0xFF37474F),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    _ToolbarBtn(icon: Icons.download_outlined, label: 'Download', onTap: _download),
                    _ToolbarBtn(icon: Icons.print_outlined, label: 'Print', onTap: _print),
                    _ToolbarBtn(icon: Icons.open_in_new, label: 'Open', onTap: _openTab),
                    const Spacer(),
                    Text(
                      '${(widget.pdfBytes.length / 1024).round()} KB · TNGIS Tamil Nilam',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
                    ),
                  ],
                ),
              ),
              // PDF canvas
              Expanded(
                child: ColoredBox(
                  color: Colors.grey.shade200,
                  child: _viewType.isNotEmpty
                      ? HtmlElementView(viewType: _viewType)
                      : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolbarBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Icon(icon, color: Colors.white70, size: 20),
        ),
      ),
    );
  }
}
