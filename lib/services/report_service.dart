import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/employee_profile.dart';
import '../models/land_lead.dart';
import '../utils/contact_directory.dart';
import 'csv_saver_stub.dart'
    if (dart.library.html) 'csv_saver_web.dart'
    if (dart.library.io) 'csv_saver_io.dart';
import 'pdf_saver_stub.dart'
    if (dart.library.html) 'pdf_saver_web.dart'
    if (dart.library.io) 'pdf_saver_io.dart';

enum LeadReportType {
  all,
  totalLeads,
  acquiredLeads,
  brokerLeads,
  employeeLeads,
}

enum OtherReportType {
  ownerReports,
  brokerReports,
}

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

/// Builds and downloads a PDF report covering all leads, acquired leads,
/// broker leads, and each employee's lead performance.
class ReportService {
  static final _date = DateFormat('dd MMM yyyy');
  static final _stamp = DateFormat('dd MMM yyyy, h:mm a');

  static const _brand = PdfColor.fromInt(0xFF1D4ED8);
  static const _ink = PdfColor.fromInt(0xFF1A1A1A);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _border = PdfColor.fromInt(0xFFE5E7EB);
  static const _zebra = PdfColor.fromInt(0xFFF3F4F6);
  static const _tileBg = PdfColor.fromInt(0xFFF8FAFC);

  static bool _isActive(LandLead l) => l.status.isActive;

  /// Generate the report and hand it to the OS/browser share/download sheet.
  static Future<void> generateLeadsReport(
    List<LandLead> leads, {
    List<EmployeeProfile> employees = const [],
    LeadReportType reportType = LeadReportType.all,
    OtherReportType? otherReportType,
    String? employeeName,
    ReportFormat format = ReportFormat.pdf,
  }) async {
    if (otherReportType != null) {
      final fileName = reportFileName(
        otherReportType: otherReportType,
        format: format,
      );
      if (format == ReportFormat.excel) {
        final bytes = buildOtherExcelReport(
          leads,
          otherReportType: otherReportType,
        );
        await saveCsv(bytes, fileName);
        return;
      }
      final bytes = await _buildOtherPdfReport(
        leads,
        otherReportType: otherReportType,
      );
      await savePdf(bytes, fileName);
      return;
    }

    final fileName = reportFileName(
      reportType: reportType,
      employeeName: employeeName,
      format: format,
    );
    if (format == ReportFormat.excel) {
      final bytes = buildExcelReport(
        leads,
        employees: employees,
        reportType: reportType,
        employeeName: employeeName,
      );
      await saveCsv(bytes, fileName);
      return;
    }

    final bytes = await _buildPdfReport(
      leads,
      employees: employees,
      reportType: reportType,
      employeeName: employeeName,
    );
    await savePdf(bytes, fileName);
  }

