import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';

const int _maxBytes = 1024 * 1024; // 1 MB

const List<String> _docTypes = [
  'Sale Deed',
  'Parent Documents',
  'Power of Attorney',
  'Approval Documents',
];

class _DocFile {
  final String name;
  final int size;
  final Uint8List bytes;
  _DocFile({required this.name, required this.size, required this.bytes});
}

class LegalVerificationScreen extends StatefulWidget {
  const LegalVerificationScreen({super.key});

  @override
  State<LegalVerificationScreen> createState() =>
      _LegalVerificationScreenState();
}

class _LegalVerificationScreenState extends State<LegalVerificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // docType → uploaded file (null = not yet uploaded)
  final Map<String, _DocFile?> _docs = {
    for (final t in _docTypes) t: null,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _pick(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if ((file.size) > _maxBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '"${file.name}" is ${(file.size / 1024).toStringAsFixed(0)} KB — max allowed is 1 MB.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() {
      _docs[docType] = _DocFile(
        name: file.name,
        size: file.size,
        bytes: file.bytes!,
      );
    });
  }

  void _remove(String docType) => setState(() => _docs[docType] = null);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FomraAppBar(moduleName: 'Legal Verification'),
      drawer: const AppDrawer(currentRoute: '/legal-verification'),
      bottomNavigationBar:
          const FomraBottomNav(currentRoute: '/legal-verification'),
      body: Column(
        children: [
          _TabBar(controller: _tabController),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FieldExecutiveTab(
                  docs: _docs,
                  onPick: _pick,
                  onRemove: _remove,
                ),
                _LegalTeamTab(docs: _docs),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab bar ───────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.primary,
        child: TabBar(
          controller: controller,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.person_pin_outlined), text: 'Field Executive'),
            Tab(icon: Icon(Icons.gavel_outlined), text: 'Legal Team'),
          ],
        ),
      );
}

// ── Field Executive tab ───────────────────────────────────────────────────────

class _FieldExecutiveTab extends StatelessWidget {
  final Map<String, _DocFile?> docs;
  final void Function(String) onPick;
  final void Function(String) onRemove;

  const _FieldExecutiveTab({
    required this.docs,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            icon: Icons.upload_file_outlined,
            title: 'Document Upload',
            subtitle: 'Attach property documents (PDF / JPG / PNG, max 1 MB each)',
          ),
          const SizedBox(height: 16),
          ...docs.keys.map(
            (type) => _UploadRow(
              docType: type,
              file: docs[type],
              onPick: () => onPick(type),
              onRemove: () => onRemove(type),
            ),
          ),
          const SizedBox(height: 24),
          _SubmitBanner(docs: docs),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SectionHeader(
      {required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      );
}

class _UploadRow extends StatelessWidget {
  final String docType;
  final _DocFile? file;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _UploadRow({
    required this.docType,
    required this.file,
    required this.onPick,
    required this.onRemove,
  });

  static const Map<String, IconData> _icons = {
    'Sale Deed': Icons.home_work_outlined,
    'Parent Documents': Icons.folder_open_outlined,
    'Power of Attorney': Icons.assignment_ind_outlined,
    'Approval Documents': Icons.approval_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final uploaded = file != null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: uploaded ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: uploaded ? AppColors.success : Colors.grey.shade300,
          width: uploaded ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (uploaded ? AppColors.success : AppColors.primary)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _icons[docType] ?? Icons.description_outlined,
                color: uploaded ? AppColors.success : AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(docType,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  if (uploaded)
                    Text(
                      '${file!.name}  •  ${(file!.size / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    )
                  else
                    const Text('No file uploaded',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (uploaded)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.success, size: 18),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.error, size: 18),
                    tooltip: 'Remove',
                    onPressed: onRemove,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              )
            else
              TextButton.icon(
                onPressed: onPick,
                icon: const Icon(Icons.upload, size: 16),
                label: const Text('Upload'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubmitBanner extends StatelessWidget {
  final Map<String, _DocFile?> docs;
  const _SubmitBanner({required this.docs});

  @override
  Widget build(BuildContext context) {
    final uploadedCount = docs.values.where((f) => f != null).length;
    final total = docs.length;
    if (uploadedCount == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            uploadedCount == total
                ? Icons.check_circle_outline
                : Icons.info_outline,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              uploadedCount == total
                  ? 'All $total documents uploaded — Legal Team can now review.'
                  : '$uploadedCount of $total documents uploaded. Upload remaining files for complete review.',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Legal Team tab ────────────────────────────────────────────────────────────

class _LegalTeamTab extends StatelessWidget {
  final Map<String, _DocFile?> docs;
  const _LegalTeamTab({required this.docs});

  @override
  Widget build(BuildContext context) {
    final uploaded = docs.entries.where((e) => e.value != null).toList();
    final missing = docs.entries.where((e) => e.value == null).toList();

    if (uploaded.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.folder_open_outlined,
                  size: 38,
                  color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            const SizedBox(height: 16),
            const Text('No documents uploaded yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            const Text('Field Executive must upload documents first.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.gavel_outlined,
            title: 'Document Review',
            subtitle:
                '${uploaded.length} of ${docs.length} documents received',
          ),
          const SizedBox(height: 16),
          ...uploaded.map((e) => _ReviewCard(docType: e.key, file: e.value!)),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Awaiting from Field Executive',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary.withValues(alpha: 0.7))),
            const SizedBox(height: 8),
            ...missing.map((e) => _MissingDocRow(docType: e.key)),
          ],
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final String docType;
  final _DocFile file;
  const _ReviewCard({required this.docType, required this.file});

  static const Map<String, IconData> _icons = {
    'Sale Deed': Icons.home_work_outlined,
    'Parent Documents': Icons.folder_open_outlined,
    'Power of Attorney': Icons.assignment_ind_outlined,
    'Approval Documents': Icons.approval_outlined,
  };

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
              color: AppColors.success.withValues(alpha: 0.4), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _icons[docType] ?? Icons.description_outlined,
                  color: AppColors.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(docType,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      '${file.name}  •  ${(file.size / 1024).toStringAsFixed(1)} KB',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 20),
            ],
          ),
        ),
      );
}

class _MissingDocRow extends StatelessWidget {
  final String docType;
  const _MissingDocRow({required this.docType});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_empty_outlined,
                size: 16, color: Colors.grey.shade400),
            const SizedBox(width: 10),
            Text(docType,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade500)),
            const Spacer(),
            const Text('Pending',
                style: TextStyle(
                    fontSize: 11,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
