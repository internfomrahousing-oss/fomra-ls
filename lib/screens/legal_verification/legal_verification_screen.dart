import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';

const int _maxBytes = 1024 * 1024;

const List<String> _docTypes = [
  'Sale Deed',
  'Parent Documents',
  'Power of Attorney',
  'Approval Documents',
];

const Map<String, IconData> _docIcons = {
  'Sale Deed':         Icons.home_work_outlined,
  'Parent Documents':  Icons.folder_open_outlined,
  'Power of Attorney': Icons.assignment_ind_outlined,
  'Approval Documents': Icons.approval_outlined,
};

class _DocFile {
  final String name;
  final int size;
  final Uint8List bytes;
  _DocFile({required this.name, required this.size, required this.bytes});
}

// ── Main Screen ───────────────────────────────────────────────────────────────

class LegalVerificationScreen extends StatefulWidget {
  const LegalVerificationScreen({super.key});

  @override
  State<LegalVerificationScreen> createState() =>
      _LegalVerificationScreenState();
}

class _LegalVerificationScreenState extends State<LegalVerificationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // leadId → { docType → _DocFile? }
  final Map<String, Map<String, _DocFile?>> _leadDocs = {};

  // Legal Review — checks
  final _ownershipCtrl       = TextEditingController();
  String _mortgageAnswer     = '';
  final _mortgageReasonCtrl  = TextEditingController();
  String _courtAnswer        = '';
  final _courtReasonCtrl     = TextEditingController();
  String _govtRiskAnswer     = '';
  final _govtRiskReasonCtrl  = TextEditingController();
  final _titleChainCtrl      = TextEditingController();
  final _encumbrancesCtrl    = TextEditingController();
  final _docValidityCtrl     = TextEditingController();

  // Legal Result
  String _legalResult              = '';
  final _legalResultNotesCtrl      = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    AppStore.instance.addListener(_onStoreUpdate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    AppStore.instance.removeListener(_onStoreUpdate);
    _ownershipCtrl.dispose();
    _mortgageReasonCtrl.dispose();
    _courtReasonCtrl.dispose();
    _govtRiskReasonCtrl.dispose();
    _titleChainCtrl.dispose();
    _encumbrancesCtrl.dispose();
    _docValidityCtrl.dispose();
    _legalResultNotesCtrl.dispose();
    super.dispose();
  }

  void _onStoreUpdate() => setState(() {});

  List<LandLead> get _siteVerifiedLeads => AppStore.instance.leads
      .where((l) => l.status.index >= LeadStatus.siteVisit.index)
      .toList();

  Map<String, _DocFile?> _docsFor(String leadId) =>
      _leadDocs[leadId] ?? {for (final t in _docTypes) t: null};

  void _openUpload(LandLead lead) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UploadSheet(
        lead: lead,
        docs: Map.from(_docsFor(lead.leadId)),
        onSave: (updated) {
          setState(() => _leadDocs[lead.leadId] = updated);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FomraAppBar(moduleName: 'Legal Verification'),
      drawer: const AppDrawer(currentRoute: '/legal-verification'),
      bottomNavigationBar:
          const FomraBottomNav(currentRoute: '/legal-verification'),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FieldExecutiveTab(
                  leads: _siteVerifiedLeads,
                  allLeadsCount: AppStore.instance.leads.length,
                  docsFor: _docsFor,
                  onUpload: _openUpload,
                ),
                _LegalReviewTab(
                  ownershipCtrl:        _ownershipCtrl,
                  mortgageAnswer:       _mortgageAnswer,
                  mortgageReasonCtrl:   _mortgageReasonCtrl,
                  onMortgageChanged:    (v) => setState(() => _mortgageAnswer = v),
                  courtAnswer:          _courtAnswer,
                  courtReasonCtrl:      _courtReasonCtrl,
                  onCourtChanged:       (v) => setState(() => _courtAnswer = v),
                  govtRiskAnswer:       _govtRiskAnswer,
                  govtRiskReasonCtrl:   _govtRiskReasonCtrl,
                  onGovtRiskChanged:    (v) => setState(() => _govtRiskAnswer = v),
                  titleChainCtrl:       _titleChainCtrl,
                  encumbrancesCtrl:     _encumbrancesCtrl,
                  docValidityCtrl:      _docValidityCtrl,
                  legalResult:          _legalResult,
                  legalResultNotesCtrl: _legalResultNotesCtrl,
                  onResultChanged:      (v) => setState(() => _legalResult = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() => Container(
        color: AppColors.primary,
        child: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(icon: Icon(Icons.person_pin_outlined, size: 18),
                text: 'Field Executive'),
            Tab(icon: Icon(Icons.gavel_outlined, size: 18),
                text: 'Legal Review'),
          ],
        ),
      );
}

// ── Field Executive Tab ───────────────────────────────────────────────────────

class _FieldExecutiveTab extends StatelessWidget {
  final List<LandLead> leads;
  final int allLeadsCount;
  final Map<String, _DocFile?> Function(String leadId) docsFor;
  final void Function(LandLead) onUpload;

  const _FieldExecutiveTab({
    required this.leads,
    required this.allLeadsCount,
    required this.docsFor,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    if (leads.isEmpty) return _emptyState();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: leads.length,
      itemBuilder: (_, i) => _LeadDocCard(
        lead: leads[i],
        docs: docsFor(leads[i].leadId),
        onUpload: () => onUpload(leads[i]),
      ),
    );
  }

  Widget _emptyState() {
    final hasLeads = allLeadsCount > 0;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.upload_file_outlined,
              size: 38, color: AppColors.primary.withValues(alpha: 0.4)),
        ),
        const SizedBox(height: 16),
        Text(
          hasLeads
              ? 'No leads have completed site verification'
              : 'No leads found',
          style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          hasLeads
              ? 'Complete site verification first to upload documents here.'
              : 'Add leads in Land Lead Management, then complete site verification.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ]),
    );
  }
}

