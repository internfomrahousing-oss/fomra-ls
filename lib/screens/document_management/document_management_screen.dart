import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';

enum DocType { titleDeed, encumbrance, mutation, khata, survey, agreement, other }
enum DocStatus { pending, uploaded, verified, rejected }

class Document {
  final String id;
  final String name;
  final DocType type;
  final DocStatus status;
  final DateTime uploadedOn;
  final String relatedTo;
  final String fileSize;

  Document({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.uploadedOn,
    required this.relatedTo,
    required this.fileSize,
  });
}

class DocumentManagementScreen extends StatefulWidget {
  const DocumentManagementScreen({super.key});

  @override
  State<DocumentManagementScreen> createState() =>
      _DocumentManagementScreenState();
}

class _DocumentManagementScreenState
    extends State<DocumentManagementScreen> {
  final List<Document> _documents = [];
  DocType? _selectedType;
  String _searchQuery = '';

  List<Document> get _filtered => _documents.where((d) {
        final matchesType =
            _selectedType == null || d.type == _selectedType;
        final matchesSearch = _searchQuery.isEmpty ||
            d.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            d.relatedTo.toLowerCase().contains(_searchQuery.toLowerCase());
        return matchesType && matchesSearch;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FomraAppBar(
        moduleName: 'Documents',
        actions: [
          if (_documents.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showTypeFilter),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/document-management'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/document-management'),
      body: Column(
        children: [
          if (_documents.isNotEmpty)
            _SearchBar(onChanged: (q) => setState(() => _searchQuery = q)),
          if (_documents.isNotEmpty) _DocSummary(documents: _documents),
          if (_selectedType != null)
            Container(
              color: AppColors.primary.withValues(alpha: 0.08),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(children: [
                Text('Filtered: ${_docTypeLabel(_selectedType!)}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500)),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _selectedType = null),
                  child: const Icon(Icons.close,
                      size: 16, color: AppColors.primary),
                ),
              ]),
            ),
          Expanded(
            child: _filtered.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _DocCard(doc: _filtered[i]),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  void _upload() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload document — coming soon')),
    );
  }

  void _showTypeFilter() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Filter by Document Type',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ListTile(
              title: const Text('All Types'),
              leading: const Icon(Icons.folder),
              onTap: () {
                setState(() => _selectedType = null);
                Navigator.pop(context);
              }),
          ...DocType.values.map((t) => ListTile(
                title: Text(_docTypeLabel(t)),
                leading:
                    Icon(_docTypeIcon(t), color: AppColors.primary),
                onTap: () {
                  setState(() => _selectedType = t);
                  Navigator.pop(context);
                },
              )),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.folder_open_outlined,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          const Text(
              'No documents uploaded yet.\nTap Upload to add your first document.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: FontWeight.w500)),
        ]),
      );
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search documents...',
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.15),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

class _DocSummary extends StatelessWidget {
  final List<Document> documents;
  const _DocSummary({required this.documents});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFF0F4F8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: DocStatus.values.map((s) {
          final count = documents.where((d) => d.status == s).length;
          final color = _statusColor(s);
          return Column(children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(_statusLabel(s),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]);
        }).toList(),
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final Document doc;
  const _DocCard({required this.doc});

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(doc.type);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(_docTypeIcon(doc.type), color: typeColor, size: 22),
        ),
        title: Text(doc.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
                '${doc.relatedTo}  •  ${doc.fileSize}  •  ${doc.uploadedOn.day}/${doc.uploadedOn.month}/${doc.uploadedOn.year}',
                style: const TextStyle(fontSize: 11)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: _statusColor(doc.status),
                    shape: BoxShape.circle)),
            const SizedBox(height: 4),
            Text(_statusLabel(doc.status),
                style: TextStyle(
                    fontSize: 10,
                    color: _statusColor(doc.status),
                    fontWeight: FontWeight.w600)),
          ],
        ),
        onTap: () {},
      ),
    );
  }
}

Color _typeColor(DocType t) => switch (t) {
      DocType.titleDeed => AppColors.primary,
      DocType.encumbrance => AppColors.info,
      DocType.mutation => const Color(0xFF8B5CF6),
      DocType.khata => AppColors.warning,
      DocType.survey => AppColors.success,
      DocType.agreement => const Color(0xFFEC4899),
      DocType.other => AppColors.textSecondary,
    };

IconData _docTypeIcon(DocType t) => switch (t) {
      DocType.titleDeed => Icons.home_work_outlined,
      DocType.encumbrance => Icons.account_balance_outlined,
      DocType.mutation => Icons.swap_horiz,
      DocType.khata => Icons.receipt_long_outlined,
      DocType.survey => Icons.map_outlined,
      DocType.agreement => Icons.handshake_outlined,
      DocType.other => Icons.insert_drive_file_outlined,
    };

String _docTypeLabel(DocType t) => switch (t) {
      DocType.titleDeed => 'Title Deed',
      DocType.encumbrance => 'Encumbrance',
      DocType.mutation => 'Mutation',
      DocType.khata => 'Khata',
      DocType.survey => 'Survey',
      DocType.agreement => 'Agreement',
      DocType.other => 'Other',
    };

Color _statusColor(DocStatus s) => switch (s) {
      DocStatus.pending => AppColors.textSecondary,
      DocStatus.uploaded => AppColors.info,
      DocStatus.verified => AppColors.success,
      DocStatus.rejected => AppColors.error,
    };

String _statusLabel(DocStatus s) => switch (s) {
      DocStatus.pending => 'Pending',
      DocStatus.uploaded => 'Uploaded',
      DocStatus.verified => 'Verified',
      DocStatus.rejected => 'Rejected',
    };
