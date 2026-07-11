import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/add_lead_result.dart';
import '../../models/land_lead.dart';
import '../../models/land_lead_site_visit.dart';
import '../../models/lead_call_log.dart';
import '../../services/app_store.dart';
import '../../services/land_lead_service.dart';
import '../../services/land_lead_site_visit_service.dart';
import '../../services/lead_call_log_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/separate_date_time_fields.dart';
import '../../widgets/ui/app_components.dart';
import '../market_intelligence/market_intelligence_screen.dart';
import '../task_management/task_management_screen.dart';
import 'add_lead_screen.dart';
import 'calls_log_dialog.dart';
import 'legal_documents_dialog.dart';
import 'meeting_log_dialog.dart';
import 'site_visit_dialog.dart';

int _leadAgeDaysFromReceived(DateTime receivedOn) {
  final received = receivedOn.toLocal();
  final now = DateTime.now();
  final receivedDay = DateTime(received.year, received.month, received.day);
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(receivedDay).inDays;
}

String _formatReceivedOn(DateTime receivedOn) {
  final local = receivedOn.toLocal();
  return '${local.day}/${local.month}/${local.year} '
      '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
}

class LeadDetailScreen extends StatefulWidget {
  final LandLead lead;
  final List<FomraBreadcrumbItem>? breadcrumbs;

  const LeadDetailScreen({
    super.key,
    required this.lead,
    this.breadcrumbs,
  });

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen>
    with SingleTickerProviderStateMixin {
  late LandLead lead = widget.lead;
  late final TabController _tabController;
  List<LeadCallLog> _callLogs = [];
  List<LandLeadSiteVisit> _siteVisits = [];

  static const _tabs = [
    'Activity',
    'Details',
    'Site Photos',
    'Infrastructure',
    'Land Records',
    'Competitor Projects',
  ];

  static const _miTabStart = 3;
  final Set<int> _loadedMiTabs = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadActivityData();
  }