  /// Structured preview of the report before export.
  static ReportPreviewData buildPreview(
    List<LandLead> leads, {
    List<EmployeeProfile> employees = const [],
    LeadReportType reportType = LeadReportType.all,
    OtherReportType? otherReportType,
    String? employeeName,
  }) {
    if (otherReportType != null) {
      return _buildOtherPreview(leads, otherReportType: otherReportType);
    }

    final acquired =
        leads.where((l) => l.status.isAcquired).toList();
    final broker =
        leads.where((l) => l.inputSource == InputSource.broker).toList();
    final active = leads.where(_isActive).length;
    final rejected = leads.where((l) => l.status.isDropped).length;
    final perf = _employeePerformance(leads, employees);

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (label: 'Total leads', value: '${leads.length}'),
        (label: 'Acquired', value: '${acquired.length}'),
        (label: 'Broker leads', value: '${broker.length}'),
        (label: 'Active', value: '$active'),
        (label: 'Rejected', value: '$rejected'),
      ],
      sections: _previewSections(
        leads: leads,
        acquired: acquired,
        broker: broker,
        perf: perf,
        reportType: reportType,
        employeeName: employeeName,
      ),
    );
  }

  static Uint8List buildExcelReport(
    List<LandLead> leads, {
    List<EmployeeProfile> employees = const [],
    LeadReportType reportType = LeadReportType.all,
    OtherReportType? otherReportType,
    String? employeeName,
  }) {
    final preview = buildPreview(
      leads,
      employees: employees,
      reportType: reportType,
      otherReportType: otherReportType,
      employeeName: employeeName,
    );
    final buffer = StringBuffer();
    buffer.writeln('Fomra Housing & Infrastructure Pvt. Ltd.');
    buffer.writeln('Land Acquisition Report');
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

  /// The download file name for a given report selection.
  static String reportFileName({
    LeadReportType reportType = LeadReportType.all,
    OtherReportType? otherReportType,
    String? employeeName,
    ReportFormat format = ReportFormat.pdf,
  }) {
    final suffix = otherReportType != null
        ? switch (otherReportType) {
            OtherReportType.ownerReports => 'Owner_Reports',
            OtherReportType.brokerReports => 'Broker_Reports',
          }
        : switch (reportType) {
            LeadReportType.all => 'Lead_Based_All',
            LeadReportType.totalLeads => 'Total_Leads',
            LeadReportType.acquiredLeads => 'Acquired_Leads',
            LeadReportType.brokerLeads => 'Broker_Leads',
            LeadReportType.employeeLeads =>
              employeeName == null || employeeName.trim().isEmpty
                  ? 'Employee_Leads_All'
                  : 'Employee_${_fileSafe(employeeName)}',
          };
    final ext = format == ReportFormat.excel ? 'csv' : 'pdf';
    return 'FomraLS_Report_${suffix}_'
        '${DateFormat('yyyyMMdd').format(DateTime.now())}.$ext';
  }

  static Future<Uint8List> _buildPdfReport(
    List<LandLead> leads, {
    List<EmployeeProfile> employees = const [],
    LeadReportType reportType = LeadReportType.all,
    String? employeeName,
  }) async {
    final now = DateTime.now();

    final acquired =
        leads.where((l) => l.status.isAcquired).toList();
    final broker =
        leads.where((l) => l.inputSource == InputSource.broker).toList();
    final active = leads.where(_isActive).length;
    final rejected = leads.where((l) => l.status.isDropped).length;
    final perf = _employeePerformance(leads, employees);

    final doc = pw.Document(
      title: 'FomraLS Land Acquisition Report',
      author: 'Fomra Housing & Infrastructure Pvt. Ltd.',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        footer: _footer,
        build: (ctx) => [
          _title(now),
          pw.SizedBox(height: 14),
          _summary(leads.length, acquired.length, broker.length, active,
              rejected),
          pw.SizedBox(height: 20),
          ..._buildSelectedSections(
            leads: leads,
            acquired: acquired,
            broker: broker,
            perf: perf,
            reportType: reportType,
            employeeName: employeeName,
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Sections ────────────────────────────────────────────────────────────

  static pw.Widget _title(DateTime now,
          {String reportLabel = 'Land Acquisition Report'}) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Fomra Housing & Infrastructure Pvt. Ltd.',
            style: const pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold, color: _brand),
          ),
          pw.SizedBox(height: 2),
          pw.Text(reportLabel,
              style: const pw.TextStyle(fontSize: 12, color: _ink)),
          pw.Text('Generated ${_stamp.format(now)}',
              style: const pw.TextStyle(fontSize: 9, color: _muted)),
          pw.SizedBox(height: 8),
          pw.Divider(color: _border, thickness: 1),
        ],
      );

  static pw.Widget _summary(
      int total, int acquired, int broker, int active, int rejected) {
    pw.Widget tile(String label, String value) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 8),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _tileBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: _border),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(value,
                    style: const pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: _brand)),
                pw.SizedBox(height: 2),
                pw.Text(label,
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
              ],
            ),
          ),
        );
    return pw.Row(children: [
      tile('Total leads', '$total'),
      tile('Acquired', '$acquired'),
      tile('Broker leads', '$broker'),
      tile('Active', '$active'),
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: _tileBg,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: _border),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('$rejected',
                  style: const pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: _brand)),
              pw.SizedBox(height: 2),
              pw.Text('Rejected',
                  style: const pw.TextStyle(fontSize: 9, color: _muted)),
            ],
          ),
        ),
      ),
    ]);
  }

  static pw.Widget _sectionTitle(String title, int count) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(title,
                style: const pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink)),
            pw.SizedBox(width: 6),
            pw.Text('($count)',
                style: const pw.TextStyle(fontSize: 11, color: _muted)),
          ],
        ),
      );

  static List<String> _leadHeaders() => const [
        'Lead ID',
        'Owner',
        'Location',
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
        l.landType.label,
        l.inputSource.label,
        l.status.label,
        l.createdByName.trim().isEmpty ? '-' : l.createdByName,
        _date.format(l.addedOn),
      ];

  static List<List<String>> _leadRows(List<LandLead> leads) =>
      leads.map(_leadRow).toList();

  static List<ReportPreviewSection> _previewSections({
    required List<LandLead> leads,
    required List<LandLead> acquired,
    required List<LandLead> broker,
    required List<_Perf> perf,
    required LeadReportType reportType,
    String? employeeName,
  }) {
    ReportPreviewSection leadsSection(String title, List<LandLead> data,
            {String emptyMsg = 'No leads.'}) =>
        ReportPreviewSection(
          title: title,
          headers: _leadHeaders(),
          rows: _leadRows(data),
          emptyMessage: emptyMsg,
        );

    ReportPreviewSection perfSection() => ReportPreviewSection(
          title: 'Employee Lead Performance',
          headers: const [
            'Employee',
            'Total Leads',
            'Acquired',
            'Broker',
            'Conversion',
          ],
          rows: perf
              .map(
                (p) => [
                  p.name,
                  '${p.total}',
                  '${p.acquired}',
                  '${p.broker}',
                  '${p.total == 0 ? 0 : ((p.acquired / p.total) * 100).round()}%',
                ],
              )
              .toList(),
          emptyMessage: 'No employee activity yet.',
        );

    switch (reportType) {
      case LeadReportType.all:
        return [
          leadsSection('All Leads', leads, emptyMsg: 'No leads yet.'),
          leadsSection('Acquired Leads', acquired,
              emptyMsg: 'No acquired leads yet.'),
          leadsSection('Broker Leads', broker, emptyMsg: 'No broker leads yet.'),
          perfSection(),
        ];
      case LeadReportType.totalLeads:
        return [
          leadsSection('Total Leads', leads, emptyMsg: 'No leads yet.'),
        ];
      case LeadReportType.acquiredLeads:
        return [
          leadsSection('Acquired Leads', acquired,
              emptyMsg: 'No acquired leads yet.'),
        ];
      case LeadReportType.brokerLeads:
        return [
          leadsSection('Broker Leads', broker, emptyMsg: 'No broker leads yet.'),
        ];
      case LeadReportType.employeeLeads:
        final requested = employeeName?.trim() ?? '';
        if (requested.isEmpty || requested.toLowerCase() == 'all') {
          return [perfSection()];
        }
        final employeeLeads = leads
            .where((l) =>
                l.createdByName.trim().toLowerCase() == requested.toLowerCase())
            .toList();
        return [
          leadsSection('Employee Leads · $requested', employeeLeads,
              emptyMsg: 'No leads found for $requested.'),
        ];
    }
  }

  // ── Owner / Broker directory reports ─────────────────────────────────────

  static ReportPreviewData _buildOtherPreview(
    List<LandLead> leads, {
    required OtherReportType otherReportType,
  }) {
    final section = _otherReportSection(leads, otherReportType);
    final kind = otherReportType == OtherReportType.ownerReports
        ? ContactDirectoryKind.owner
        : ContactDirectoryKind.broker;
    final entries = buildContactDirectoryEntries(leads, kind);
    final linkedLeads = entries.fold<int>(0, (sum, e) => sum + e.leads.length);
    final acquired = entries.fold<int>(
      0,
      (sum, e) => sum + e.leads.where((l) => l.status.isAcquired).length,
    );

    return ReportPreviewData(
      generatedAt: DateTime.now(),
      summary: [
        (
          label: otherReportType == OtherReportType.ownerReports
              ? 'Owners'
              : 'Brokers',
          value: '${entries.length}',
        ),
        (label: 'Linked leads', value: '$linkedLeads'),
        (label: 'Acquired', value: '$acquired'),
      ],
      sections: [section],
    );
  }

  static ReportPreviewSection _otherReportSection(
    List<LandLead> leads,
    OtherReportType otherReportType,
  ) {
    final kind = otherReportType == OtherReportType.ownerReports
        ? ContactDirectoryKind.owner
        : ContactDirectoryKind.broker;
    final entries = buildContactDirectoryEntries(leads, kind);
    final isOwner = otherReportType == OtherReportType.ownerReports;

    return ReportPreviewSection(
      title: isOwner ? 'Owner Reports' : 'Broker Reports',
      headers: isOwner
          ? const [
              'Owner Name',
              'Contact',
              'Leads',
              'Acquired',
              'Lead IDs',
              'Locations',
            ]
          : const [
              'Broker Name',
              'Contact',
              'Leads',
              'Acquired',
              'Lead IDs',
            ],
      rows: entries
          .map(
            (e) => isOwner
                ? [
                    e.name,
                    e.contact.isEmpty ? '-' : e.contact,
                    '${e.leads.length}',
                    '${e.leads.where((l) => l.status.isAcquired).length}',
                    e.leads.map((l) => l.leadId).join(', '),
                    e.leads
                        .map((l) => l.location.trim())
                        .where((s) => s.isNotEmpty)
                        .toSet()
                        .join('; '),
                  ]
                : [
                    e.name,
                    e.contact.isEmpty ? '-' : e.contact,
                    '${e.leads.length}',
                    '${e.leads.where((l) => l.status.isAcquired).length}',
                    e.leads.map((l) => l.leadId).join(', '),
                  ],
          )
          .toList(),
      emptyMessage: isOwner
          ? 'No owner records found in leads.'
          : 'No broker records found in leads.',
    );
  }

  static Uint8List buildOtherExcelReport(
    List<LandLead> leads, {
    required OtherReportType otherReportType,
  }) {
    return buildExcelReport(
      leads,
      otherReportType: otherReportType,
    );
  }

  static Future<Uint8List> _buildOtherPdfReport(
    List<LandLead> leads, {
    required OtherReportType otherReportType,
  }) async {
    final preview = _buildOtherPreview(leads, otherReportType: otherReportType);
    final section = preview.sections.first;
    final now = DateTime.now();
    final title = otherReportType == OtherReportType.ownerReports
        ? 'Owner Reports'
        : 'Broker Reports';

    final doc = pw.Document(
      title: 'FomraLS $title',
      author: 'Fomra Housing & Infrastructure Pvt. Ltd.',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        footer: _footer,
        build: (ctx) => [
          _title(now, reportLabel: title),
          pw.SizedBox(height: 14),
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
                      style: const pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          pw.SizedBox(height: 20),
          _sectionTitle(section.title, section.count),
          _directoryTable(section),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _directoryTable(ReportPreviewSection section) {
    if (section.rows.isEmpty) {
      return pw.Text(
        section.emptyMessage,
        style: const pw.TextStyle(
          fontSize: 10,
          color: _muted,
          fontStyle: pw.FontStyle.italic,
        ),
      );
    }
    return pw.TableHelper.fromTextArray(
      headers: section.headers,
      data: section.rows,
      border: pw.TableBorder.all(color: _border, width: 0.5),
      headerStyle: const pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _brand),
      cellStyle: const pw.TextStyle(fontSize: 8.5, color: _ink),
      oddRowDecoration: const pw.BoxDecoration(color: _zebra),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      headerHeight: 18,
    );
  }

  static String _csv(String value) {
    final v = value.replaceAll('\r', ' ').replaceAll('\n', ' ');
    if (v.contains(',') || v.contains('"')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  static pw.Widget _leadsTable(List<LandLead> leads,
      {String emptyMsg = 'No leads.'}) {
    if (leads.isEmpty) {
      return pw.Text(emptyMsg,
          style: const pw.TextStyle(
              fontSize: 10,
              color: _muted,
              fontStyle: pw.FontStyle.italic));
    }
    return pw.TableHelper.fromTextArray(
      headers: _leadHeaders(),
      data: _leadRows(leads),
      border: pw.TableBorder.all(color: _border, width: 0.5),
      headerStyle: const pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _brand),
      cellStyle: const pw.TextStyle(fontSize: 8.5, color: _ink),
      oddRowDecoration: const pw.BoxDecoration(color: _zebra),
      cellAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      headerHeight: 18,
    );
  }

  static pw.Widget _performanceTable(List<_Perf> perf) {
    if (perf.isEmpty) {
      return pw.Text('No employee activity yet.',
          style: const pw.TextStyle(
              fontSize: 10,
              color: _muted,
              fontStyle: pw.FontStyle.italic));
    }
    return pw.TableHelper.fromTextArray(
      headers: const [
        'Employee',
        'Total Leads',
        'Acquired',
        'Broker',
        'Conversion',
      ],
      data: perf
          .map((p) => [
                p.name,
                '${p.total}',
                '${p.acquired}',
                '${p.broker}',
                '${p.total == 0 ? 0 : ((p.acquired / p.total) * 100).round()}%',
              ])
          .toList(),
      border: pw.TableBorder.all(color: _border, width: 0.5),
      headerStyle: const pw.TextStyle(
          fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: _brand),
      cellStyle: const pw.TextStyle(fontSize: 9, color: _ink),
      oddRowDecoration: const pw.BoxDecoration(color: _zebra),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      headerHeight: 18,
      cellAlignments: const {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.center,
        4: pw.Alignment.center,
      },
    );
  }

  static pw.Widget _footer(pw.Context ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text(
          'FomraLS  ·  Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _muted),
        ),
      );

  static List<pw.Widget> _buildSelectedSections({
    required List<LandLead> leads,
    required List<LandLead> acquired,
    required List<LandLead> broker,
    required List<_Perf> perf,
    required LeadReportType reportType,
    String? employeeName,
  }) {
    switch (reportType) {
      case LeadReportType.all:
        return [
          _sectionTitle('All Leads', leads.length),
          _leadsTable(leads, emptyMsg: 'No leads yet.'),
          pw.SizedBox(height: 20),
          _sectionTitle('Acquired Leads', acquired.length),
          _leadsTable(acquired, emptyMsg: 'No acquired leads yet.'),
          pw.SizedBox(height: 20),
          _sectionTitle('Broker Leads', broker.length),
          _leadsTable(broker, emptyMsg: 'No broker leads yet.'),
          pw.SizedBox(height: 20),
          _sectionTitle('Employee Lead Performance', perf.length),
          _performanceTable(perf),
        ];
      case LeadReportType.totalLeads:
        return [
          _sectionTitle('Total Leads', leads.length),
          _leadsTable(leads, emptyMsg: 'No leads yet.'),
        ];
      case LeadReportType.acquiredLeads:
        return [
          _sectionTitle('Acquired Leads', acquired.length),
          _leadsTable(acquired, emptyMsg: 'No acquired leads yet.'),
        ];
      case LeadReportType.brokerLeads:
        return [
          _sectionTitle('Broker Leads', broker.length),
          _leadsTable(broker, emptyMsg: 'No broker leads yet.'),
        ];
      case LeadReportType.employeeLeads:
        final requested = employeeName?.trim() ?? '';
        if (requested.isEmpty || requested.toLowerCase() == 'all') {
          return [
            _sectionTitle('Employee Lead Performance', perf.length),
            _performanceTable(perf),
          ];
        }
        final employeeLeads = leads
            .where((l) => l.createdByName.trim().toLowerCase() ==
                requested.toLowerCase())
            .toList();
        final empAcquired =
            employeeLeads.where((l) => l.status.isAcquired).length;
        final empBroker = employeeLeads
            .where((l) => l.inputSource == InputSource.broker)
            .length;
        final conversion = employeeLeads.isEmpty
            ? 0
            : ((empAcquired / employeeLeads.length) * 100).round();
        return [
          _sectionTitle('Employee Leads · $requested', employeeLeads.length),
          _employeeSummary(requested, employeeLeads.length, empAcquired,
              empBroker, conversion),
          pw.SizedBox(height: 10),
          _leadsTable(
            employeeLeads,
            emptyMsg: 'No leads found for $requested.',
          ),
        ];
    }
  }

  static pw.Widget _employeeSummary(
    String employee,
    int total,
    int acquired,
    int broker,
    int conversion,
  ) {
    pw.Widget tile(String label, String value) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 8),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: _tileBg,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: _border),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  value,
                  style: const pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _brand,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(label,
                    style: const pw.TextStyle(fontSize: 9, color: _muted)),
              ],
            ),
          ),
        );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Employee: $employee',
            style: const pw.TextStyle(
                fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            tile('Total Leads', '$total'),
            tile('Acquired', '$acquired'),
            tile('Broker Leads', '$broker'),
            pw.Expanded(
              child: pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: _tileBg,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: _border),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('$conversion%',
                        style: const pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: _brand)),
                    pw.SizedBox(height: 2),
                    pw.Text('Conversion',
                        style:
                            const pw.TextStyle(fontSize: 9, color: _muted)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _fileSafe(String value) => value
      .trim()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-zA-Z0-9_]+'), '');

  // ── Data ────────────────────────────────────────────────────────────────

  static List<_Perf> _employeePerformance(
      List<LandLead> leads, List<EmployeeProfile> employees) {
    final map = <String, _Perf>{};
    _Perf forName(String n) => map.putIfAbsent(n, () => _Perf(n));

    // Seed with the roster so employees with zero leads still appear.
    for (final e in employees) {
      final n = e.fullName.trim();
      if (n.isNotEmpty) forName(n);
    }
    for (final l in leads) {
      final n =
          l.createdByName.trim().isEmpty ? 'Unassigned' : l.createdByName.trim();
      final p = forName(n);
      p.total++;
      if (l.status.isAcquired) p.acquired++;
      if (l.inputSource == InputSource.broker) p.broker++;
    }
    final list = map.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }
}

class _Perf {
  final String name;
  int total = 0;
  int acquired = 0;
  int broker = 0;
  _Perf(this.name);
}
