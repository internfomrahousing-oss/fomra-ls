import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/app_store.dart';
import '../../services/report_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/ui/app_components.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _kAllEmployees = 'All';
  bool _generatingReport = false;
  LeadReportType _selectedReportType = LeadReportType.all;
  ReportFormat _selectedReportFormat = ReportFormat.pdf;
  String _selectedEmployeeReport = _kAllEmployees;

  List<String> get _employeeNames {
    final names = <String>{};
    for (final e in AppStore.instance.employees) {
      final name = e.fullName.trim();
      if (name.isNotEmpty) names.add(name);
    }
    for (final l in AppStore.instance.leads) {
      final name = l.createdByName.trim();
      if (name.isNotEmpty) names.add(name);
    }
    final sorted = names.toList()..sort((a, b) => a.compareTo(b));
    return [_kAllEmployees, ...sorted];
  }

  ({IconData icon, String title, String description}) _reportTypeMeta(
    LeadReportType type,
  ) =>
      switch (type) {
        LeadReportType.all => (
            icon: Icons.dashboard_customize_outlined,
            title: 'All Reports',
            description: 'Complete overview of every section',
          ),
        LeadReportType.totalLeads => (
            icon: Icons.location_on_outlined,
            title: 'Total Leads',
            description: 'Every lead in the pipeline',
          ),
        LeadReportType.acquiredLeads => (
            icon: Icons.check_circle_outline,
            title: 'Acquired Leads',
            description: 'Closed and converted deals',
          ),
        LeadReportType.brokerLeads => (
            icon: Icons.handshake_outlined,
            title: 'Broker Leads',
            description: 'Leads sourced through brokers',
          ),
        LeadReportType.employeeLeads => (
            icon: Icons.badge_outlined,
            title: 'Employee Leads',
            description: 'Performance by team member',
          ),
      };

  Color _reportTypeColor(LeadReportType type) => switch (type) {
        LeadReportType.all => AppColors.primary,
        LeadReportType.totalLeads => AppColors.info,
        LeadReportType.acquiredLeads => AppColors.success,
        LeadReportType.brokerLeads => AppColors.secondary,
        LeadReportType.employeeLeads => AppColors.warning,
      };

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  Future<void> _generateReport() async {
    if (_generatingReport) return;
    setState(() => _generatingReport = true);
    try {
      await ReportService.generateLeadsReport(
        AppStore.instance.leads,
        employees: AppStore.instance.employees,
        reportType: _selectedReportType,
        employeeName: _selectedReportType == LeadReportType.employeeLeads &&
                _selectedEmployeeReport != _kAllEmployees
            ? _selectedEmployeeReport
            : null,
        format: _selectedReportFormat,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Couldn’t create report: ${e.toString().replaceFirst('Exception: ', '')}'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _generatingReport = false);
    }
  }

  void _previewReport() {
    final preview = ReportService.buildPreview(
      AppStore.instance.leads,
      employees: AppStore.instance.employees,
      reportType: _selectedReportType,
      employeeName: _selectedReportType == LeadReportType.employeeLeads &&
              _selectedEmployeeReport != _kAllEmployees
          ? _selectedEmployeeReport
          : null,
    );
    showDialog(
      context: context,
      builder: (_) => _ReportPreviewDialog(
        preview: preview,
        format: _selectedReportFormat,
      ),
    );
  }

  Widget _buildReportCard(BuildContext context, {required bool leadsEmpty}) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      radius: AppColors.radiusMd,
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportHeader(context),
          if (leadsEmpty) ...[
            const SizedBox(height: 24),
            const _EmptyReportNotice(),
          ] else ...[
            const SizedBox(height: 24),
            _buildReportTypeSection(context),
            const SizedBox(height: 20),
            _buildReportFormatSection(context),
            _buildEmployeeFilter(context),
            const SizedBox(height: 24),
            _buildReportFooter(context),
          ],
        ],
      ),
    );
  }

  Widget _buildReportHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.summarize_outlined,
            color: AppColors.primary,
            size: 26,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: context.fomraTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Preview, then export as PDF or Excel from your land database.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: context.fomraTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReportTypeSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ReportSectionLabel(
          icon: Icons.category_outlined,
          label: 'Report Type',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final cols = width > 860 ? 3 : (width > 520 ? 2 : 1);
            const spacing = 12.0;
            final itemWidth = (width - spacing * (cols - 1)) / cols;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final type in LeadReportType.values)
                  SizedBox(
                    width: cols == 1 ? width : itemWidth,
                    child: _ReportTypeCard(
                      meta: _reportTypeMeta(type),
                      accent: _reportTypeColor(type),
                      selected: _selectedReportType == type,
                      onTap: () => setState(() => _selectedReportType = type),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildReportFormatSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ReportSectionLabel(
          icon: Icons.file_download_outlined,
          label: 'Export Format',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ReportFormatCard(
                label: 'PDF',
                description: 'Print-ready document',
                icon: Icons.picture_as_pdf_outlined,
                accent: AppColors.primary,
                selected: _selectedReportFormat == ReportFormat.pdf,
                onTap: () =>
                    setState(() => _selectedReportFormat = ReportFormat.pdf),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ReportFormatCard(
                label: 'Excel',
                description: 'Spreadsheet (.csv)',
                icon: Icons.table_chart_outlined,
                accent: AppColors.success,
                selected: _selectedReportFormat == ReportFormat.excel,
                onTap: () =>
                    setState(() => _selectedReportFormat = ReportFormat.excel),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmployeeFilter(BuildContext context) {
    final employees = _employeeNames;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      child: _selectedReportType != LeadReportType.employeeLeads
          ? const SizedBox(width: double.infinity)
          : Padding(
              key: const ValueKey('employee-filter'),
              padding: const EdgeInsets.only(top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ReportSectionLabel(
                    icon: Icons.person_search_outlined,
                    label: 'Filter by Employee',
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: employees.contains(_selectedEmployeeReport)
                        ? _selectedEmployeeReport
                        : employees.first,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    borderRadius: BorderRadius.circular(14),
                    items: employees
                        .map((name) => DropdownMenuItem<String>(
                              value: name,
                              child: Text(
                                name == _kAllEmployees ? 'All Employees' : name,
                              ),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedEmployeeReport = value);
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(
                        Icons.badge_outlined,
                        size: 20,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildReportFooter(BuildContext context) {
    final isPdf = _selectedReportFormat == ReportFormat.pdf;
    final generatingLabel = isPdf ? 'Preparing PDF…' : 'Preparing Excel…';
    final generateLabel = isPdf ? 'Generate PDF' : 'Generate Excel';
    final generateIcon =
        isPdf ? Icons.picture_as_pdf_outlined : Icons.table_chart_outlined;

    return Container(
      padding: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.fomraBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SecondaryButton(
              label: 'Preview',
              icon: Icons.visibility_outlined,
              onPressed: _generatingReport ? null : _previewReport,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: PrimaryButton(
              label: _generatingReport ? generatingLabel : generateLabel,
              icon: generateIcon,
              loading: _generatingReport,
              expand: true,
              onPressed: _generatingReport ? null : _generateReport,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leads = AppStore.instance.leads;

    return FomraAppShell(
      currentRoute: '/reports',
      appBar: const FomraAppBar(moduleName: 'Reports'),
      backgroundColor: context.fomraPageBg,
      body: SingleChildScrollView(
        padding: FomraLayout.pagePadding(context),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Reports',
                  subtitle:
                      'Generate PDF or Excel exports from your land lead database.',
                  icon: Icons.summarize_outlined,
                ),
                const SizedBox(height: 16),
                _buildReportCard(context, leadsEmpty: leads.isEmpty),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportSectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ReportSectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.fomraTextSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: context.fomraTextPrimary,
          ),
        ),
      ],
    );
  }
}

class _ReportTypeCard extends StatelessWidget {
  final ({IconData icon, String title, String description}) meta;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _ReportTypeCard({
    required this.meta,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.08)
                : context.fomraSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : context.fomraBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: Icon(meta.icon, color: accent, size: 20),
                  ),
                  const Spacer(),
                  AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    scale: selected ? 1 : 0,
                    child: Icon(
                      Icons.check_circle_rounded,
                      color: accent,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                meta.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.fomraTextPrimary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                meta.description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: context.fomraTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyReportNotice extends StatelessWidget {
  const _EmptyReportNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.fomraBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.inbox_outlined, color: context.fomraTextTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No leads available for report generation yet.',
              style: TextStyle(
                fontSize: 13,
                color: context.fomraTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportFormatCard extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _ReportFormatCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.08)
                : context.fomraSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : context.fomraBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportPreviewDialog extends StatelessWidget {
  final ReportPreviewData preview;
  final ReportFormat format;

  const _ReportPreviewDialog({
    required this.preview,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final stamp = DateFormat('dd MMM yyyy, h:mm a').format(preview.generatedAt);
    final formatLabel =
        format == ReportFormat.pdf ? 'PDF export' : 'Excel export';

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: context.fomraSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 960,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.visibility_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                        Text(
                          '$formatLabel · $stamp',
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
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in preview.summary)
                    _PreviewSummaryChip(
                      label: item.label,
                      value: item.value,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: preview.sections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 20),
                itemBuilder: (_, i) {
                  final section = preview.sections[i];
                  return _PreviewSectionBlock(section: section);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _PreviewSummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fomraBorder),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: context.fomraTextPrimary,
        ),
      ),
    );
  }
}

class _PreviewSectionBlock extends StatelessWidget {
  final ReportPreviewSection section;

  const _PreviewSectionBlock({required this.section});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${section.title} (${section.count})',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: context.fomraTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        if (section.rows.isEmpty)
          Text(
            section.emptyMessage,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: context.fomraTextSecondary,
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 34,
              dataRowMaxHeight: 48,
              columnSpacing: 18,
              headingTextStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.fomraTextSecondary,
              ),
              dataTextStyle: TextStyle(
                fontSize: 12,
                color: context.fomraTextPrimary,
              ),
              columns: [
                for (final h in section.headers) DataColumn(label: Text(h)),
              ],
              rows: [
                for (final row in section.rows)
                  DataRow(
                    cells: [
                      for (final cell in row)
                        DataCell(
                          Text(
                            cell,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
