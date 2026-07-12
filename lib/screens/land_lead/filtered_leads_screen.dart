import 'package:flutter/material.dart';

import '../../models/land_lead.dart';
import '../../models/lead_list_filter.dart';
import '../../services/app_store.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/ui/app_components.dart';
import 'lead_detail_screen.dart';

class FilteredLeadsScreen extends StatefulWidget {
  final LeadListFilter filter;
  final List<FomraBreadcrumbItem> breadcrumbs;

  const FilteredLeadsScreen({
    super.key,
    required this.filter,
    required this.breadcrumbs,
  });

  static void open(
    BuildContext context,
    LeadListFilter filter, {
    List<FomraBreadcrumbItem>? breadcrumbs,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilteredLeadsScreen(
          filter: filter,
          breadcrumbs:
              breadcrumbs ?? FomraBreadcrumbs.fromWorkspaceFilter(filter.title),
        ),
      ),
    );
  }

  @override
  State<FilteredLeadsScreen> createState() => _FilteredLeadsScreenState();
}

class _FilteredLeadsScreenState extends State<FilteredLeadsScreen> {
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

  @override
  Widget build(BuildContext context) {
    final filter = widget.filter;
    final leads = filterLeads(AppStore.instance.leads, filter);

    return FomraAppShell(
      currentRoute: '/land-lead',
      appBar: FomraAppBar(
        moduleName: filter.title,
        breadcrumbs: widget.breadcrumbs,
      ),
      backgroundColor: context.fomraPageBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: FomraLayout.pagePadding(context),
            child: SectionHeader(
              title: filter.title,
              subtitle:
                  '${leads.length} lead${leads.length == 1 ? '' : 's'} · ${filter.subtitle}',
              icon: Icons.list_alt_rounded,
            ),
          ),
          Expanded(
            child: leads.isEmpty
                ? Center(
                    child: Text(
                      'No leads in this category yet.',
                      style: TextStyle(color: context.fomraTextSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: leads.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: context.fomraBorder.withValues(alpha: 0.7),
                    ),
                    itemBuilder: (_, index) {
                      final lead = leads[index];
                      return _FilteredLeadRow(
                        lead: lead,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LeadDetailScreen(
                              lead: lead,
                              breadcrumbs:
                                  FomraBreadcrumbs.fromFilteredLeadDetail(
                                filterLabel: filter.title,
                                leadId: lead.leadId,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilteredLeadRow extends StatelessWidget {
  final LandLead lead;
  final VoidCallback onTap;

  const _FilteredLeadRow({required this.lead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final owner = lead.ownerName.trim();
    final title = owner.isNotEmpty ? owner : 'Lead #${lead.leadId}';
    final location = [
      lead.location,
      lead.village,
      lead.district,
    ].where((s) => s.trim().isNotEmpty).join(', ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${lead.leadId}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: lead.status.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: lead.status.color.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      lead.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: lead.status.color,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.fomraTextTertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
