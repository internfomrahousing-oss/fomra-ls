import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../analytics/management_bi_metrics.dart';
import '../models/employee_profile.dart';
import '../models/land_lead.dart';
import '../models/land_lead_legal_document.dart';
import '../models/land_lead_site_visit.dart';
import '../utils/contact_directory.dart';
import 'csv_saver_stub.dart'
    if (dart.library.html) 'csv_saver_web.dart'
    if (dart.library.io) 'csv_saver_io.dart';
import 'land_lead_legal_service.dart';
import 'management_bi_activity_service.dart';
import 'pdf_saver_stub.dart'
    if (dart.library.html) 'pdf_saver_web.dart'
    if (dart.library.io) 'pdf_saver_io.dart';

enum ReportFormat { pdf, excel }

class ReportPreviewSection {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final String emptyMessage;

  const ReportPreviewSection({
    required this.title,
    required this.headers,
    required this.rows,
    this.emptyMessage = 'No data.',
  });

  int get count => rows.length;
}

class ReportPreviewData {
  final DateTime generatedAt;
  final List<({String label, String value})> summary;
  final List<ReportPreviewSection> sections;

  const ReportPreviewData({
    required this.generatedAt,
    required this.summary,
    required this.sections,
  });
}

/// One-click report catalog covering all product report types.
enum ReportKind {
  daily,
  weekly,
  monthly,
  employee,
  district,
  village,
  broker,
  owner,
  conversion,
  siteAgeing,
  pendingApproval,
  siteVisit,
  survey,
  legal,
  document,
  acquisitionSummary,
  pipeline,
}

extension ReportKindX on ReportKind {
  String get label => switch (this) {
        ReportKind.daily => 'Daily Report',
        ReportKind.weekly => 'Weekly Report',
        ReportKind.monthly => 'Monthly Report',
        ReportKind.employee => 'Employee Report',
        ReportKind.district => 'District Report',
        ReportKind.village => 'Village Report',
        ReportKind.broker => 'Broker Report',
        ReportKind.owner => 'Owner Report',
        ReportKind.conversion => 'Conversion Report',
        ReportKind.siteAgeing => 'Site Ageing Report',
        ReportKind.pendingApproval => 'Pending Approval Report',
        ReportKind.siteVisit => 'Site Visit Report',
        ReportKind.survey => 'Survey Report',
        ReportKind.legal => 'Legal Report',
        ReportKind.document => 'Document Report',
        ReportKind.acquisitionSummary => 'Acquisition Summary',
        ReportKind.pipeline => 'Pipeline Report',
      };

  String get description => switch (this) {
        ReportKind.daily => 'Sites added today',
        ReportKind.weekly => 'Activity across the current week',
        ReportKind.monthly => 'Month-to-date pipeline snapshot',
        ReportKind.employee => 'Performance by executive',
        ReportKind.district => 'Sites grouped by district',
        ReportKind.village => 'Sites grouped by village',
        ReportKind.broker => 'Broker directory and linked sites',
        ReportKind.owner => 'Owner directory and linked sites',
        ReportKind.conversion => 'Acquisition and conversion rates',
        ReportKind.siteAgeing => 'Age buckets across the pipeline',
        ReportKind.pendingApproval => 'Visits awaiting management approval',
        ReportKind.siteVisit => 'All logged site visits',
        ReportKind.survey => 'Survey numbers and pending surveys',
        ReportKind.legal => 'Legal verification and document progress',
        ReportKind.document => 'Uploaded legal document inventory',
        ReportKind.acquisitionSummary => 'Fleet-wide acquisition snapshot',
        ReportKind.pipeline => 'Current pipeline by stage',
      };

