import 'package:flutter/material.dart';

import '../../services/app_store.dart';
import '../../services/report_catalog_service.dart';
import '../../services/report_service.dart';
import '../../services/role_access.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/app_feedback.dart';
import '../../widgets/ui/app_table.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ReportFormat _format = ReportFormat.pdf;
  ReportKind? _busyKind;

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

  Future<void> _export(ReportKind kind) async {
    if (_busyKind != null) return;
    if (!RoleAccess.canExport) {
      AppFeedback.error(context, RoleAccess.deniedMessage('export reports'));
      return;
    }
    setState(() => _busyKind = kind);
    try {
      await ReportCatalogService.exportOneClick(
        kind: kind,
        leads: AppStore.instance.leads,
        employees: AppStore.instance.employees,
        format: _format,
      );
      if (!mounted) return;
      AppFeedback.success(
        context,
        '${kind.label} exported as ${_format == ReportFormat.pdf ? 'PDF' : 'Excel'}.',
      );
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(
        context,
        'Export failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    } finally {
      if (mounted) setState(() => _busyKind = null);
    }
  }

  Future<void> _preview(ReportKind kind) async {
    setState(() => _busyKind = kind);
    try {
      final preview = await ReportCatalogService.buildLivePreview(
        kind: kind,
        leads: AppStore.instance.leads,
        employees: AppStore.instance.employees,
      );
      if (!mounted) return;
      setState(() => _busyKind = null);
      await showDialog(
        context: context,
        builder: (_) => _CatalogPreviewDialog(
          kind: kind,
          preview: preview,
          format: _format,
          onExport: () {
            Navigator.pop(context);
            _export(kind);
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyKind = null);
      AppFeedback.error(context, 'Preview failed: $e');
    }
  }

  IconData _icon(ReportKind kind) => switch (kind) {
        ReportKind.daily => Icons.today_outlined,
        ReportKind.weekly => Icons.date_range_outlined,
        ReportKind.monthly => Icons.calendar_month_outlined,
        ReportKind.employee => Icons.badge_outlined,
        ReportKind.village => Icons.holiday_village_outlined,
        ReportKind.broker => Icons.handshake_outlined,
        ReportKind.owner => Icons.person_outline,
        ReportKind.conversion => Icons.trending_up_rounded,
        ReportKind.leadAgeing => Icons.hourglass_bottom_rounded,
        ReportKind.pendingApproval => Icons.approval_outlined,
        ReportKind.survey => Icons.map_outlined,
        ReportKind.siteVisit => Icons.apartment_outlined,
      };

  Color _color(ReportKind kind) => switch (kind) {
        ReportKind.daily => AppColors.info,
        ReportKind.weekly => AppColors.primary,
        ReportKind.monthly => AppColors.secondary,
        ReportKind.employee => AppColors.warning,
        ReportKind.village => AppColors.success,
        ReportKind.broker => AppColors.secondary,
        ReportKind.owner => AppColors.info,
        ReportKind.conversion => AppColors.success,
        ReportKind.leadAgeing => AppColors.warning,
        ReportKind.pendingApproval => AppColors.error,
        ReportKind.survey => AppColors.primary,
        ReportKind.siteVisit => AppColors.info,
      };

  @override
  Widget build(BuildContext context) {
    final pad = FomraLayout.pagePadding(context);
    final leadsEmpty = AppStore.instance.leads.isEmpty;

    return FomraAppShell(
      currentRoute: '/reports',
      body: ListView(
        padding: pad,
        children: [
          Text(
            'Reports',
            style: TextStyle(
              fontSize: FomraLayout.responsiveClamp(
                context,
                min: 20,
                max: 22,
              ),
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'One-click export for daily, weekly, monthly, employee, village, broker, owner, conversion, ageing, approvals, survey, and site-visit reports.',
            style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: 16),
          AppCard(
            interactive: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 520;
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
                  onSelectionChanged: (s) =>
                      setState(() => _format = s.first),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Export format',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.fomraTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: control,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Text(
                      'Export format',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    control,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          if (leadsEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.summarize_outlined,
                title: 'No lead data yet',
                message: 'Reports will be available once leads are in the system.',
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final cross = wide ? 3 : (constraints.maxWidth >= 480 ? 2 : 1);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ReportKind.values.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cross,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 150,
                  ),
                  itemBuilder: (context, i) {
                    final kind = ReportKind.values[i];
                    return _ReportExportCard(
                      kind: kind,
                      icon: _icon(kind),
                      color: _color(kind),
                      busy: _busyKind == kind,
                      enabled: _busyKind == null && RoleAccess.canExport,
                      format: _format,
                      onExport: () => _export(kind),
                      onPreview: () => _preview(kind),
                    );
                  },
                );
              },
            ),
          if (!RoleAccess.canExport) ...[
            const SizedBox(height: 12),
            Text(
              RoleAccess.deniedMessage('export reports'),
              style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReportExportCard extends StatelessWidget {
  final ReportKind kind;
  final IconData icon;
  final Color color;
  final bool busy;
  final bool enabled;
  final ReportFormat format;
  final VoidCallback onExport;
  final VoidCallback onPreview;

  const _ReportExportCard({
    required this.kind,
    required this.icon,
    required this.color,
    required this.busy,
    required this.enabled,
    required this.format,
    required this.onExport,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  kind.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: context.fomraTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              kind.description,
              style: TextStyle(
                fontSize: 12,
                color: context.fomraTextSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: enabled ? onPreview : null,
                child: const Text('Preview'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: enabled ? onExport : null,
                icon: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        format == ReportFormat.pdf
                            ? Icons.picture_as_pdf_outlined
                            : Icons.download_outlined,
                        size: 16,
                      ),
                label: Text(busy ? '…' : 'Export'),
              ),
            ],
          ),
        ],
      ),
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