  Future<void> _loadActivityData() async {
    try {
      final results = await Future.wait([
        LeadCallLogService.getForLead(lead.leadId),
        LandLeadSiteVisitService.getForLead(
          lead.leadId,
          visitType: LandLeadSiteVisitType.employee,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _callLogs = results[0] as List<LeadCallLog>;
        _siteVisits = results[1] as List<LandLeadSiteVisit>;
      });
    } catch (_) {
      // Tables may not exist yet — keep counts at zero.
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final index = _tabController.index;
    if (index >= _miTabStart && !_loadedMiTabs.contains(index)) {
      setState(() => _loadedMiTabs.add(index));
    }
  }

  bool _shouldLoadMiTab(int index) =>
      _loadedMiTabs.contains(index) || _tabController.index == index;

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  String get _displayName => lead.ownerName.trim().isEmpty
      ? 'Lead #${lead.leadId}'
      : lead.ownerName.trim();

  int get _leadAgeDays => _leadAgeDaysFromReceived(lead.addedOn);

  CallActivityMetrics get _callMetrics =>
      CallActivityMetrics.fromLogs(_callLogs);

  Future<void> _openEdit() async {
    final result = await Navigator.push<AddLeadResult>(
      context,
      MaterialPageRoute(builder: (_) => AddLeadScreen(existingLead: lead)),
    );
    if (result == null || !mounted) return;

    try {
      final saved = await LandLeadService.update(
        result.lead,
        sitePhotoBytes: result.sitePhotoBytes,
      );
      AppStore.instance.replaceLead(saved);
      setState(() => lead = saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lead updated')),
        );
      }
    } catch (e) {
      AppStore.instance.replaceLead(result.lead);
      setState(() => lead = result.lead);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved locally; sync failed: $e')),
        );
      }
    }
  }

  Future<void> _changeStatus(LeadStatus? status) async {
    if (status == null || status == lead.status) return;
    final previous = lead.status;
    setState(() => lead.status = status);
    AppStore.instance.replaceLead(lead);
    try {
      await LandLeadService.updateStatus(lead.leadId, status);
    } catch (_) {
      setState(() => lead.status = previous);
      AppStore.instance.replaceLead(lead);
    }
  }

  Future<void> _launchContact(String scheme) async {
    final raw = lead.contactDetails.replaceAll(RegExp(r'[^\d+]'), '');
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contact number on this lead')),
      );
      return;
    }
    final Uri uri;
    if (scheme.startsWith('https://wa.me')) {
      uri = Uri.parse('https://wa.me/$raw');
    } else {
      uri = Uri.parse('$scheme:$raw');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open contact action')),
        );
      }
    }
  }

  void _openCreateTask() {
    showCreateTaskSheet(
      context,
      leadId: lead.leadId,
      leadLabel: lead.ownerName.trim().isNotEmpty ? lead.ownerName.trim() : null,
      leadLocation: lead.location,
    );
  }

  void _handleDetailAction(String label) {
    _showActionDialog(label);
  }

  Future<void> _showActionDialog(String label) async {
    if (label == 'Calls') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => CallsLogDialog(
          leadId: lead.leadId,
          ownerName: lead.ownerName,
        ),
      );
      await _loadActivityData();
      return;
    }

    if (label == 'Site visit') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => SiteVisitDialog(
          leadId: lead.leadId,
          onVisitDone: () {
            if (lead.status == LeadStatus.prospectMeetingPending) {
              _changeStatus(LeadStatus.prospectMeetingCompleted);
            }
          },
        ),
      );
      await _loadActivityData();
      return;
    }

    if (label == 'Management site visit') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => SiteVisitDialog.management(
          leadId: lead.leadId,
        ),
      );
      return;
    }

    if (label == 'Meeting') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => MeetingLogDialog(
          leadId: lead.leadId,
          ownerName: lead.ownerName,
          onMeetingSaved: () {
            if (lead.status == LeadStatus.prospectMeetingPending) {
              _changeStatus(LeadStatus.prospectMeetingCompleted);
            }
          },
        ),
      );
      return;
    }

    if (label == 'Legal') {
      await showDialog<void>(
        context: context,
        builder: (ctx) => LegalDocumentsDialog(leadId: lead.leadId),
      );
      return;
    }

    final icon = switch (label) {
      'Calls' => Icons.call_outlined,
      'Site visit' => Icons.location_on_outlined,
      'Management site visit' => Icons.apartment_outlined,
      'Meeting' => Icons.groups_outlined,
      'Legal' => Icons.gavel_outlined,
      'Signed' => Icons.draw_outlined,
      _ => Icons.touch_app_outlined,
    };

    await showDialog<void>(
      context: context,
      builder: (ctx) => _LeadActionDialog(
        actionLabel: label,
        icon: icon,
        leadId: lead.leadId,
      ),
    );
  }

  List<FomraBreadcrumbItem> get _breadcrumbs =>
      widget.breadcrumbs ??
      FomraBreadcrumbs.fromWorkspace('Lead ${lead.leadId}');

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/land-lead',
      backgroundColor: const Color(0xFFEEF1F6),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(
                  leadId: lead.leadId,
                  onBack: () => Navigator.pop(context),
                  onEdit: _openEdit,
                ),
                FomraBreadcrumbStrip(items: _breadcrumbs),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _ProfilePanel(
                                  lead: lead,
                                  displayName: _displayName,
                                  leadAgeDays: _leadAgeDays,
                                  onStatusChanged: _changeStatus,
                                  onLaunchContact: _launchContact,
                                  onCreateTask: _openCreateTask,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: _WorkspacePanel(
                                  lead: lead,
                                  tabController: _tabController,
                                  tabs: _tabs,
                                  siteVisitCount: _siteVisits.length,
                                  callMetrics: _callMetrics,
                                  callLogs: _callLogs,
                                  siteVisits: _siteVisits,
                                  onLaunchContact: _launchContact,
                                  onDetailAction: _handleDetailAction,
                                  shouldLoadMiTab: _shouldLoadMiTab,
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            children: [
                              _ProfilePanel(
                                lead: lead,
                                displayName: _displayName,
                                leadAgeDays: _leadAgeDays,
                                onStatusChanged: _changeStatus,
                                onLaunchContact: _launchContact,
                                onCreateTask: _openCreateTask,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: constraints.maxHeight * 0.72,
                                child: _WorkspacePanel(
                                  lead: lead,
                                  tabController: _tabController,
                                  tabs: _tabs,
                                  siteVisitCount: _siteVisits.length,
                                  callMetrics: _callMetrics,
                                  callLogs: _callLogs,
                                  siteVisits: _siteVisits,
                                  onLaunchContact: _launchContact,
                                  onDetailAction: _handleDetailAction,
                                  shouldLoadMiTab: _shouldLoadMiTab,
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
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String leadId;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  const _TopBar({
    required this.leadId,
    required this.onBack,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        color: context.fomraSurface,
        border: Border(bottom: BorderSide(color: context.fomraBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person_pin_circle_outlined,
              color: AppColors.purple,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
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
                Text(
                  'Lead workspace',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.fomraTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit lead'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  final LandLead lead;
  final String displayName;
  final int leadAgeDays;
  final ValueChanged<LeadStatus?> onStatusChanged;
  final Future<void> Function(String scheme) onLaunchContact;
  final VoidCallback onCreateTask;

  const _ProfilePanel({
    required this.lead,
    required this.displayName,
    required this.leadAgeDays,
    required this.onStatusChanged,
    required this.onLaunchContact,
    required this.onCreateTask,
  });

  @override
  Widget build(BuildContext context) {
    final locationLabel = [
      if (lead.village.isNotEmpty) lead.village,
      if (lead.district.isNotEmpty) lead.district,
    ].join(', ');
    final initial = displayName.isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '#';

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: context.fomraSurface,
          border: Border.all(color: context.fomraBorder),
          boxShadow: AppColors.cardShadow,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 12, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      lead.status.color.withValues(alpha: 0.18),
                      lead.status.color.withValues(alpha: 0.04),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(color: context.fomraBorder),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: lead.status.color.withValues(alpha: 0.2),
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: lead.status.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#${lead.leadId}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              color: context.fomraTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: context.fomraTextPrimary,
                            ),
                          ),
                          if (locationLabel.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.place_outlined,
                                  size: 14,
                                  color: context.fomraTextSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    locationLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.fomraTextSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _InfoChip(
                                label: '$leadAgeDays days old',
                                icon: Icons.schedule_outlined,
                              ),
                              _InfoChip(
                                label: lead.landType.label,
                                icon: Icons.landscape_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (lead.contactDetails.isNotEmpty)
                      IconButton(
                        tooltip: 'WhatsApp',
                        onPressed: () => onLaunchContact('https://wa.me'),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366)
                              .withValues(alpha: 0.12),
                        ),
                        icon: const Icon(Icons.chat_rounded,
                            color: Color(0xFF25D366)),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StageStatusField(
                      status: lead.status,
                      onStatusChanged: onStatusChanged,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'LEAD DETAILS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _LeadInfoGrid(lead: lead, leadAgeDays: leadAgeDays),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onCreateTask,
                        icon: const Icon(Icons.add_task_outlined, size: 18),
                        label: const Text('Create Task'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.purple,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    if (lead.contactDetails.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => onLaunchContact('tel'),
                          icon: const Icon(Icons.phone_outlined, size: 18),
                          label: const Text('View contact details'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.fomraSurface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.fomraBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: context.fomraTextSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.fomraTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspacePanel extends StatelessWidget {
  final LandLead lead;
  final TabController tabController;
  final List<String> tabs;
  final int siteVisitCount;
  final CallActivityMetrics callMetrics;
  final List<LeadCallLog> callLogs;
  final List<LandLeadSiteVisit> siteVisits;
  final Future<void> Function(String scheme) onLaunchContact;
  final ValueChanged<String> onDetailAction;
  final bool Function(int tabIndex) shouldLoadMiTab;

  const _WorkspacePanel({
    required this.lead,
    required this.tabController,
    required this.tabs,
    required this.siteVisitCount,
    required this.callMetrics,
    required this.callLogs,
    required this.siteVisits,
    required this.onLaunchContact,
    required this.onDetailAction,
    required this.shouldLoadMiTab,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: context.fomraSurface,
          border: Border.all(color: context.fomraBorder),
          boxShadow: AppColors.cardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'QUICK ACTIONS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: context.fomraTextSecondary,
              ),
            ),
            const SizedBox(height: 10),
            _ActionToolbar(onAction: onDetailAction),
            const SizedBox(height: 16),
            _ActivitySummaryRow(
              siteVisitCount: siteVisitCount,
              callMetrics: callMetrics,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: context.fomraSurfaceVar.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                labelColor: AppColors.purple,
                unselectedLabelColor: context.fomraTextSecondary,
                indicator: BoxDecoration(
                  color: context.fomraSurface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                tabs: [for (final t in tabs) Tab(text: t, height: 34)],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  _ActivityTimeline(
                    lead: lead,
                    callLogs: callLogs,
                    siteVisits: siteVisits,
                  ),
                  _DetailsTab(lead: lead),
                  _SitePhotosTab(lead: lead),
                  _LazyMarketIntelTab(
                    active: shouldLoadMiTab(3),
                    lead: lead,
                    section: MarketIntelLeadSection.infrastructure,
                  ),
                  _LazyMarketIntelTab(
                    active: shouldLoadMiTab(4),
                    lead: lead,
                    section: MarketIntelLeadSection.landRecords,
                  ),
                  _LazyMarketIntelTab(
                    active: shouldLoadMiTab(5),
                    lead: lead,
                    section: MarketIntelLeadSection.competitorProjects,
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

class _ActionToolbar extends StatelessWidget {
  final ValueChanged<String> onAction;

  const _ActionToolbar({required this.onAction});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.call_outlined, 'Calls'),
      (Icons.location_on_outlined, 'Site visit'),
      (Icons.apartment_outlined, 'Management site visit'),
      (Icons.groups_outlined, 'Meeting'),
      (Icons.gavel_outlined, 'Legal'),
      (Icons.draw_outlined, 'Signed'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: AppColors.purple.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: () => onAction(action.$2),
                  borderRadius: BorderRadius.circular(24),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(action.$1, size: 16, color: AppColors.purple),
                        const SizedBox(width: 6),
                        Text(
                          action.$2,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LeadActionDialog extends StatelessWidget {
  final String actionLabel;
  final IconData icon;
  final String leadId;

  const _LeadActionDialog({
    required this.actionLabel,
    required this.icon,
    required this.leadId,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: context.fomraSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: AppColors.purple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          actionLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                        Text(
                          'Lead #$leadId',
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
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.fomraSurfaceVar.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.fomraBorder),
                ),
                child: Text(
                  'Action window ready. Tell me what fields or actions to add here.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: context.fomraTextSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitySummaryRow extends StatelessWidget {
  final int siteVisitCount;
  final CallActivityMetrics callMetrics;

  const _ActivitySummaryRow({
    required this.siteVisitCount,
    required this.callMetrics,
  });

  @override
  Widget build(BuildContext context) {
    final cells = [
      ('Conducted\nSite Visits', '$siteVisitCount'),
      ('Outgoing\nNot Answered', '${callMetrics.outgoingNotAnswered}'),
      ('Outgoing\nAnswered', '${callMetrics.outgoingAnswered}'),
      ('Incoming\nNot Answered', '${callMetrics.incomingNotAnswered}'),
      ('Incoming\nAnswered', '${callMetrics.incomingAnswered}'),
    ];

    return Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: context.fomraSurfaceVar.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.fomraBorder),
              ),
              child: Column(
                children: [
                  Text(
                    cells[i].$1,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: context.fomraTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cells[i].$2,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: i == 0
                          ? AppColors.purple
                          : context.fomraTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  final LandLead lead;
  final List<LeadCallLog> callLogs;
  final List<LandLeadSiteVisit> siteVisits;

  const _ActivityTimeline({
    required this.lead,
    required this.callLogs,
    required this.siteVisits,
  });

  @override
  Widget build(BuildContext context) {
    final events = <({String title, String subtitle, IconData icon})>[];

    for (final log in callLogs) {
      final outcome = log.isAnswered ? 'Answered' : 'Not answered';
      final subtitleParts = [
        _formatReceivedOn(log.calledAt),
        '$outcome · ${log.duration} min',
        if (log.details.isNotEmpty) log.details,
      ];
      events.add((
        title: '${log.direction.label} call',
        subtitle: subtitleParts.join('\n'),
        icon: log.direction == CallDirection.outgoing
            ? Icons.call_made_outlined
            : Icons.call_received_outlined,
      ));
    }

    for (final visit in siteVisits) {
      events.add((
        title: 'Site visit conducted',
        subtitle: visit.loggedByName.isEmpty
            ? _formatReceivedOn(visit.visitedAt)
            : '${_formatReceivedOn(visit.visitedAt)}\n${visit.loggedByName}',
        icon: Icons.location_on_outlined,
      ));
    }

    events.addAll([
      (
        title: 'Current stage',
        subtitle: lead.status.label,
        icon: Icons.flag_outlined,
      ),
      if (lead.createdByName.isNotEmpty)
        (
          title: lead.ownershipLabel,
          subtitle: lead.createdByName,
          icon: Icons.person_outline,
        ),
      (
        title: 'Lead created',
        subtitle: _formatReceivedOn(lead.addedOn),
        icon: Icons.add_circle_outline,
      ),
    ]);

    return ListView(
      children: [
        Text(
          'History',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.fomraTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(e.icon, size: 18, color: AppColors.purple),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        e.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final LandLead lead;
  const _DetailsTab({required this.lead});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Owner', lead.ownerName),
      if (lead.contactDetails.isNotEmpty) ('Contact', lead.contactDetails),
      ('Input Source', lead.inputSource.label),
      ('Land Type', lead.landType.label),
      ('Status', lead.status.label),
      ('Location', lead.location),
      if (lead.village.isNotEmpty) ('Village', lead.village),
      if (lead.taluk.isNotEmpty) ('Taluk', lead.taluk),
      if (lead.district.isNotEmpty) ('District', lead.district),
      if (lead.pincode.isNotEmpty) ('Pincode', lead.pincode),
      if (lead.gpsCoordinates.isNotEmpty) ('GPS', lead.gpsCoordinates),
      if (lead.surveyNumber.isNotEmpty) ('Survey No.', lead.surveyNumber),
      if (lead.subDivision.isNotEmpty) ('Sub Division', lead.subDivision),
      if (lead.landExtent.isNotEmpty) ('Land Extent', lead.landExtent),
      if (lead.roadWidth.isNotEmpty) ('Road Width', lead.roadWidth),
      if (lead.accessDetails.isNotEmpty) ('Terms', lead.accessDetails),
      if (lead.createdByName.isNotEmpty)
        (lead.ownershipLabel, lead.createdByName),
    ];

    return ListView(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    row.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.fomraTextSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.$2,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SitePhotosTab extends StatelessWidget {
  static const _thumbSize = 96.0;

  final LandLead lead;
  const _SitePhotosTab({required this.lead});

  @override
  Widget build(BuildContext context) {
    final urls = _sitePhotoUrls(lead);
    if (urls.isEmpty) {
      return Center(
        child: Text(
          'No site photos uploaded',
          style: TextStyle(color: context.fomraTextSecondary),
        ),
      );
    }
    return Align(
      alignment: Alignment.topLeft,
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < urls.length; i++)
              _SitePhotoThumbnail(
                url: urls[i],
                size: _thumbSize,
                onTap: () => _showSitePhotoLightbox(context, urls[i]),
              ),
          ],
        ),
      ),
    );
  }
}

class _SitePhotoThumbnail extends StatelessWidget {
  final String url;
  final double size;
  final VoidCallback onTap;

  const _SitePhotoThumbnail({
    required this.url,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.fomraBorder),
            boxShadow: AppColors.cardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ColoredBox(
              color: context.fomraSurfaceVar,
              child: Icon(
                Icons.broken_image_outlined,
                color: context.fomraTextSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showSitePhotoLightbox(BuildContext context, String url) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: context.fomraSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(ctx).width - 48,
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Padding(
                  padding: const EdgeInsets.all(48),
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: context.fomraTextSecondary,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => Navigator.pop(ctx),
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StageStatusField extends StatelessWidget {
  final LeadStatus status;
  final ValueChanged<LeadStatus?> onStatusChanged;

  const _StageStatusField({
    required this.status,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STAGE & STATUS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: context.fomraTextSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: status.color.withValues(alpha: 0.45),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<LeadStatus>(
              value: status,
              isExpanded: true,
              items: leadStatusPipelineOrder
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 5,
                            backgroundColor: s.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onStatusChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _LeadInfoGrid extends StatelessWidget {
  final LandLead lead;
  final int leadAgeDays;

  const _LeadInfoGrid({required this.lead, required this.leadAgeDays});

  @override
  Widget build(BuildContext context) {
    final pairs = <(String, String)>[
      ('Area', lead.landExtent.isEmpty ? '—' : lead.landExtent),
      ('Survey Number', lead.surveyNumber.isEmpty ? '—' : lead.surveyNumber),
      ('Input Source', lead.inputSource.label),
      ('Land Type', lead.landType.label),
      ('Received On', _formatReceivedOn(lead.addedOn)),
      ('Lead Age', '$leadAgeDays days'),
      ('Tags', '${lead.landType.label}, ${lead.inputSource.label}'),
      ('Posted By', lead.createdByName.isEmpty ? '—' : lead.createdByName),
      ('Owner Name', lead.ownerName.trim().isEmpty ? '—' : lead.ownerName.trim()),
      (
        'Project Interest',
        lead.village.isEmpty ? lead.location : lead.village,
      ),
      (
        'Contact Details',
        lead.contactDetails.isEmpty ? '—' : lead.contactDetails,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 4; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MetaCell(label: pairs[i].$1, value: pairs[i].$2),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetaCell(
                    label: pairs[i + 1].$1,
                    value: pairs[i + 1].$2,
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _MetaCell(
            label: 'Current Date & Time',
            value: _formatReceivedOn(DateTime.now()),
          ),
        ),
        for (var i = 4; i < pairs.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MetaCell(label: pairs[i].$1, value: pairs[i].$2),
                ),
                const SizedBox(width: 12),
                if (i + 1 < pairs.length)
                  Expanded(
                    child: _MetaCell(
                      label: pairs[i + 1].$1,
                      value: pairs[i + 1].$2,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetaCell extends StatelessWidget {
  final String label;
  final String value;

  const _MetaCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.fomraBorder.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.45,
              color: context.fomraTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
              color: context.fomraTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LazyMarketIntelTab extends StatelessWidget {
  final bool active;
  final LandLead lead;
  final MarketIntelLeadSection section;

  const _LazyMarketIntelTab({
    required this.active,
    required this.lead,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    if (!active) {
      return Center(
        child: Text(
          'Open this tab to load Market Intelligence data.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: context.fomraTextSecondary,
          ),
        ),
      );
    }

    return MarketIntelligenceScreen(
      lead: lead,
      embeddedInLead: true,
      leadSectionOnly: section,
    );
  }
}

List<String> _sitePhotoUrls(LandLead lead) {
  if (lead.sitePhotoUrls.isNotEmpty) return lead.sitePhotoUrls;
  if (lead.sitePhotoUrl.isNotEmpty) return [lead.sitePhotoUrl];
  return const [];
}
