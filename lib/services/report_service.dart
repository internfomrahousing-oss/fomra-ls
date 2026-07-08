import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/employee_profile.dart';
import '../models/land_lead.dart';
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

  static bool _isActive(LandLead l) => const [
        LeadStatus.new_,
        LeadStatus.contacted,
        LeadStatus.siteVisit,
        LeadStatus.negotiation,
      ].contains(l.status);

  /// Generate the PDF and hand it to the OS/browser share/download sheet.
  static Future<void> generateLeadsReport(
    List<LandLead> leads, {
    List<EmployeeProfile> employees = const [],
    LeadReportType reportType = LeadReportType.all,
    String? employeeName,
  }) async {
    final bytes = await _buildReport(
      leads,
      employees: employees,
      reportType: reportType,
      employeeName: employeeName,
    );
    await savePdf(
      bytes,
      reportFileName(reportType: reportType, employeeName: employeeName),
    );
  }

  /// The download file name for a given report selection.
  static String reportFileName({
    LeadReportType reportType = LeadReportType.all,
    String? employeeName,
  }) {
    final suffix = switch (reportType) {
      LeadReportType.all => 'All',
      LeadReportType.totalLeads => 'Total_Leads',
      LeadReportType.acquiredLeads => 'Acquired_Leads',
      LeadReportType.brokerLeads => 'Broker_Leads',
      LeadReportType.employeeLeads =>
        employeeName == null || employeeName.trim().isEmpty
            ? 'Employee_Leads_All'
            : 'Employee_${_fileSafe(employeeName)}',
    };
    return 'FomraLS_Report_${suffix}_'
        '${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
  }

  static Future<Uint8List> _buildReport(
    List<LandLead> leads, {
    List<EmployeeProfile> employees = const [],
    LeadReportType reportType = LeadReportType.all,
    String? employeeName,
  }) async {
    final now = DateTime.now();

    final acquired =
        leads.where((l) => l.status == LeadStatus.closed).toList();
    final broker =
        leads.where((l) => l.inputSource == InputSource.broker).toList();
    final active = leads.where(_isActive).length;
    final rejected = leads.where((l) => l.status == LeadStatus.lost).length;
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

  static pw.Widget _title(DateTime now) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Fomra Housing & Infrastructure Pvt. Ltd.',
            style: const pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold, color: _brand),
          ),
          pw.SizedBox(height: 2),
          pw.Text('Land Acquisition Report',
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
      headers: const [
        'Lead ID',
        'Owner',
        'Location',
        'Type',
        'Source',
        'Status',
        'Added By',
        'Date',
      ],
      data: leads
          .map((l) => [
                l.leadId,
                l.ownerName.trim().isEmpty ? '-' : l.ownerName,
                l.location.trim().isEmpty ? '-' : l.location,
                l.landType.label,
                l.inputSource.label,
                l.status.label,
                l.createdByName.trim().isEmpty ? '-' : l.createdByName,
                _date.format(l.addedOn),
              ])
          .toList(),
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
            employeeLeads.where((l) => l.status == LeadStatus.closed).length;
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
      if (l.status == LeadStatus.closed) p.acquired++;
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
