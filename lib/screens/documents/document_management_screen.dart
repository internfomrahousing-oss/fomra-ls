import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/land_lead.dart';
import '../../models/land_lead_legal_document.dart';
import '../../services/app_store.dart';
import '../../services/auth_service.dart';
import '../../services/document_index_service.dart';
import '../../services/role_access.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../utils/legal_document_catalog.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/app_loader.dart';
import '../land_lead/lead_detail_screen.dart';

/// Central repository for Patta, Chitta, FMB, EC, Sale Deed, Survey Reports.
class DocumentManagementScreen extends StatefulWidget {
  const DocumentManagementScreen({super.key});

  @override
  State<DocumentManagementScreen> createState() =>
      _DocumentManagementScreenState();
}

class _DocumentManagementScreenState extends State<DocumentManagementScreen> {
  bool _loading = true;
  String? _error;
  String _query = '';
  List<LandLeadLegalDocument> _docs = const [];
  final Set<String> _expandedLeads = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool force = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs =
          await DocumentIndexService.instance.ensureLoaded(force: force);
      if (!mounted) return;
      setState(() {
        _docs = _scoped(docs);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<LandLeadLegalDocument> _scoped(List<LandLeadLegalDocument> docs) {
    if (AuthService.instance.isManagement) return docs;
    final me =
        (AuthService.instance.currentUser?.fullName ?? '').trim().toLowerCase();
    if (me.isEmpty) return docs;
    final myLeadIds = AppStore.instance.leads
        .where((l) => l.createdByName.trim().toLowerCase() == me)
        .map((l) => l.leadId)
        .toSet();
    return docs.where((d) => myLeadIds.contains(d.leadId)).toList();
  }

  List<LandLeadLegalDocument> get _filtered {
    final list = _docs;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((d) {
      final num = LegalDocumentCatalog.extractDocumentNumber(d.fileName);
      return d.fileName.toLowerCase().contains(q) ||
          d.leadId.toLowerCase().contains(q) ||
          (num != null && num.toLowerCase().contains(q)) ||
          d.loggedByName.toLowerCase().contains(q);
    }).toList();
  }

  LandLead? _leadFor(String leadId) {
    return AppStore.instance.leads.where((l) => l.leadId == leadId).firstOrNull;
  }

  Future<void> _preview(LandLeadLegalDocument doc) async {
    final lower = doc.fileName.toLowerCase();
    final isOffice = lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.pptx');
    // Office files can't render inline in a browser, so route them through the
    // Microsoft Office web viewer. PDFs/images open directly in a new tab.
    final target = isOffice
        ? 'https://view.officeapps.live.com/op/view.aspx?src=${Uri.encodeComponent(doc.fileUrl)}'
        : doc.fileUrl;
    final uri = Uri.tryParse(target);
    if (uri == null) return;
    await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
  }

  Future<void> _download(LandLeadLegalDocument doc) async {
    final uri = Uri.tryParse(doc.fileUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showVersions(LandLeadLegalDocument doc) {
    final versions = DocumentIndexService.instance.versionsFor(doc);
    final cat = LegalDocumentCatalog.classify(doc.fileName);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.fomraSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Version history · ${cat.label}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.fomraTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lead #${doc.leadId} · ${versions.length} version(s)',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.fomraTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: versions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = versions[i];
                      final stamp = DateFormat('dd MMM yyyy, h:mm a')
                          .format(v.verifiedAt.toLocal());
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          v.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            stamp,
                            if (v.loggedByName.isNotEmpty) v.loggedByName,
                            if (i == 0) 'Latest',
                          ].join(' · '),
                        ),
                        trailing: IconButton(
                          tooltip: 'Preview',
                          icon: const Icon(Icons.visibility_outlined),
                          onPressed: () => _preview(v),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = FomraLayout.pagePadding(context);
    final body = RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView(
        padding: pad,
        children: [
          Text(
            'Document Management',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Central repository for Patta, Chitta, FMB, EC, Sale Deed, and Survey Reports. Preview, download, and review version history.',
            style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Role: ${RoleAccess.currentRole.label}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search by file, lead ID, or document number',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: context.fomraSurfaceVar,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: AppLoader.center(message: 'Loading documents…'),
            )
          else if (_error != null)
            EmptyState(
              title: 'Could not load documents',
              message: _error,
              icon: Icons.error_outline_rounded,
            )
          else if (_filtered.isEmpty)
            const EmptyState(
              title: 'No documents found',
              message: 'Uploaded documents will appear here.',
              icon: Icons.folder_open_outlined,
            )
          else
            ..._buildLeadGroups(),
        ],
      ),
    );

    return FomraAppShell(
      currentRoute: '/document-management',
      appBar: const FomraAppBar(moduleName: 'Documents'),
      body: body,
    );
  }

  /// Group the filtered documents by lead so the page shows a lead number
  /// first; tapping a lead expands to reveal all its documents (Patta, Chitta…).
  List<Widget> _buildLeadGroups() {
    final byLead = <String, List<LandLeadLegalDocument>>{};
    for (final d in _filtered) {
      (byLead[d.leadId] ??= []).add(d);
    }
    final leadIds = byLead.keys.toList()..sort((a, b) => a.compareTo(b));
    return [for (final id in leadIds) _leadGroupCard(id, byLead[id]!)];
  }

  Widget _leadGroupCard(String leadId, List<LandLeadLegalDocument> docs) {
    final expanded = _expandedLeads.contains(leadId);
    final lead = _leadFor(leadId);
    final cats = <String>[
      for (final label in {
        for (final d in docs) LegalDocumentCatalog.classify(d.fileName).label,
      })
        label,
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            padding: const EdgeInsets.all(12),
            onTap: () => setState(() {
              if (expanded) {
                _expandedLeads.remove(leadId);
              } else {
                _expandedLeads.add(leadId);
              }
            }),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.folder_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lead #$leadId',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: context.fomraTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (lead != null && lead.ownerName.isNotEmpty)
                            lead.ownerName,
                          '${docs.length} document${docs.length == 1 ? '' : 's'}',
                          if (cats.isNotEmpty) cats.join(', '),
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: context.fomraTextSecondary,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final d in docs) _docTile(d)],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _docTile(LandLeadLegalDocument doc) {
    final cat = LegalDocumentCatalog.classify(doc.fileName);
    final lead = _leadFor(doc.leadId);
    final stamp =
        DateFormat('dd MMM yyyy').format(doc.verifiedAt.toLocal());
    final num = LegalDocumentCatalog.extractDocumentNumber(doc.fileName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    cat.label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  stamp,
                  style: TextStyle(
                    fontSize: 10,
                    color: context.fomraTextSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              doc.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.fomraTextPrimary,
              ),
            ),
            if (num != null || doc.loggedByName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                [
                  if (num != null) 'Doc #$num',
                  if (doc.loggedByName.isNotEmpty) doc.loggedByName,
                ].join(' · '),
                style: TextStyle(
                  fontSize: 11,
                  color: context.fomraTextSecondary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _docAction(Icons.visibility_outlined, 'Preview',
                    () => _preview(doc)),
                _docAction(Icons.download_outlined, 'Download',
                    () => _download(doc)),
                _docAction(Icons.history_rounded, 'Versions',
                    () => _showVersions(doc)),
                if (lead != null)
                  _docAction(Icons.open_in_new_rounded, 'Open lead', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LeadDetailScreen(lead: lead),
                      ),
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _docAction(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(0, 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