  String get fileStem => switch (this) {
        ReportKind.daily => 'Daily',
        ReportKind.weekly => 'Weekly',
        ReportKind.monthly => 'Monthly',
        ReportKind.employee => 'Employee',
        ReportKind.district => 'District',
        ReportKind.village => 'Village',
        ReportKind.broker => 'Broker',
        ReportKind.owner => 'Owner',
        ReportKind.conversion => 'Conversion',
        ReportKind.siteAgeing => 'Site_Ageing',
        ReportKind.pendingApproval => 'Pending_Approvals',
        ReportKind.siteVisit => 'Site_Visits',
        ReportKind.survey => 'Survey',
        ReportKind.legal => 'Legal',
        ReportKind.document => 'Documents',
        ReportKind.acquisitionSummary => 'Acquisition_Summary',
        ReportKind.pipeline => 'Pipeline',
      };
}

/// Caps PDF table rows to keep generation responsive on large datasets.
const int kReportPdfRowCap = 1500;

class ReportCatalogService {
  static final _date = DateFormat('dd MMM yyyy');
  static final _stamp = DateFormat('dd MMM yyyy, h:mm a');

  static const _brand = PdfColor.fromInt(0xFF1D4ED8);
  static const _ink = PdfColor.fromInt(0xFF1A1A1A);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _border = PdfColor.fromInt(0xFFE5E7EB);
  static const _zebra = PdfColor.fromInt(0xFFF3F4F6);
  static const _tileBg = PdfColor.fromInt(0xFFF8FAFC);

  /// One-click export for a catalog report.
  static Future<void> exportOneClick({
    required ReportKind kind,
    required List<LandLead> leads,
    List<EmployeeProfile> employees = const [],
    ReportFormat format = ReportFormat.pdf,
    String? employeeName,
  }) async {
    final preview = await buildLivePreview(
      kind: kind,
      leads: leads,
      employees: employees,
      employeeName: employeeName,
      capForPdf: format == ReportFormat.pdf,
    );
    final fileName =
        'FomraLS_${kind.fileStem}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}'
        '.${format == ReportFormat.excel ? 'csv' : 'pdf'}';

    if (format == ReportFormat.excel) {
      final bytes = _excelFromPreview(preview);
      await saveCsv(bytes, fileName);
      return;
    }

    final bytes = await _buildPdf(preview, kind.label);
    await savePdf(bytes, fileName);
  }

  /// Builds a preview, loading site-visit activity / legal documents when
  /// the report needs them.
  static Future<ReportPreviewData> buildLivePreview({
    required ReportKind kind,
    required List<LandLead> leads,
    List<EmployeeProfile> employees = const [],
    String? employeeName,
    bool capForPdf = true,
  }) async {
    final activity = await _loadActivityIfNeeded(kind);
    final legalDocs = await _loadLegalDocsIfNeeded(kind);
    return buildPreview(
      kind: kind,
      leads: leads,
      employees: employees,
      employeeName: employeeName,
      siteVisits: activity.siteVisits,
      legalDocs: legalDocs,
      capForPdf: capForPdf,
    );
  }

  static Future<ManagementBiActivityBundle> _loadActivityIfNeeded(
    ReportKind kind,
  ) async {
    if (kind == ReportKind.siteVisit ||
        kind == ReportKind.pendingApproval ||
        kind == ReportKind.siteAgeing) {
      return ManagementBiActivityService.loadAll();
    }
    return ManagementBiActivityBundle.empty;
  }

  static Future<List<LandLeadLegalDocument>> _loadLegalDocsIfNeeded(
    ReportKind kind,
  ) async {
    if (kind != ReportKind.legal && kind != ReportKind.document) return const [];
    try {
      return await LandLeadLegalService.getAllDocuments();
    } catch (_) {
      return const [];
    }
  }

