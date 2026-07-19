import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../services/auth_service.dart';
import '../../services/report_catalog_service.dart';
import '../../services/role_access.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/app_feedback.dart';
import '../../widgets/ui/app_table.dart';

/// Management + admins can export reports, and executives can export their own
/// (report data is already scoped to their leads via [AppStore.visibleLeads]).
bool get _reportsCanExport =>
    RoleAccess.canExport || AuthService.instance.isEmployee;

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

/// Report categories shown as premium selectable cards.
const _reportCategories = <({String name, List<ReportKind> kinds})>[
  (
    name: 'Performance',
    kinds: [
      ReportKind.employee,
      ReportKind.broker,
      ReportKind.district,
      ReportKind.village,
    ],
  ),
  (
    name: 'Acquisition',
    kinds: [
      ReportKind.pipeline,
      ReportKind.conversion,
      ReportKind.siteAgeing,
      ReportKind.acquisitionSummary,
    ],
  ),
  (
    name: 'Operations',
    kinds: [
      ReportKind.siteVisit,
      ReportKind.pendingApproval,
    ],
  ),
  (
    name: 'Time Reports',
    kinds: [
      ReportKind.daily,
      ReportKind.weekly,
      ReportKind.monthly,
    ],
  ),
];

const _quickReports = <({String label, ReportKind kind})>[
  (label: "Today's Report", kind: ReportKind.daily),
  (label: 'Weekly Report', kind: ReportKind.weekly),
  (label: 'Monthly Report', kind: ReportKind.monthly),
  (label: 'Employee Performance', kind: ReportKind.employee),
  (label: 'Pipeline Report', kind: ReportKind.pipeline),
];