class _LeadDocCard extends StatelessWidget {
  final LandLead lead;
  final Map<String, _DocFile?> docs;
  final VoidCallback onUpload;

  const _LeadDocCard({
    required this.lead,
    required this.docs,
    required this.onUpload,
  });

  int get _uploaded => docs.values.where((f) => f != null).length;
  bool get _complete => _uploaded == _docTypes.length;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder_special_outlined,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lead.ownerName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold)),
                    Text(
                      '${lead.leadId}  •  ${lead.location}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (_complete
                        ? AppColors.success
                        : _uploaded > 0
                            ? AppColors.warning
                            : Colors.grey.shade400)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _complete
                    ? 'Complete'
                    : _uploaded > 0
                        ? 'Partial'
                        : 'Pending',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _complete
                      ? AppColors.success
                      : _uploaded > 0
                          ? AppColors.warning
                          : Colors.grey.shade500,
                ),
              ),
            ),
          ]),

          // Doc rows
          if (_uploaded > 0) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ..._docTypes.map((type) {
              final file = docs[type];
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [
                  Icon(
                    _docIcons[type] ?? Icons.description_outlined,
                    size: 14,
                    color: file != null
                        ? AppColors.success
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(type,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: file != null
                              ? AppColors.textPrimary
                              : Colors.grey.shade400,
                        )),
                  ),
                  if (file != null) ...[
                    Text(file.name,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(width: 4),
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 13),
                  ] else
                    const Text('Pending',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600)),
                ]),
              );
            }),
          ],

          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file_outlined, size: 16),
              label: Text(
                _uploaded == 0 ? 'Upload Documents' : 'Update Documents',
                style: const TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Upload Documents Bottom Sheet ─────────────────────────────────────────────

class _UploadSheet extends StatefulWidget {
  final LandLead lead;
  final Map<String, _DocFile?> docs;
  final void Function(Map<String, _DocFile?>) onSave;

  const _UploadSheet({
    required this.lead,
    required this.docs,
    required this.onSave,
  });

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  late final Map<String, _DocFile?> _docs;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _docs = Map.from(widget.docs);
  }

  Future<void> _pick(String docType) async {
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (!mounted) return;
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      if (file.size > _maxBytes) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${file.name}" exceeds 1 MB limit.'),
          backgroundColor: AppColors.error,
        ));
        return;
      }
      setState(() => _docs[docType] =
          _DocFile(name: file.name, size: file.size, bytes: file.bytes!));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _save() {
    widget.onSave(Map.from(_docs));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              const Icon(Icons.upload_file_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Upload Documents',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(
                        '${widget.lead.ownerName}  •  ${widget.lead.leadId}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ]),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'PDF / JPG / PNG — max 1 MB each',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                ..._docTypes.map(_docRow),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _picking ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _docRow(String type) {
    final file = _docs[type];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: file != null
            ? AppColors.success.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: file != null
              ? AppColors.success.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: file != null ? 1.5 : 1,
        ),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: (file != null ? AppColors.success : AppColors.primary)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _docIcons[type] ?? Icons.description_outlined,
            color:
                file != null ? AppColors.success : AppColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (file != null)
                  Text(
                    '${file.name}  •  ${(file.size / 1024).toStringAsFixed(0)} KB',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  const Text('No file',
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
              ]),
        ),
        if (file != null) ...[
          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => setState(() => _docs[type] = null),
            child: const Icon(Icons.close, color: AppColors.error, size: 18),
          ),
        ] else
          TextButton.icon(
            onPressed: _picking ? null : () => _pick(type),
            icon: const Icon(Icons.upload, size: 15),
            label: const Text('Upload', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
      ]),
    );
  }
}

// ── Legal Review Tab ──────────────────────────────────────────────────────────