  static ReportPreviewData buildPreview({
    required ReportKind kind,
    required List<LandLead> leads,
    List<EmployeeProfile> employees = const [],
    String? employeeName,
    List<LandLeadSiteVisit> siteVisits = const [],
    List<LandLeadLegalDocument> legalDocs = const [],
    bool capForPdf = true,
  }) {
    final scoped = _periodFilter(leads, kind);
    final cap = capForPdf;
    return switch (kind) {
      ReportKind.daily ||
      ReportKind.weekly ||
      ReportKind.monthly =>
        _periodLeadsPreview(kind, scoped, cap: cap),
      ReportKind.employee =>
        _employeePreview(scoped, employees, employeeName, cap: cap),
      ReportKind.district => _districtPreview(scoped, cap: cap),
      ReportKind.village => _villagePreview(scoped, cap: cap),
      ReportKind.broker =>
        _directoryPreview(scoped, ContactDirectoryKind.broker, cap: cap),
      ReportKind.owner =>
        _directoryPreview(scoped, ContactDirectoryKind.owner, cap: cap),
      ReportKind.conversion => _conversionPreview(scoped),
      ReportKind.siteAgeing => _ageingPreview(scoped, cap: cap),
      ReportKind.pendingApproval =>
        _pendingApprovalPreview(scoped, siteVisits, cap: cap),
      ReportKind.siteVisit =>
        _siteVisitPreview(scoped, siteVisits, cap: cap),
      ReportKind.survey => _surveyPreview(scoped, cap: cap),
      ReportKind.legal => _legalPreview(scoped, legalDocs, cap: cap),
      ReportKind.document => _documentPreview(scoped, legalDocs, cap: cap),
      ReportKind.acquisitionSummary => _acquisitionSummaryPreview(scoped),
      ReportKind.pipeline => _pipelinePreview(scoped, cap: cap),
    };
  }