/// Premium enterprise reporting: quick reports, categorized report cards, a
/// slide-in filters drawer, a live summary, an inline preview and export.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportFormat _format = ReportFormat.pdf;
  final Set<ReportKind> _selectedKinds = {};
  bool _exporting = false;

  bool _previewLoading = false;
  ReportKind? _previewKind;
  ReportPreviewData? _previewData;

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

  int get _activeFilterCount =>
      (_dateRange != null ? 1 : 0) +
      (_executive != null ? 1 : 0) +
      (_district != null ? 1 : 0) +
      (_village != null ? 1 : 0) +
      (_broker != null ? 1 : 0) +
      (_owner != null ? 1 : 0) +
      (_stages.isNotEmpty ? 1 : 0) +
      (_status != null ? 1 : 0);

  bool get _hasActiveFilters => _activeFilterCount > 0;

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
    final values = AppStore.instance.visibleLeads
        .map(pick)
        .where((v) => v.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  List<LandLead> get _filteredLeads {
    return AppStore.instance.visibleLeads.where((l) {
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
      // A compact input dialog instead of the full-screen calendar (tap the
      // calendar icon inside to switch to the month view if needed).
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  void _toggleKind(ReportKind kind) {
    // Only one report type may be selected at a time — selecting another
    // automatically deselects the previous one.
    setState(() {
      if (_selectedKinds.contains(kind)) {
        _selectedKinds.clear();
      } else {
        _selectedKinds
          ..clear()
          ..add(kind);
      }
    });
  }

  void _selectQuickReport(ReportKind kind) {
    setState(() {
      _selectedKinds
        ..clear()
        ..add(kind);
    });
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    if (_selectedKinds.isEmpty) {
      AppFeedback.warning(context, 'Select a report to preview.');
      return;
    }
    final kind = _selectedKinds.first;
    setState(() {
      _previewLoading = true;
      _previewKind = kind;
    });
    try {
      final data = await ReportCatalogService.buildLivePreview(
        kind: kind,
        leads: _filteredLeads,
        employees: AppStore.instance.employees,
      );
      if (!mounted) return;
      setState(() {
        _previewData = data;
        _previewLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _previewLoading = false);
      AppFeedback.error(context, 'Preview failed: $e');
    }
  }

  Future<void> _generate() async {
    if (_selectedKinds.isEmpty) {
      AppFeedback.warning(context, 'Select at least one report type.');
      return;
    }
    if (!_reportsCanExport) {
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
    final fmt = _formatLabel(_format);
    if (failed == 0) {
      AppFeedback.success(
        context,
        succeeded == 1
            ? 'Exported 1 report as $fmt.'
            : 'Exported $succeeded reports as $fmt.',
      );
    } else {
      AppFeedback.error(context, '$succeeded exported, $failed failed.');
    }
  }

  static String _formatLabel(ReportFormat f) => switch (f) {
        ReportFormat.pdf => 'PDF',
        ReportFormat.excel => 'Excel',
        ReportFormat.csv => 'CSV',
      };

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

  // ── Filters drawer ─────────────────────────────────────────────────────────

  void _openFilters() {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Filters',
      barrierColor: Colors.black.withValues(alpha: 0.35),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, a1, a2) {
        final width =
            math.min(380.0, MediaQuery.sizeOf(ctx).width * 0.88);
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: context.fomraSurface,
            elevation: 12,
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: SafeArea(
                child: StatefulBuilder(
                  builder: (ctx, setSheet) {
                    void apply(VoidCallback fn) {
                      setState(fn);
                      setSheet(() {});
                    }

                    return _buildFiltersDrawer(ctx, apply);
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, sec, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(curved),
          child: child,
        );
      },
    );
  }

  Widget _buildFiltersDrawer(
    BuildContext context,
    void Function(VoidCallback) apply,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              const Icon(Icons.tune_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: context.fomraTextPrimary,
                ),
              ),
              const Spacer(),
              if (_hasActiveFilters)
                TextButton(
                  onPressed: () => apply(_clearFilters),
                  child: const Text('Clear'),
                ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await _pickDateRange();
                  apply(() {});
                },
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(
                  _dateRange == null
                      ? 'Date range'
                      : '${DateFormat('d MMM').format(_dateRange!.start)} – ${DateFormat('d MMM yyyy').format(_dateRange!.end)}',
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              _drawerDropdown('Executive', _executive,
                  _distinct((l) => l.createdByName),
                  (v) => apply(() => _executive = v)),
              _drawerDropdown('District', _district,
                  _distinct((l) => l.district),
                  (v) => apply(() => _district = v)),
              _drawerDropdown('Village', _village,
                  _distinct((l) => l.village),
                  (v) => apply(() => _village = v)),
              _drawerDropdown('Broker', _broker,
                  _distinct((l) => l.brokerName),
                  (v) => apply(() => _broker = v)),
              _drawerDropdown('Owner', _owner, _distinct((l) => l.ownerName),
                  (v) => apply(() => _owner = v)),
              const SizedBox(height: 4),
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
                      onSelected: (sel) => apply(() {
                        if (sel) {
                          _stages.add(s);
                        } else {
                          _stages.remove(s);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _statusDropdown((v) => apply(() => _status = v)),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              child: Text('Apply${_hasActiveFilters ? ' ($_activeFilterCount)' : ''}'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _drawerDropdown(
    String label,
    String? value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        key: ValueKey('rp-$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: context.fomraSurfaceVar,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
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

  Widget _statusDropdown(ValueChanged<_StatusFilter?> onChanged) {
    return DropdownButtonFormField<_StatusFilter>(
      key: ValueKey('rp-status-$_status'),
      initialValue: _status,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Status',
        isDense: true,
        filled: true,
        fillColor: context.fomraSurfaceVar,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All status')),
        for (final s in _StatusFilter.values)
          DropdownMenuItem(value: s, child: Text(s.label)),
      ],
      onChanged: onChanged,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pad = FomraLayout.pagePadding(context);
    final leadsEmpty = AppStore.instance.visibleLeads.isEmpty;

    return FomraAppShell(
      currentRoute: '/reports',
      appBar: const FomraAppBar(
        moduleName: 'Reports',
      ),
      body: ListView(
        padding: pad,
        children: [
          _titleRow(context),
          const SizedBox(height: 16),
          if (leadsEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.summarize_outlined,
                title: 'No site data yet',
                message:
                    'Reports will be available once sites are in the system.',
              ),
            )
          else ...[
            _quickReportsSection(context),
            const SizedBox(height: 20),
            _categoriesSection(context),
            const SizedBox(height: 20),
            _liveSummarySection(context),
            const SizedBox(height: 20),
            _previewSection(context),
            const SizedBox(height: 20),
            _exportSection(context),
          ],
        ],
      ),
    );
  }

  Widget _titleRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reports',
                style: TextStyle(
                  fontSize:
                      FomraLayout.responsiveClamp(context, min: 20, max: 22),
                  fontWeight: FontWeight.w800,
                  color: context.fomraTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Build enterprise reports, preview, and export as PDF, Excel or CSV.',
                style:
                    TextStyle(fontSize: 13, color: context.fomraTextSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _openFilters,
          icon: Badge(
            isLabelVisible: _hasActiveFilters,
            label: Text('$_activeFilterCount'),
            child: const Icon(Icons.tune_rounded, size: 18),
          ),
          label: const Text('Filters'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _quickReportsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'Quick reports', Icons.bolt_outlined),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _quickReports.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final q = _quickReports[i];
              final selected = _selectedKinds.contains(q.kind) &&
                  _selectedKinds.length == 1;
              return Material(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : context.fomraSurface,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => _selectQuickReport(q.kind),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : context.fomraBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_icon(q.kind),
                            size: 16,
                            color: selected
                                ? AppColors.primary
                                : context.fomraTextSecondary),
                        const SizedBox(width: 6),
                        Text(
                          q.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.primary
                                : context.fomraTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _categoriesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(context, 'Report types', Icons.grid_view_outlined,
            trailing: '${_selectedKinds.length} selected'),
        const SizedBox(height: 10),
        for (final cat in _reportCategories) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(
              cat.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.fomraTextSecondary,
              ),
            ),
          ),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 720 ? 3 : (c.maxWidth >= 480 ? 2 : 1);
              const gap = 10.0;
              final cardW = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final kind in cat.kinds)
                    SizedBox(width: cardW, child: _reportCard(context, kind)),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _reportCard(BuildContext context, ReportKind kind) {
    final selected = _selectedKinds.contains(kind);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _toggleKind(kind),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.06)
                : context.fomraSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : context.fomraBorder,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected ? context.fomraCardShadow : null,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(_icon(kind), size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kind.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      kind.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: selected ? AppColors.primary : context.fomraBorder,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _liveSummarySection(BuildContext context) {
    final leads = _filteredLeads;
    final executives = _distinctFrom(leads, (l) => l.createdByName);
    final villages = _distinctFrom(leads, (l) => l.village);
    final estPages = _selectedKinds.isEmpty
        ? 0
        : _selectedKinds.length * math.max(1, (leads.length / 25).ceil());
    final rangeLabel = _dateRange == null
        ? 'All time'
        : '${DateFormat('d MMM').format(_dateRange!.start)} – ${DateFormat('d MMM').format(_dateRange!.end)}';

    final cells = <({String label, String value, IconData icon})>[
      (label: 'Records found', value: '${leads.length}', icon: Icons.dataset_outlined),
      (label: 'Executives', value: '$executives', icon: Icons.badge_outlined),
      (label: 'Villages', value: '$villages', icon: Icons.holiday_village_outlined),
      (label: 'Selected reports', value: '${_selectedKinds.length}', icon: Icons.checklist_rounded),
      (label: 'Date range', value: rangeLabel, icon: Icons.date_range_outlined),
      (label: 'Estimated pages', value: '$estPages', icon: Icons.description_outlined),
    ];

    return AppCard(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, 'Live summary', Icons.insights_outlined),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 560 ? 3 : 2;
              const gap = 10.0;
              final w = (c.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final cell in cells)
                    SizedBox(
                      width: w,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.fomraSurfaceVar.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.fomraBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(cell.icon,
                                size: 16, color: context.fomraTextSecondary),
                            const SizedBox(height: 8),
                            Text(
                              cell.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: context.fomraTextPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cell.label,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.fomraTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  int _distinctFrom(List<LandLead> leads, String Function(LandLead) pick) =>
      leads.map(pick).where((v) => v.trim().isNotEmpty).toSet().length;

  Widget _previewSection(BuildContext context) {
    return AppCard(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(context, 'Report preview', Icons.visibility_outlined),
          const SizedBox(height: 12),
          if (_previewLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_previewData == null || _previewKind == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Select a report and tap "Preview Report" to see sample tables, '
                'KPIs and summaries before exporting.',
                style:
                    TextStyle(fontSize: 13, color: context.fomraTextSecondary),
              ),
            )
          else
            _previewContent(context, _previewKind!, _previewData!),
        ],
      ),
    );
  }

  Widget _previewContent(
    BuildContext context,
    ReportKind kind,
    ReportPreviewData data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kind.label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: context.fomraTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in data.summary)
              Chip(
                label: Text('${s.label}: ${s.value}'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 14),
        for (final section in data.sections.take(2)) ...[
          Text(
            '${section.title} (${section.count})',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (section.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                section.emptyMessage,
                style: TextStyle(color: context.fomraTextSecondary),
              ),
            )
          else
            AppDataTable(
              minWidth: 520,
              columns: [for (final h in section.headers) AppTableColumn(h)],
              rows: [
                for (final row in section.rows.take(8))
                  AppTableRow(cells: [for (final c in row) Text(c)]),
              ],
            ),
          if (section.rows.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 12),
              child: Text(
                'Showing first 8 of ${section.rows.length} rows. Export for full data.',
                style:
                    TextStyle(fontSize: 12, color: context.fomraTextSecondary),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _exportSection(BuildContext context) {
    return AppCard(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel(context, 'Export', Icons.download_outlined),
          const SizedBox(height: 12),
          SegmentedButton<ReportFormat>(
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
              ButtonSegment(
                value: ReportFormat.csv,
                label: Text('CSV'),
                icon: Icon(Icons.grid_on_outlined, size: 16),
              ),
            ],
            selected: {_format},
            onSelectionChanged: (s) => setState(() => _format = s.first),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final preview = OutlinedButton.icon(
                onPressed: _previewLoading ? null : _loadPreview,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Preview Report'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              );
              final generate = FilledButton.icon(
                onPressed:
                    _exporting || !_reportsCanExport ? null : _generate,
                icon: _exporting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: Text(_exporting
                    ? 'Generating…'
                    : 'Generate Report${_selectedKinds.isEmpty ? '' : ' (${_selectedKinds.length})'}'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              );
              if (c.maxWidth < 460) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    preview,
                    const SizedBox(height: 10),
                    generate,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: preview),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: generate),
                ],
              );
            },
          ),
          if (!_reportsCanExport) ...[
            const SizedBox(height: 8),
            Text(
              RoleAccess.deniedMessage('export reports'),
              style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text, IconData icon,
      {String? trailing}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: context.fomraTextPrimary,
          ),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(
            trailing,
            style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
          ),
        ],
      ],
    );
  }
}
