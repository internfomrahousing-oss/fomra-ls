import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../services/report_catalog_service.dart';
import '../../services/role_access.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/app_feedback.dart';
import '../../widgets/ui/app_table.dart';

enum _StatusFilter { active, closed, dropped }

extension on _StatusFilter {
  String get label => switch (this) {
        _StatusFilter.active => 'Active',
        _StatusFilter.closed => 'Closed',
        _StatusFilter.dropped => 'Dropped',
      };

  bool matches(LeadStatus status) => switch (this) {
        _StatusFilter.active => status.isActive,
        _StatusFilter.closed => status.isAcquired,
        _StatusFilter.dropped => status.isDropped,
      };
}

/// Configurable report generator — pick one or more report types, apply
/// shared filters, and export as PDF or Excel.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportFormat _format = ReportFormat.pdf;
  final Set<ReportKind> _selectedKinds = {};
  bool _exporting = false;
  ReportKind? _previewingKind;

  DateTimeRange? _dateRange;
  String? _executive;
  String? _district;
  String? _village;
  String? _broker;
  String? _owner;
  final Set<LeadStatus> _stages = {};
  _StatusFilter? _status;

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

  bool get _hasActiveFilters =>
      _dateRange != null ||
      _executive != null ||
      _district != null ||
      _village != null ||
      _broker != null ||
      _owner != null ||
      _stages.isNotEmpty ||
      _status != null;

  void _clearFilters() {
    setState(() {
      _dateRange = null;
      _executive = null;
      _district = null;
      _village = null;
      _broker = null;
      _owner = null;
      _stages.clear();
      _status = null;
    });
  }

  List<String> _distinct(String Function(LandLead l) pick) {
    final values = AppStore.instance.leads
        .map(pick)
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<LandLead> get _filteredLeads {
    return AppStore.instance.leads.where((l) {
      if (_dateRange != null) {
        final d = l.addedOn.toLocal();
        final start = _dateRange!.start;
        final end = _dateRange!.end
            .add(const Duration(hours: 23, minutes: 59, seconds: 59));
        if (d.isBefore(start) || d.isAfter(end)) return false;
      }
      if (_executive != null && l.createdByName != _executive) return false;
      if (_district != null && l.district != _district) return false;
      if (_village != null && l.village != _village) return false;
      if (_broker != null && l.brokerName != _broker) return false;
      if (_owner != null && l.ownerName != _owner) return false;
      if (_stages.isNotEmpty && !_stages.contains(l.status)) return false;
      if (_status != null && !_status!.matches(l.status)) return false;
      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _dateRange,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  Future<void> _generate() async {
    if (_selectedKinds.isEmpty) {
      AppFeedback.warning(context, 'Select at least one report type.');
      return;
    }
    if (!RoleAccess.canExport) {
      AppFeedback.error(context, RoleAccess.deniedMessage('export reports'));
      return;
    }
    setState(() => _exporting = true);
    final leads = _filteredLeads;
    final employees = AppStore.instance.employees;
    var succeeded = 0;
    var failed = 0;
    for (final kind in _selectedKinds) {
      try {
        await ReportCatalogService.exportOneClick(
          kind: kind,
          leads: leads,
          employees: employees,
          format: _format,
        );
        succeeded++;
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _exporting = false);
    if (failed == 0) {
      AppFeedback.success(
        context,
        succeeded == 1
            ? 'Exported 1 report as ${_format == ReportFormat.pdf ? 'PDF' : 'Excel'}.'
            : 'Exported $succeeded reports as ${_format == ReportFormat.pdf ? 'PDF' : 'Excel'}.',
      );
    } else {
      AppFeedback.error(
        context,
        '$succeeded exported, $failed failed. Try again.',
      );
    }
  }

  Future<void> _preview(ReportKind kind) async {
    setState(() => _previewingKind = kind);
    try {
      final preview = await ReportCatalogService.buildLivePreview(
        kind: kind,
        leads: _filteredLeads,
        employees: AppStore.instance.employees,
      );
      if (!mounted) return;
      setState(() => _previewingKind = null);
      await showDialog(
        context: context,
        builder: (_) => _CatalogPreviewDialog(
          kind: kind,
          preview: preview,
          format: _format,
          onExport: () async {
            Navigator.pop(context);
            setState(() => _exporting = true);
            try {
              await ReportCatalogService.exportOneClick(
                kind: kind,
                leads: _filteredLeads,
                employees: AppStore.instance.employees,
                format: _format,
              );
              if (mounted) {
                AppFeedback.success(
                  context,
                  '${kind.label} exported as ${_format == ReportFormat.pdf ? 'PDF' : 'Excel'}.',
                );
              }
            } catch (e) {
              if (mounted) AppFeedback.error(context, 'Export failed: $e');
            } finally {
              if (mounted) setState(() => _exporting = false);
            }
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewingKind = null);
      AppFeedback.error(context, 'Preview failed: $e');
    }
  }

  IconData _icon(ReportKind kind) => switch (kind) {
        ReportKind.daily => Icons.today_outlined,
        ReportKind.weekly => Icons.date_range_outlined,
        ReportKind.monthly => Icons.calendar_month_outlined,
        ReportKind.employee => Icons.badge_outlined,
        ReportKind.district => Icons.map_outlined,
        ReportKind.village => Icons.holiday_village_outlined,
        ReportKind.broker => Icons.handshake_outlined,
        ReportKind.owner => Icons.person_outline,
        ReportKind.conversion => Icons.trending_up_rounded,
        ReportKind.siteAgeing => Icons.hourglass_bottom_rounded,
        ReportKind.pendingApproval => Icons.approval_outlined,
        ReportKind.siteVisit => Icons.apartment_outlined,
        ReportKind.survey => Icons.straighten_outlined,
        ReportKind.legal => Icons.gavel_outlined,
        ReportKind.document => Icons.description_outlined,
        ReportKind.acquisitionSummary => Icons.summarize_outlined,
        ReportKind.pipeline => Icons.filter_alt_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final pad = FomraLayout.pagePadding(context);
    final leadsEmpty = AppStore.instance.leads.isEmpty;
    final filteredCount = _filteredLeads.length;

    return FomraAppShell(
      currentRoute: '/reports',
      appBar: FomraAppBar(
        moduleName: 'Reports',
        breadcrumbs: FomraBreadcrumbs.module('Reports'),
      ),
      body: ListView(
        padding: pad,
        children: [
          Text(
            'Reports',
            style: TextStyle(
              fontSize: FomraLayout.responsiveClamp(context, min: 20, max: 22),
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick one or more report types, apply filters, and export as PDF or Excel.',
            style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: 16),
          if (leadsEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.summarize_outlined,
                title: 'No site data yet',
                message: 'Reports will be available once sites are in the system.',
              ),
            )
          else ...[
            _buildFiltersCard(context),
            const SizedBox(height: 16),
            Text(
              '$filteredCount site(s) match the current filters',
              style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
            ),
            const SizedBox(height: 12),
            _buildReportTypesCard(context),
            const SizedBox(height: 16),
            _buildExportBar(context),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltersCard(BuildContext context) {
    return AppCard(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.fomraTextPrimary,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: const Text('Clear filters'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _dateRangeChip(context),
              _filterDropdown(
                label: 'Executive',
                value: _executive,
                options: _distinct((l) => l.createdByName),
                onChanged: (v) => setState(() => _executive = v),
              ),
              _filterDropdown(
                label: 'District',
                value: _district,
                options: _distinct((l) => l.district),
                onChanged: (v) => setState(() => _district = v),
              ),
              _filterDropdown(
                label: 'Village',
                value: _village,
                options: _distinct((l) => l.village),
                onChanged: (v) => setState(() => _village = v),
              ),
              _filterDropdown(
                label: 'Broker',
                value: _broker,
                options: _distinct((l) => l.brokerName),
                onChanged: (v) => setState(() => _broker = v),
              ),
              _filterDropdown(
                label: 'Owner',
                value: _owner,
                options: _distinct((l) => l.ownerName),
                onChanged: (v) => setState(() => _owner = v),
              ),
              _statusDropdown(context),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Stage',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.fomraTextSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in leadStatusPipelineOrder)
                FilterChip(
                  label: Text(s.label),
                  selected: _stages.contains(s),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _stages.add(s);
                    } else {
                      _stages.remove(s);
                    }
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateRangeChip(BuildContext context) {
    final label = _dateRange == null
        ? 'Date Range'
        : '${DateFormat('d MMM').format(_dateRange!.start)} – ${DateFormat('d MMM yyyy').format(_dateRange!.end)}';
    return InputChip(
      avatar: const Icon(Icons.date_range_outlined, size: 16),
      label: Text(label),
      onPressed: _pickDateRange,
      onDeleted:
          _dateRange == null ? null : () => setState(() => _dateRange = null),
    );
  }

  Widget _statusDropdown(BuildContext context) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<_StatusFilter>(
        key: ValueKey('reports-status-$_status'),
        initialValue: _status,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Status',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true,
          fillColor: context.fomraSurfaceVar,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('All Status')),
          for (final s in _StatusFilter.values)
            DropdownMenuItem(value: s, child: Text(s.label)),
        ],
        onChanged: (v) => setState(() => _status = v),
      ),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        key: ValueKey('reports-filter-$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true,
          fillColor: context.fomraSurfaceVar,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        items: [
          DropdownMenuItem(value: null, child: Text('All $label')),
          for (final o in options)
            DropdownMenuItem(
              value: o,
              child: Text(o, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildReportTypesCard(BuildContext context) {
    return AppCard(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Report types',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: context.fomraTextPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${_selectedKinds.length} selected',
                style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in ReportKind.values)
                _ReportTypeChip(
                  kind: kind,
                  icon: _icon(kind),
                  selected: _selectedKinds.contains(kind),
                  busy: _previewingKind == kind,
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _selectedKinds.add(kind);
                    } else {
                      _selectedKinds.remove(kind);
                    }
                  }),
                  onPreview: () => _preview(kind),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportBar(BuildContext context) {
    return AppCard(
      interactive: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final control = SegmentedButton<ReportFormat>(
            segments: const [
              ButtonSegment(
                value: ReportFormat.pdf,
                label: Text('PDF'),
                icon: Icon(Icons.picture_as_pdf_outlined, size: 16),
              ),
              ButtonSegment(
                value: ReportFormat.excel,
                label: Text('Excel'),
                icon: Icon(Icons.table_chart_outlined, size: 16),
              ),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          );
          final exportButton = FilledButton.icon(
            onPressed: _exporting || !RoleAccess.canExport ? null : _generate,
            icon: _exporting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download_outlined, size: 18),
            label: Text(_exporting
                ? 'Exporting…'
                : 'Generate ${_selectedKinds.isEmpty ? '' : '(${_selectedKinds.length})'}'),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                control,
                const SizedBox(height: 12),
                exportButton,
                if (!RoleAccess.canExport) ...[
                  const SizedBox(height: 8),
                  Text(
                    RoleAccess.deniedMessage('export reports'),
                    style: TextStyle(
                        fontSize: 12, color: context.fomraTextSecondary),
                  ),
                ],
              ],
            );
          }

          return Row(
            children: [
              control,
              const Spacer(),
              if (!RoleAccess.canExport)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    RoleAccess.deniedMessage('export reports'),
                    style: TextStyle(
                        fontSize: 12, color: context.fomraTextSecondary),
                  ),
                ),
              exportButton,
            ],
          );
        },
      ),
    );
  }
}

class _ReportTypeChip extends StatelessWidget {
  final ReportKind kind;
  final IconData icon;
  final bool selected;
  final bool busy;
  final ValueChanged<bool> onSelected;
  final VoidCallback onPreview;

  const _ReportTypeChip({
    required this.kind,
    required this.icon,
    required this.selected,
    required this.busy,
    required this.onSelected,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 16),
      label: Text(kind.label),
      selected: selected,
      onSelected: (sel) => onSelected(sel),
      tooltip: kind.description,
      onDeleted: busy ? null : onPreview,
      deleteIcon: const Icon(Icons.visibility_outlined, size: 16),
    );
  }
}

class _CatalogPreviewDialog extends StatelessWidget {
  final ReportKind kind;
  final ReportPreviewData preview;
  final ReportFormat format;
  final VoidCallback onExport;

  const _CatalogPreviewDialog({
    required this.kind,
    required this.preview,
    required this.format,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: context.fomraSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 920,
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      kind.label,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.fomraTextPrimary,
                      ),
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
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in preview.summary)
                    Chip(
                      label: Text('${s.label}: ${s.value}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  for (final section in preview.sections) ...[
                    Text(
                      '${section.title} (${section.count})',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (section.rows.isEmpty)
                      Text(
                        section.emptyMessage,
                        style: TextStyle(color: context.fomraTextSecondary),
                      )
                    else
                      AppDataTable(
                        minWidth: 520,
                        columns: [
                          for (final h in section.headers) AppTableColumn(h),
                        ],
                        rows: [
                          for (final row in section.rows.take(40))
                            AppTableRow(
                              cells: [for (final c in row) Text(c)],
                            ),
                        ],
                      ),
                    if (section.rows.length > 40)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Showing first 40 of ${section.rows.length} rows. Export for full data.',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Text(
                    format == ReportFormat.pdf ? 'PDF export' : 'Excel export',
                    style: TextStyle(color: context.fomraTextSecondary),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: RoleAccess.canExport ? onExport : null,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Export'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