  static List<LandLead> _periodFilter(List<LandLead> leads, ReportKind kind) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTime? start = switch (kind) {
      ReportKind.daily => today,
      ReportKind.weekly =>
        today.subtract(Duration(days: today.weekday - 1)),
      ReportKind.monthly => DateTime(now.year, now.month, 1),
      _ => null,
    };
    if (start == null) return leads;
    return leads.where((l) {
      final d = l.addedOn.toLocal();
      return !d.isBefore(start);
    }).toList();
  }

  static ReportPreviewData _periodLeadsPreview(
    ReportKind kind,
    List<LandLead> leads, {
    required bool cap,
  }) {
    final acquired = leads.where((l) => l.status.isAcquired).length;
    final active = leads.where((l) => l.status.isActive).length;
    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'Period leads', value: '${leads.length}'),
        (label: 'Active', value: '$active'),
        (label: 'Acquired', value: '$acquired'),
      ],
      sections: [
        ReportPreviewSection(
          title: kind.label,
          headers: _leadHeaders(),
          rows: _maybeCap(_leadRows(leads), cap),
          emptyMessage: 'No leads in this period.',
        ),
      ],
    );
  }

  static ReportPreviewData _employeePreview(
    List<LandLead> leads,
    List<EmployeeProfile> employees,
    String? employeeName, {
    required bool cap,
  }) {
    final requested = employeeName?.trim() ?? '';
    if (requested.isNotEmpty && requested.toLowerCase() != 'all') {
      final mine = leads
          .where((l) =>
              l.createdByName.trim().toLowerCase() == requested.toLowerCase())
          .toList();
      return ReportPreviewData(
        generatedAt: DateTime.now(),
        summary: [
          (label: 'Employee', value: requested),
          (label: 'Leads', value: '${mine.length}'),
          (
            label: 'Acquired',
            value: '${mine.where((l) => l.status.isAcquired).length}'
          ),
        ],
        sections: [
          ReportPreviewSection(
            title: 'Employee Leads · $requested',
            headers: _leadHeaders(),
            rows: _maybeCap(_leadRows(mine), cap),
            emptyMessage: 'No leads for $requested.',
          ),
        ],
      );
    }

    final names = <String>{
      ...employees.map((e) => e.fullName.trim()).where((n) => n.isNotEmpty),
      ...leads.map((l) => l.createdByName.trim()).where((n) => n.isNotEmpty),
    };
    final rows = names.map((name) {
      final mine = leads
          .where((l) =>
              l.createdByName.trim().toLowerCase() == name.toLowerCase())
          .toList();
      final acquired = mine.where((l) => l.status.isAcquired).length;
      final rate =
          mine.isEmpty ? 0 : ((acquired / mine.length) * 100).round();
      return [
        name,
        '${mine.length}',
        '$acquired',
        '${mine.where((l) => l.status.isActive).length}',
        '$rate%',
      ];
    }).toList()
      ..sort((a, b) => int.parse(b[1]).compareTo(int.parse(a[1])));

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'Employees', value: '${rows.length}'),
        (label: 'Total leads', value: '${leads.length}'),
      ],
      sections: [
        ReportPreviewSection(
          title: 'Employee Performance',
          headers: const [
            'Employee',
            'Total',
            'Acquired',
            'Active',
            'Conversion',
          ],
          rows: _maybeCap(rows, cap),
          emptyMessage: 'No employee activity.',
        ),
      ],
    );
  }

  static ReportPreviewData _districtPreview(
    List<LandLead> leads, {
    required bool cap,
  }) {
    final map = <String, List<LandLead>>{};
    for (final l in leads) {
      final d =
          l.district.trim().isEmpty ? '(Unspecified)' : l.district.trim();
      (map[d] ??= []).add(l);
    }
    final rows = map.entries.map((e) {
      final acquired = e.value.where((l) => l.status.isAcquired).length;
      final villages = e.value.map((l) => l.village.trim()).where((v) => v.isNotEmpty).toSet();
      final acres = e.value.fold<double>(0, (s, l) => s + biLeadAcres(l));
      return [
        e.key,
        '${villages.length}',
        '${e.value.length}',
        '$acquired',
        acres.toStringAsFixed(1),
      ];
    }).toList()
      ..sort((a, b) => int.parse(b[2]).compareTo(int.parse(a[2])));

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'Districts', value: '${rows.length}'),
        (label: 'Sites', value: '${leads.length}'),
      ],
      sections: [
        ReportPreviewSection(
          title: 'District Report',
          headers: const ['District', 'Villages', 'Sites', 'Acquired', 'Acres'],
          rows: _maybeCap(rows, cap),
          emptyMessage: 'No district data.',
        ),
      ],
    );
  }

  static ReportPreviewData _villagePreview(
    List<LandLead> leads, {
    required bool cap,
  }) {
    final map = <String, List<LandLead>>{};
    for (final l in leads) {
      final v = l.village.trim().isEmpty ? '(Unspecified)' : l.village.trim();
      (map[v] ??= []).add(l);
    }
    final rows = map.entries.map((e) {
      final acquired = e.value.where((l) => l.status.isAcquired).length;
      final acres =
          e.value.fold<double>(0, (s, l) => s + biLeadAcres(l));
      return [
        e.key,
        e.value.first.district.trim().isEmpty
            ? '-'
            : e.value.first.district.trim(),
        '${e.value.length}',
        '$acquired',
        acres.toStringAsFixed(1),
      ];
    }).toList()
      ..sort((a, b) => int.parse(b[2]).compareTo(int.parse(a[2])));

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'Villages', value: '${rows.length}'),
        (label: 'Leads', value: '${leads.length}'),
      ],
      sections: [
        ReportPreviewSection(
          title: 'Village Reports',
          headers: const [
            'Village',
            'District',
            'Leads',
            'Acquired',
            'Acres',
          ],
          rows: _maybeCap(rows, cap),
          emptyMessage: 'No village data.',
        ),
      ],
    );
  }

  static ReportPreviewData _directoryPreview(
    List<LandLead> leads,
    ContactDirectoryKind kind, {
    required bool cap,
  }) {
    final entries = buildContactDirectoryEntries(leads, kind);
    final isOwner = kind == ContactDirectoryKind.owner;
    final rows = entries
        .map(
          (e) => [
            e.name,
            e.contact.isEmpty ? '-' : e.contact,
            '${e.leads.length}',
            '${e.leads.where((l) => l.status.isAcquired).length}',
            e.leads.map((l) => l.leadId).join(', '),
          ],
        )
        .toList();

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: isOwner ? 'Owners' : 'Brokers', value: '${entries.length}'),
        (label: 'Linked leads', value: '${leads.length}'),
      ],
      sections: [
        ReportPreviewSection(
          title: isOwner ? 'Owner Reports' : 'Broker Reports',
          headers: const [
            'Name',
            'Contact',
            'Leads',
            'Acquired',
            'Lead IDs',
          ],
          rows: _maybeCap(rows, cap),
          emptyMessage: isOwner ? 'No owners found.' : 'No brokers found.',
        ),
      ],
    );
  }

  static ReportPreviewData _conversionPreview(List<LandLead> leads) {
    final total = leads.length;
    final acquired = leads.where((l) => l.status.isAcquired).length;
    final dropped = leads.where((l) => l.status.isDropped).length;
    final active = leads.where((l) => l.status.isActive).length;
    final rate = total == 0 ? 0 : ((acquired / total) * 100).round();

    final bySource = <String, List<LandLead>>{};
    for (final l in leads) {
      (bySource[l.inputSource.label] ??= []).add(l);
    }
    final sourceRows = bySource.entries.map((e) {
      final a = e.value.where((l) => l.status.isAcquired).length;
      final r =
          e.value.isEmpty ? 0 : ((a / e.value.length) * 100).round();
      return [e.key, '${e.value.length}', '$a', '$r%'];
    }).toList();

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'Total', value: '$total'),
        (label: 'Acquired', value: '$acquired'),
        (label: 'Conversion', value: '$rate%'),
        (label: 'Active', value: '$active'),
        (label: 'Dropped', value: '$dropped'),
      ],
      sections: [
        ReportPreviewSection(
          title: 'Conversion by Source',
          headers: const ['Source', 'Leads', 'Acquired', 'Rate'],
          rows: sourceRows,
          emptyMessage: 'No conversion data.',
        ),
      ],
    );
  }

  static ReportPreviewData _ageingPreview(
    List<LandLead> leads, {
    required bool cap,
  }) {
    final now = DateTime.now();
    final buckets = <BiAgeBucket, List<LandLead>>{
      for (final b in BiAgeBucket.values) b: <LandLead>[],
    };
    for (final l in leads.where((l) => l.status.isActive)) {
      final age = biLeadAgeDays(l, now);
      buckets[BiAgeBucketX.forAgeDays(age)]!.add(l);
    }
    final summaryRows = [
      for (final b in BiAgeBucket.values) [b.label, '${buckets[b]!.length}'],
    ];
    final detail = buckets.values.expand((list) => list).toList();
    final detailRows = detail
        .map(
          (l) => [
            l.leadId,
            l.ownerName,
            l.status.label,
            '${biLeadAgeDays(l, now)}',
            l.createdByName.isEmpty ? '-' : l.createdByName,
          ],
        )
        .toList();

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'Active sites', value: '${detail.length}'),
        (
          label: BiAgeBucket.d90plus.label,
          value: '${buckets[BiAgeBucket.d90plus]!.length}'
        ),
      ],
      sections: [
        ReportPreviewSection(
          title: 'Age Buckets',
          headers: const ['Bucket', 'Count'],
          rows: summaryRows,
        ),
        ReportPreviewSection(
          title: 'Active Sites by Age',
          headers: const [
            'Site ID',
            'Owner',
            'Status',
            'Age (days)',
            'Executive',
          ],
          rows: _maybeCap(detailRows, cap),
          emptyMessage: 'No active sites.',
        ),
      ],
    );
  }

  static ReportPreviewData _pendingApprovalPreview(
    List<LandLead> leads,
    List<LandLeadSiteVisit> visits, {
    required bool cap,
  }) {
    final pending = visits
        .where((v) => v.approvalStatus == SiteVisitApprovalStatus.pending)
        .toList();
    final leadMap = {for (final l in leads) l.leadId: l};
    final rows = pending
        .map((v) {
          final lead = leadMap[v.leadId];
          return [
            v.leadId,
            lead?.ownerName ?? '-',
            v.visitType.label,
            v.loggedByName.isEmpty ? '-' : v.loggedByName,
            _date.format(v.visitedAt),
            '${DateTime.now().difference(v.visitedAt).inDays}d',
          ];
        })
        .toList();

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'Pending approvals', value: '${pending.length}'),
      ],
      sections: [
        ReportPreviewSection(
          title: 'Pending Approval Reports',
          headers: const [
            'Lead ID',
            'Owner',
            'Visit type',
            'Logged by',
            'Visited',
            'Waiting',
          ],
          rows: _maybeCap(rows, cap),
          emptyMessage: 'No pending approvals.',
        ),
      ],
    );
  }

  static ReportPreviewData _surveyPreview(
    List<LandLead> leads, {
    required bool cap,
  }) {
    final withSurvey =
        leads.where((l) => l.surveyNumber.trim().isNotEmpty).toList();
    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'With survey #', value: '${withSurvey.length}'),
      ],
      sections: [
        ReportPreviewSection(
          title: 'Survey Completed',
          headers: const [
            'Lead ID',
            'Owner',
            'Survey #',
            'Sub-division',
            'Village',
            'Status',
          ],
          rows: _maybeCap(
            withSurvey
                .map((l) => [
                      l.leadId,
                      l.ownerName,
                      l.surveyNumber,
                      l.subDivision.isEmpty ? '-' : l.subDivision,
                      l.village.isEmpty ? '-' : l.village,
                      l.status.label,
                    ])
                .toList(),
            cap,
          ),
          emptyMessage: 'No surveyed leads.',
        ),
      ],
    );
  }

  static ReportPreviewData _siteVisitPreview(
    List<LandLead> leads,
    List<LandLeadSiteVisit> visits, {
    required bool cap,
  }) {
    final leadMap = {for (final l in leads) l.leadId: l};
    final rows = visits
        .map((v) {
          final lead = leadMap[v.leadId];
          return [
            v.leadId,
            lead?.ownerName ?? '-',
            v.visitType.label,
            v.approvalStatus.label,
            v.loggedByName.isEmpty ? '-' : v.loggedByName,
            _date.format(v.visitedAt),
          ];
        })
        .toList();

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'Site visits', value: '${visits.length}'),
        (
          label: 'Pending',
          value:
              '${visits.where((v) => v.approvalStatus == SiteVisitApprovalStatus.pending).length}'
        ),
      ],
      sections: [
        ReportPreviewSection(
          title: 'Site Visit Reports',
          headers: const [
            'Lead ID',
            'Owner',
            'Type',
            'Approval',
            'Logged by',
            'Date',
          ],
          rows: _maybeCap(rows, cap),
          emptyMessage: 'No site visits logged.',
        ),
      ],
    );
  }

  static ReportPreviewData _legalPreview(
    List<LandLead> leads,
    List<LandLeadLegalDocument> legalDocs, {
    required bool cap,
  }) {
    final docsByLead = <String, List<LandLeadLegalDocument>>{};
    for (final d in legalDocs) {
      (docsByLead[d.leadId] ??= []).add(d);
    }
    final relevant = leads
        .where((l) =>
            l.status == LeadStatus.negotiation ||
            l.status == LeadStatus.legal ||
            l.status == LeadStatus.signed)
        .toList();
    final rows = relevant.map((l) {
      final docs = docsByLead[l.leadId] ?? const [];
      return [
        l.leadId,
        l.ownerName.trim().isEmpty ? '-' : l.ownerName,
        l.status.label,
        l.surveyNumber.trim().isEmpty ? 'Missing' : 'On file',
        '${docs.length}',
      ];
    }).toList();
    final withDocs = relevant.where((l) => (docsByLead[l.leadId] ?? const []).isNotEmpty).length;

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'In legal pipeline', value: '${relevant.length}'),
        (label: 'With documents', value: '$withDocs'),
      ],
      sections: [
        ReportPreviewSection(
          title: 'Legal Report',
          headers: const [
            'Site ID',
            'Owner',
            'Stage',
            'Survey Number',
            'Documents Uploaded',
          ],
          rows: _maybeCap(rows, cap),
          emptyMessage: 'No sites in the legal pipeline.',
        ),
      ],
    );
  }

  static ReportPreviewData _documentPreview(
    List<LandLead> leads,
    List<LandLeadLegalDocument> legalDocs, {
    required bool cap,
  }) {
    final leadIds = leads.map((l) => l.leadId).toSet();
    final scoped = legalDocs.where((d) => leadIds.contains(d.leadId)).toList()
      ..sort((a, b) => b.verifiedAt.compareTo(a.verifiedAt));
    final rows = scoped
        .map((d) => [
              d.leadId,
              d.fileName,
              _date.format(d.verifiedAt),
              d.loggedByName.isEmpty ? '-' : d.loggedByName,
            ])
        .toList();

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'Documents', value: '${scoped.length}'),
        (
          label: 'Sites covered',
          value: '${scoped.map((d) => d.leadId).toSet().length}'
        ),
      ],
      sections: [
        ReportPreviewSection(
          title: 'Document Report',
          headers: const ['Site ID', 'File Name', 'Verified', 'Uploaded By'],
          rows: _maybeCap(rows, cap),
          emptyMessage: 'No documents uploaded.',
        ),
      ],
    );
  }

  static ReportPreviewData _acquisitionSummaryPreview(List<LandLead> leads) {
    final total = leads.length;
    final signed = leads.where((l) => l.status == LeadStatus.signed).toList();
    final active = leads.where((l) => l.status.isActive).toList();
    final dropped = leads.where((l) => l.status.isDropped).toList();
    final totalAcres = leads.fold<double>(0, (s, l) => s + biLeadAcres(l));
    final signedAcres = signed.fold<double>(0, (s, l) => s + biLeadAcres(l));

    final stageRows = [
      for (final status in leadStatusPipelineOrder)
        [
          status.label,
          '${leads.where((l) => l.status == status).length}',
          leads
              .where((l) => l.status == status)
              .fold<double>(0, (s, l) => s + biLeadAcres(l))
              .toStringAsFixed(1),
        ],
    ];

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'Total sites', value: '$total'),
        (label: 'Total acres', value: totalAcres.toStringAsFixed(1)),
        (label: 'Signed', value: '${signed.length}'),
        (label: 'Signed acres', value: signedAcres.toStringAsFixed(1)),
        (label: 'Active', value: '${active.length}'),
        (label: 'Dropped', value: '${dropped.length}'),
      ],
      sections: [
        ReportPreviewSection(
          title: 'Acquisition Summary',
          headers: const ['Stage', 'Sites', 'Acres'],
          rows: stageRows,
          emptyMessage: 'No acquisition data.',
        ),
      ],
    );
  }

  static ReportPreviewData _pipelinePreview(
    List<LandLead> leads, {
    required bool cap,
  }) {
    final now = DateTime.now();
    final active = leads.where((l) => l.status.isActive).toList()
      ..sort((a, b) => leadStatusPipelineOrder
          .indexOf(a.status)
          .compareTo(leadStatusPipelineOrder.indexOf(b.status)));
    final rows = active
        .map((l) => [
              l.leadId,
              l.ownerName.trim().isEmpty ? '-' : l.ownerName,
              l.status.label,
              biLeadAcres(l).toStringAsFixed(1),
              '${biLeadAgeDays(l, now)}',
              l.createdByName.trim().isEmpty ? '-' : l.createdByName,
            ])
        .toList();

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'In pipeline', value: '${active.length}'),
        (
          label: 'Pipeline acres',
          value: active.fold<double>(0, (s, l) => s + biLeadAcres(l)).toStringAsFixed(1)
        ),
      ],
      sections: [
        ReportPreviewSection(
          title: 'Pipeline Report',
          headers: const [
            'Site ID',
            'Owner',
            'Stage',
            'Acres',
            'Age (days)',
            'Executive',
          ],
          rows: _maybeCap(rows, cap),
          emptyMessage: 'No sites in the pipeline.',
        ),
      ],
    );
  }

  static List<String> _leadHeaders() => const [
        'Lead ID',
        'Owner',
        'Location',
        'Village',
        'Type',
        'Source',
        'Status',
        'Added By',
        'Date',
      ];

  static List<String> _leadRow(LandLead l) => [
        l.leadId,
        l.ownerName.trim().isEmpty ? '-' : l.ownerName,
        l.location.trim().isEmpty ? '-' : l.location,
        l.village.trim().isEmpty ? '-' : l.village,
        l.landType.label,
        l.inputSource.label,
        l.status.label,
        l.createdByName.trim().isEmpty ? '-' : l.createdByName,
        _date.format(l.addedOn),
      ];

  static List<List<String>> _leadRows(List<LandLead> leads) =>
      leads.map(_leadRow).toList();

  static List<List<String>> _maybeCap(List<List<String>> rows, bool cap) {
    if (!cap || rows.length <= kReportPdfRowCap) return rows;
    return [
      ...rows.take(kReportPdfRowCap),
      List.filled(
        rows.first.length,
        '… truncated ${rows.length - kReportPdfRowCap} more rows (export Excel for full set)',
      ),
    ];
  }

  // ── Excel ────────────────────────────────────────────────────────────────

  static Uint8List _excelFromPreview(ReportPreviewData preview) {
    final buffer = StringBuffer();
    buffer.writeln('Fomra Housing & Infrastructure Pvt. Ltd.');
    buffer.writeln('Generated,${_csv(_stamp.format(preview.generatedAt))}');
    buffer.writeln();
    buffer.writeln(
      preview.summary.map((s) => '${_csv(s.label)},${_csv(s.value)}').join(','),
    );
    buffer.writeln();
    for (final section in preview.sections) {
      buffer.writeln('${_csv(section.title)} (${section.count})');
      buffer.writeln(section.headers.map(_csv).join(','));
      if (section.rows.isEmpty) {
        buffer.writeln(_csv(section.emptyMessage));
      } else {
        for (final row in section.rows) {
          buffer.writeln(row.map(_csv).join(','));
        }
      }
      buffer.writeln();
    }
    final body = utf8.encode(buffer.toString());
    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...body]);
  }

  static String _csv(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');
    final escaped = value.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  // ── PDF ──────────────────────────────────────────────────────────────────

  static Future<Uint8List> _buildPdf(
    ReportPreviewData preview,
    String title,
  ) async {
    final doc = pw.Document(
      title: 'FomraLS $title',
      author: 'Fomra Housing & Infrastructure Pvt. Ltd.',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        maxPages: 80,
        footer: (ctx) => pw.Text(
          'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: _muted),
          textAlign: pw.TextAlign.right,
        ),
        build: (ctx) => [
          pw.Text(
            'Fomra Housing & Infrastructure Pvt. Ltd.',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _brand,
            ),
          ),
          pw.Text(title,
              style: pw.TextStyle(fontSize: 12, color: _ink)),
          pw.Text(
            'Generated ${_stamp.format(preview.generatedAt)}',
            style: pw.TextStyle(fontSize: 9, color: _muted),
          ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: preview.summary
                .map(
                  (s) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: pw.BoxDecoration(
                      color: _tileBg,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: _border),
                    ),
                    child: pw.Text(
                      '${s.label}: ${s.value}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          pw.SizedBox(height: 16),
          for (final section in preview.sections) ...[
            pw.Text(
              '${section.title} (${section.count})',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.SizedBox(height: 6),
            if (section.rows.isEmpty)
              pw.Text(
                section.emptyMessage,
                style: pw.TextStyle(fontSize: 10, color: _muted),
              )
            else
              _table(section),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _table(ReportPreviewSection section) {
    return pw.TableHelper.fromTextArray(
      headers: section.headers,
      data: section.rows,
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: _ink,
      ),
      cellStyle: pw.TextStyle(fontSize: 7.5, color: _ink),
      headerDecoration: const pw.BoxDecoration(color: _tileBg),
      oddRowDecoration: const pw.BoxDecoration(color: _zebra),
      border: pw.TableBorder.all(color: _border, width: 0.4),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    );
  }
}
