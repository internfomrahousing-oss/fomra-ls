import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/land_lead_legal_document.dart';
import '../../services/land_lead_legal_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../utils/image_compressor.dart';
import '../../widgets/separate_date_time_fields.dart';

class LegalDocumentsDialog extends StatefulWidget {
  final String leadId;

  const LegalDocumentsDialog({super.key, required this.leadId});

  @override
  State<LegalDocumentsDialog> createState() => _LegalDocumentsDialogState();
}

class _LegalDocumentsDialogState extends State<LegalDocumentsDialog> {
  static const _maxDocuments = 4;

  final _notesCtrl = TextEditingController();
  bool _loading = true;
  bool _uploading = false;
  bool _savingNotes = false;
  List<LandLeadLegalDocument> _documents = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        LandLeadLegalService.getDocuments(widget.leadId),
        LandLeadLegalService.getReferenceNotes(widget.leadId),
      ]);
      if (!mounted) return;
      setState(() {
        _documents = results[0] as List<LandLeadLegalDocument>;
        _notesCtrl.text = results[1] as String;
      });
    } catch (_) {
      // Tables may not exist yet.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _fieldDecoration(BuildContext context, String label,
      {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: true,
      filled: true,
      fillColor: context.fomraSurfaceVar.withValues(alpha: 0.55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.fomraBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: context.fomraBorder),
      ),
    );
  }

  int get _remainingSlots => _maxDocuments - _documents.length;

  bool _isImageFile(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png');
  }

  String _jpegFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    return '$base.jpg';
  }

  Future<({Uint8List bytes, String fileName})> _prepareUploadBytes(
    Uint8List bytes,
    String fileName,
  ) async {
    if (_isImageFile(fileName)) {
      final compressed = await ImageCompressor.compressTo1Mb(bytes);
      return (bytes: compressed, fileName: _jpegFileName(fileName));
    }
    if (bytes.length > ImageCompressor.maxBytes1Mb) {
      throw Exception(
        '$fileName exceeds 1 MB. Use a smaller file or upload as JPG/PNG.',
      );
    }
    return (bytes: bytes, fileName: fileName);
  }

  Future<void> _uploadDocument() async {
    if (_uploading) return;
    if (_remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum $_maxDocuments documents allowed')),
      );
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
        .take(_remainingSlots)
        .toList();
    if (picked.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read selected file(s)')),
        );
      }
      return;
    }
    if (result.files.length > _remainingSlots && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Only $_remainingSlots more file${_remainingSlots == 1 ? '' : 's'} allowed (max $_maxDocuments)',
          ),
        ),
      );
    }

    setState(() => _uploading = true);
    var uploaded = 0;
    try {
      for (final file in picked) {
        if (!mounted || _documents.length >= _maxDocuments) break;
        final prepared = await _prepareUploadBytes(file.bytes!, file.name);
        final doc = await LandLeadLegalService.uploadDocument(
          leadId: widget.leadId,
          bytes: prepared.bytes,
          fileName: prepared.fileName,
        );
        if (!mounted) return;
        setState(() => _documents = [doc, ..._documents]);
        uploaded++;
      }
      if (mounted && uploaded > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uploaded == 1
                  ? 'Uploaded 1 document'
                  : 'Uploaded $uploaded documents',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uploaded > 0
                  ? 'Uploaded $uploaded file(s); then failed: $e'
                  : 'Upload failed: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveNotes() async {
    if (_savingNotes) return;
    setState(() => _savingNotes = true);
    try {
      await LandLeadLegalService.saveReferenceNotes(
        widget.leadId,
        _notesCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reference notes saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save notes: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNotes = false);
    }
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: context.fomraSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
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
                      color: AppColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.gavel_outlined,
                      color: AppColors.purple,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legal',
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
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Upload legal verified documents and keep reference notes',
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
                        onPressed:
                            (_uploading || _remainingSlots <= 0)
                                ? null
                                : _uploadDocument,
                        icon: _uploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file_outlined, size: 18),
                        label: Text(
                          _uploading
                              ? 'Uploading…'
                              : _remainingSlots <= 0
                                  ? 'Maximum $_maxDocuments documents uploaded'
                                  : 'Upload legal document',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.purple,
                          side: BorderSide(color: context.fomraBorder),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_documents.length}/$_maxDocuments uploaded · PDF, JPG, PNG, DOC · images auto-compress to 1 MB',
                        style: TextStyle(
                          fontSize: 11,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else if (_documents.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Verified documents',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final doc in _documents)
                          _DocumentTile(
                            document: doc,
                            onOpen: () => _openDocument(doc.fileUrl),
                          ),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: _notesCtrl,
                        minLines: 4,
                        maxLines: 6,
                        maxLength: 500,
                        decoration: _fieldDecoration(
                          context,
                          'Reference notes',
                          hint: 'Add notes for legal reference…',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _savingNotes ? null : _saveNotes,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                    ),
                    child: _savingNotes
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Notes'),
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

class _DocumentTile extends StatelessWidget {
  final LandLeadLegalDocument document;
  final VoidCallback onOpen;

  const _DocumentTile({
    required this.document,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: context.fomraBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.verified_outlined,
              size: 18,
              color: AppColors.purple,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.fomraTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Verified ${formatCallDateTime(document.verifiedAt)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.fomraTextSecondary,
                  ),
                ),
                if (document.loggedByName.isNotEmpty)
                  Text(
                    document.loggedByName,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.fomraTextSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new, size: 18),
            tooltip: 'Open document',
            color: AppColors.purple,
          ),
        ],
      ),
    );
  }
}
