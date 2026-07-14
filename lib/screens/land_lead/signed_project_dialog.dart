import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/land_lead.dart';
import '../../services/land_lead_legal_service.dart';
import '../../services/land_lead_signed_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../utils/image_compressor.dart';
import '../../widgets/ui/app_feedback.dart';

/// "Project Signed" submission window: attach supporting photos/documents,
/// add a note, and submit for management approval. Images are compressed
/// before upload. The lead only becomes Signed once management approves.
class SignedProjectDialog extends StatefulWidget {
  final String leadId;

  const SignedProjectDialog({super.key, required this.leadId});

  @override
  State<SignedProjectDialog> createState() => _SignedProjectDialogState();
}

class _PickedFile {
  final Uint8List bytes;
  final String name;
  const _PickedFile({required this.bytes, required this.name});
}

class _SignedProjectDialogState extends State<SignedProjectDialog> {
  static const _maxFiles = 6;

  final _noteCtrl = TextEditingController();
  final List<_PickedFile> _files = [];
  bool _submitting = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool _isImage(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
  }

  String _jpegName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return '$base.jpg';
  }

  Future<void> _pickFiles() async {
    if (_submitting) return;
    final remaining = _maxFiles - _files.length;
    if (remaining <= 0) {
      AppFeedback.warning(context, 'Maximum $_maxFiles files allowed');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files
        .where((f) => f.bytes != null && f.name.trim().isNotEmpty)
        .take(remaining)
        .map((f) => _PickedFile(bytes: f.bytes!, name: f.name))
        .toList();
    if (picked.isEmpty) return;
    setState(() => _files.addAll(picked));
  }

  Future<({Uint8List bytes, String name})> _prepare(_PickedFile file) async {
    if (_isImage(file.name)) {
      final compressed = await ImageCompressor.compressTo1Mb(file.bytes);
      return (bytes: compressed, name: _jpegName(file.name));
    }
    if (file.bytes.length > ImageCompressor.maxBytes1Mb) {
      throw Exception('${file.name} exceeds 1 MB. Use a smaller file.');
    }
    return (bytes: file.bytes, name: file.name);
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final urls = <String>[];
      for (final file in _files) {
        final prepared = await _prepare(file);
        final doc = await LandLeadLegalService.uploadDocument(
          leadId: widget.leadId,
          bytes: prepared.bytes,
          fileName: prepared.name,
        );
        urls.add(doc.fileUrl);
      }
      await LandLeadSignedService.submit(
        leadId: widget.leadId,
        note: _noteCtrl.text,
        photoUrls: urls,
      );
      if (!mounted) return;
      AppFeedback.success(
        context,
        'Submitted for management approval. The lead becomes Signed once approved.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      AppFeedback.error(
          context, 'Could not submit: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: context.fomraSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 640),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: LeadStatus.signed.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.draw_outlined,
                        color: LeadStatus.signed.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Project Signed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                        Text(
                          'Lead #${widget.leadId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Attach the signed agreement photos/documents and submit for '
                'management approval. The lead becomes Signed only after approval.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.fomraTextSecondary,
                ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _submitting ? null : _pickFiles,
                        icon: const Icon(Icons.upload_file_outlined, size: 18),
                        label: Text(
                          _files.isEmpty
                              ? 'Upload documents / photos'
                              : 'Add more (${_files.length}/$_maxFiles)',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.purple,
                          side: BorderSide(color: context.fomraBorder),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'PDF, JPG, PNG, DOC · images auto-compress before upload',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                      if (_files.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        for (var i = 0; i < _files.length; i++)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              border: Border.all(color: context.fomraBorder),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isImage(_files[i].name)
                                      ? Icons.image_outlined
                                      : Icons.description_outlined,
                                  size: 18,
                                  color: AppColors.purple,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _files[i].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.fomraTextPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _submitting
                                      ? null
                                      : () =>
                                          setState(() => _files.removeAt(i)),
                                  icon: const Icon(Icons.close_rounded,
                                      size: 18),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteCtrl,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 500,
                        decoration: InputDecoration(
                          labelText: 'Note (optional)',
                          alignLabelWithHint: true,
                          filled: true,
                          fillColor:
                              context.fomraSurfaceVar.withValues(alpha: 0.55),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.fomraBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.fomraBorder),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.draw_outlined, size: 18),
                    label: Text(_submitting ? 'Submitting…' : 'Project Signed'),
                    style: FilledButton.styleFrom(
                      backgroundColor: LeadStatus.signed.color,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