class _LegalReviewTab extends StatelessWidget {
  final TextEditingController ownershipCtrl;
  final String mortgageAnswer;
  final TextEditingController mortgageReasonCtrl;
  final void Function(String) onMortgageChanged;
  final String courtAnswer;
  final TextEditingController courtReasonCtrl;
  final void Function(String) onCourtChanged;
  final String govtRiskAnswer;
  final TextEditingController govtRiskReasonCtrl;
  final void Function(String) onGovtRiskChanged;
  final TextEditingController titleChainCtrl;
  final TextEditingController encumbrancesCtrl;
  final TextEditingController docValidityCtrl;
  final String legalResult;
  final TextEditingController legalResultNotesCtrl;
  final void Function(String) onResultChanged;

  const _LegalReviewTab({
    required this.ownershipCtrl,
    required this.mortgageAnswer,
    required this.mortgageReasonCtrl,
    required this.onMortgageChanged,
    required this.courtAnswer,
    required this.courtReasonCtrl,
    required this.onCourtChanged,
    required this.govtRiskAnswer,
    required this.govtRiskReasonCtrl,
    required this.onGovtRiskChanged,
    required this.titleChainCtrl,
    required this.encumbrancesCtrl,
    required this.docValidityCtrl,
    required this.legalResult,
    required this.legalResultNotesCtrl,
    required this.onResultChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionHeader('Check', Icons.fact_check_outlined),
        const SizedBox(height: 14),

        _fillField('Ownership', ownershipCtrl,
            hint: 'Enter ownership details'),
        const SizedBox(height: 10),

        _yesNoField(
          label: 'Mortgage',
          answer: mortgageAnswer,
          reasonCtrl: mortgageReasonCtrl,
          onChanged: onMortgageChanged,
        ),
        const SizedBox(height: 10),

        _yesNoField(
          label: 'Court Cases',
          answer: courtAnswer,
          reasonCtrl: courtReasonCtrl,
          onChanged: onCourtChanged,
        ),
        const SizedBox(height: 10),

        _yesNoField(
          label: 'Government Acquisition Risk',
          answer: govtRiskAnswer,
          reasonCtrl: govtRiskReasonCtrl,
          onChanged: onGovtRiskChanged,
        ),
        const SizedBox(height: 10),

        _fillField('Title Chain', titleChainCtrl,
            hint: 'Describe title chain details'),
        const SizedBox(height: 10),

        _fillField('Encumbrances', encumbrancesCtrl,
            hint: 'List any encumbrances'),
        const SizedBox(height: 10),

        _fillField('Document Validity', docValidityCtrl,
            hint: 'Describe document validity'),
        const SizedBox(height: 24),

        _sectionHeader('Legal Result', Icons.verified_outlined),
        const SizedBox(height: 14),
        _resultPicker(),
        const SizedBox(height: 40),
      ]),
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold)),
      ]);

  Widget _fillField(String label, TextEditingController ctrl,
      {String hint = ''}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ]);

  Widget _yesNoField({
    required String label,
    required String answer,
    required TextEditingController reasonCtrl,
    required void Function(String) onChanged,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(children: [
            _yesNoChip('Yes', answer == 'Yes',
                const Color(0xFFDC2626), onChanged),
            const SizedBox(width: 8),
            _yesNoChip(
                'No', answer == 'No', AppColors.success, onChanged),
          ]),
          if (answer == 'Yes') ...[
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Enter reason...',
                hintStyle: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                filled: true,
                fillColor: Colors.white,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ]),
      );

  Widget _yesNoChip(String label, bool selected, Color color,
          void Function(String) onTap) =>
      GestureDetector(
        onTap: () => onTap(selected ? '' : label),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          decoration: BoxDecoration(
            color:
                selected ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : AppColors.textSecondary)),
        ),
      );

  Widget _resultPicker() {
    const results = [
      ('CLEAR',       Color(0xFF16A34A), Icons.check_circle_outline),
      ('OBSERVATION', Color(0xFFD97706), Icons.remove_red_eye_outlined),
      ('HIGH RISK',   Color(0xFFDC2626), Icons.warning_amber_outlined),
      ('REJECT',      Color(0xFF7C3AED), Icons.cancel_outlined),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: results.map((r) {
          final (label, color, icon) = r;
          final selected = legalResult == label;
          return GestureDetector(
            onTap: () => onResultChanged(selected ? '' : label),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? color.withValues(alpha: 0.1)
                    : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? color : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon,
                    color: selected ? color : Colors.grey.shade400,
                    size: 18),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: selected ? color : AppColors.textSecondary)),
              ]),
            ),
          );
        }).toList(),
      ),
      if (legalResult.isNotEmpty) ...[
        const SizedBox(height: 14),
        TextField(
          controller: legalResultNotesCtrl,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            labelText: 'Notes / Remarks',
            labelStyle: const TextStyle(fontSize: 13),
            hintText: 'Enter detailed remarks for this result...',
            hintStyle: const TextStyle(
                fontSize: 12, color: AppColors.textSecondary),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.primary, width: 1.5)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    ]);
  }
}
