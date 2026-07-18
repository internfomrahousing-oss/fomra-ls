import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/land_lead.dart';
import '../../models/land_lead_legal_document.dart';
import '../../models/land_lead_meeting.dart';
import '../../models/land_lead_site_visit.dart';
import '../../models/lead_call_log.dart';
import '../../services/app_store.dart';
import '../../services/auth_service.dart';
import '../../services/role_access.dart';
import '../../services/lead_drop_approval_service.dart';
import '../../services/lead_drop_reason_catalog_service.dart';
import '../../services/land_lead_legal_service.dart';
import '../../services/land_lead_meeting_service.dart';
import '../../services/land_lead_service.dart';
import '../../services/nearby_features_service.dart';
import '../../utils/lead_auto_notes.dart';
import '../../utils/lead_location_parser.dart';
import '../../services/land_lead_site_visit_service.dart';
import '../../services/lead_call_log_service.dart';
import '../../services/voice_note_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/ui/app_feedback.dart';
import '../../utils/employee_lead_next_action.dart';
import '../../utils/maps_navigation.dart';
import '../../widgets/employee_lead_workflow_ui.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/offline_status_banner.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/ui/app_components.dart';
import '../market_intelligence/market_intelligence_screen.dart';
import '../task_management/task_management_screen.dart';
import 'add_lead_screen.dart';
import 'calls_log_dialog.dart';
import 'lead_drop_reason_dialog.dart';
import 'legal_documents_dialog.dart';
import 'meeting_log_dialog.dart';
import 'notes_log_dialog.dart';
import 'signed_project_dialog.dart';
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

  const LeadDetailScreen({
    super.key,
    required this.lead,
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
  List<LandLeadMeeting> _meetings = [];
  List<LandLeadLegalDocument> _legalDocs = [];

  /// Competitor Projects sits beside Land Records, but only management may see
  /// it — an executive, RM or Head never gets the tab at all.
  static List<String> get _tabs => [
        'Activity',
        'Site Photos',
        'Infrastructure',
        'Land Records',
        if (AuthService.instance.isManagement) 'Competitor Projects',
      ];

  static const _miTabStart = 2;
  final Set<int> _loadedMiTabs = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadActivityData();
    _refreshAutoNotes();
  }

  /// Fetches what's around the site's GPS and folds it into the lead's notes as
  /// an auto-generated block, leaving manual notes untouched.
  ///
  /// Best-effort and silent: the site GPS may be missing, the device offline, or
  /// Overpass unavailable — none of which should interrupt viewing the lead. The
  /// write is skipped entirely when the surroundings haven't changed, so simply
  /// opening a lead repeatedly costs nothing.
  Future<void> _refreshAutoNotes() async {
    final at = parseLeadGps(lead.gpsCoordinates);
    if (at == null) return;
    try {
      final nearby = await NearbyFeaturesService.fetch(at);
      if (!mounted) return;
      final merged = LeadAutoNotes.mergeInto(
        lead.notes,
        LeadAutoNotes.generate(
          nearby,
          radiusKm: NearbyFeaturesService.notesRadiusKm,
        ),
      );
      if (identical(merged, lead.notes)) return;

      final saved = await LandLeadService.update(lead.copyWith(notes: merged));
      if (!mounted) return;
      AppStore.instance.replaceLead(saved);
      setState(() => lead = saved);
    } catch (_) {
      // Leave the existing notes as they are.
    }
  }

  Future<void> _loadActivityData() async {
    try {
      final results = await Future.wait([
        LeadCallLogService.getForLead(lead.leadId),
        LandLeadSiteVisitService.getAllForLead(lead.leadId),
        LandLeadMeetingService.getForLead(lead.leadId),
        LandLeadLegalService.getDocuments(lead.leadId),
      ]);
      if (!mounted) return;
      setState(() {
        _callLogs = results[0] as List<LeadCallLog>;
        _siteVisits = results[1] as List<LandLeadSiteVisit>;
        _meetings = results[2] as List<LandLeadMeeting>;
        _legalDocs = results[3] as List<LandLeadLegalDocument>;
      });
    } catch (_) {
      // Tables may not exist yet — keep counts at zero.
      try {
        final results = await Future.wait([
          LeadCallLogService.getForLead(lead.leadId),
          LandLeadSiteVisitService.getAllForLead(lead.leadId),
        ]);
        if (!mounted) return;
        setState(() {
          _callLogs = results[0] as List<LeadCallLog>;
          _siteVisits = results[1] as List<LandLeadSiteVisit>;
        });
      } catch (_) {}
    }
  }

  EmployeeLeadWorkflowInsight get _workflowInsight =>
      EmployeeLeadWorkflow.build(
        lead: lead,
        callLogs: _callLogs,
        siteVisits: _siteVisits,
        meetings: _meetings,
        legalDocCount: _legalDocs.length,
      );

  /// Opens the tab where the pending activity is logged, so the card is a
  /// shortcut to doing the thing it asks for.
  void _onNextActionTap() {
    switch (_workflowInsight.nextAction.kind) {
      case EmployeeNextActionKind.callOwner:
        _handleDetailAction('Calls');
        break;
      case EmployeeNextActionKind.landOwnerMeeting:
        _handleDetailAction('Meeting');
        break;
      case EmployeeNextActionKind.siteVisit:
      case EmployeeNextActionKind.managementSiteVisit:
        _handleDetailAction('Site visit');
        break;
      case EmployeeNextActionKind.legalVerification:
      case EmployeeNextActionKind.projectSigning:
        _handleDetailAction('Legal');
        break;
      case EmployeeNextActionKind.none:
        break;
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

  /// Management has unrestricted view/edit access to every lead regardless of
  /// owner, so nothing on the lead detail is read-only.
  bool get _readOnly => false;

  /// A Signed/Dropped lead is terminal — locked to view-only for everyone.
  bool get _isLocked => lead.status.isTerminal;

  /// Whether the page should render without any editing affordances.
  bool get _viewOnly => _readOnly || _isLocked;

  /// Edit Lead + full modifications for employees on their own leads and
  /// management on every lead — but never once the lead is locked.
  bool get _canEditSite => RoleAccess.canEdit && !_isLocked;

  CallActivityMetrics get _callMetrics =>
      CallActivityMetrics.fromLogs(_callLogs);

  Future<void> _openEdit() async {
    if (!_canEditSite) return;
    final saved = await Navigator.push<LandLead>(
      context,
      MaterialPageRoute(builder: (_) => AddLeadScreen(existingLead: lead)),
    );
    if (saved == null || !mounted) return;

    AppStore.instance.replaceLead(saved);
    setState(() => lead = saved);
    if (mounted) {
      AppFeedback.success(context, 'Lead updated');
    }
  }

  Future<void> _changeStatus(LeadStatus? status) async {
    if (status == null || status == lead.status) return;
    if (_isLocked) {
      if (!mounted) return;
      AppFeedback.info(
        context,
        'This lead is already ${lead.status.label} and can no longer be modified.',
      );
      return;
    }
    if (_readOnly) {
      if (!mounted) return;
      AppFeedback.info(context,
          'Management view is read-only. Sign in as employee to update status.');
      return;
    }

    // Signing is approval-gated: employees submit a Project Signed request and
    // the lead only becomes Signed once management approves it.
    if (status == LeadStatus.signed) {
      _handleDetailAction('Signed');
      return;
    }

    if (status == LeadStatus.dropped) {
      final result = await showLeadDropReasonDialog(context);
      if (result == null || !mounted) return;
      try {
        await LeadDropApprovalService.submit(
          leadId: lead.leadId,
          reason: result.reason,
          notes: result.notes,
        );
        if (!mounted) return;
        AppFeedback.info(context, 'Drop request submitted for approval');
      } catch (_) {
        if (!mounted) return;
        AppFeedback.error(context, 'Could not submit drop request');
      }
      return;
    }

    final previous = lead.status;
    final previousDropReason = lead.dropReason;
    final previousDropNotes = lead.dropNotes;
    final updated = lead.copyWith(
      status: status,
      dropReason: '',
      dropNotes: '',
    );
    setState(() => lead = updated);
    AppStore.instance.replaceLead(updated);
    try {
      await LandLeadService.updateStatus(
        lead.leadId,
        status,
        previousStatus: previous,
      );
      if (!mounted) return;
      AppFeedback.success(context, 'Status updated to ${status.label}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        lead = lead.copyWith(
          status: previous,
          dropReason: previousDropReason,
          dropNotes: previousDropNotes,
        );
      });
      AppStore.instance.replaceLead(lead);
      AppFeedback.error(context, 'Could not update status: $e');
    }
  }

  Future<void> _launchContact(String scheme) async {
    if (_readOnly) return;
    final raw = lead.contactDetails.replaceAll(RegExp(r'[^\d+]'), '');
    if (raw.isEmpty) {
      AppFeedback.warning(context, 'No contact number on this lead');
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
        AppFeedback.error(context, 'Could not open contact action');
      }
    }
  }

  Future<void> _openCreateTask() async {
    await showCreateTaskSheet(
      context,
      leadId: lead.leadId,
      leadLabel: lead.ownerName.trim().isNotEmpty ? lead.ownerName.trim() : null,
    );
    if (mounted) setState(() {});
  }

  Future<void> _openViewTasks() async {
    await showLeadTasksSheet(
      context,
      leadId: lead.leadId,
      leadLabel: lead.ownerName.trim().isNotEmpty ? lead.ownerName.trim() : null,
    );
    if (mounted) setState(() {});
  }

  Future<void> _navigateToProperty() async {
    final ok = await MapsNavigation.navigateFromGpsString(
      lead.gpsCoordinates,
      label: lead.ownerName.trim().isNotEmpty
          ? lead.ownerName.trim()
          : 'Lead ${lead.leadId}',
    );
    if (!ok && mounted) {
      AppFeedback.warning(context, 'No GPS coordinates available to navigate');
    }
  }

  bool _isViewOnlyAction(String label) {
    // A locked (Signed/Dropped) lead opens every activity dialog read-only —
    // history stays visible, but nothing new can be logged.
    if (_isLocked) return true;
    return _readOnly && label != 'Management site visit';
  }

  void _handleDetailAction(String label) {
    _showActionDialog(label);
  }

  Future<void> _showActionDialog(String label) async {
    final viewOnly = _isViewOnlyAction(label);
    if (label == 'Calls') {
      await showFomraDialog<void>(
        context: context,
        builder: (ctx) => CallsLogDialog(
          leadId: lead.leadId,
          ownerName: lead.ownerName,
          readOnly: viewOnly,
        ),
      );
      await _loadActivityData();
      return;
    }

    if (label == 'Site visit') {
      await showFomraDialog<void>(
        context: context,
        builder: (ctx) => SiteVisitDialog(
          leadId: lead.leadId,
          readOnly: viewOnly,
          onVisitDone: viewOnly
              ? null
              : () {
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
      await showFomraDialog<void>(
        context: context,
        builder: (ctx) => SiteVisitDialog.management(
          leadId: lead.leadId,
        ),
      );
      await _loadActivityData();
      return;
    }

    if (label == 'Meeting') {
      await showFomraDialog<void>(
        context: context,
        builder: (ctx) => MeetingLogDialog(
          leadId: lead.leadId,
          ownerName: lead.ownerName,
          readOnly: viewOnly,
          onMeetingSaved: viewOnly
              ? null
              : () {
                  if (lead.status == LeadStatus.prospectMeetingPending) {
                    _changeStatus(LeadStatus.prospectMeetingCompleted);
                  }
                },
        ),
      );
      return;
    }

    if (label == 'Notes') {
      await showFomraDialog<void>(
        context: context,
        builder: (ctx) => NotesLogDialog(
          lead: lead,
          readOnly: viewOnly,
          onSaved: viewOnly
              ? null
              : (saved) {
                  AppStore.instance.replaceLead(saved);
                  setState(() => lead = saved);
                },
        ),
      );
      return;
    }

    if (label == 'Legal') {
      await showFomraDialog<void>(
        context: context,
        builder: (ctx) => LegalDocumentsDialog(
          leadId: lead.leadId,
          readOnly: viewOnly,
        ),
      );
      await _loadActivityData();
      return;
    }

    if (label == 'Signed') {
      if (viewOnly) {
        AppFeedback.info(context,
            'Management view is read-only. Sign in as employee to submit.');
        return;
      }
      final submitted = await showFomraDialog<bool>(
        context: context,
        builder: (ctx) => SignedProjectDialog(leadId: lead.leadId),
      );
      if (submitted == true) {
        await _loadActivityData();
        if (mounted) {
          AppFeedback.info(context,
              'Submitted — awaiting management approval before the lead is marked Signed.');
        }
      }
      return;
    }

    final icon = switch (label) {
      'Calls' => Icons.call_outlined,
      'Site visit' => Icons.location_on_outlined,
      'Management site visit' => Icons.apartment_outlined,
      'Meeting' => Icons.groups_outlined,
      'Legal' => Icons.gavel_outlined,
      'Signed' => Icons.check_circle,
      _ => Icons.touch_app_outlined,
    };

    await showFomraDialog<void>(
      context: context,
      builder: (ctx) => _LeadActionDialog(
        actionLabel: label,
        icon: icon,
        leadId: lead.leadId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workspace = _WorkspacePanel(
      lead: lead,
      readOnly: _viewOnly,
      readOnlyNote: _isLocked
          ? 'This lead is ${lead.status.label} and locked. Everything below is '
              'view-only — open an activity to see its full history.'
          : 'View-only for management. Tap an activity to open its full history.',
      tabController: _tabController,
      tabs: _tabs,
      siteVisitCount: _siteVisits.length,
      callMetrics: _callMetrics,
      callLogs: _callLogs,
      siteVisits: _siteVisits,
      meetings: _meetings,
      legalDocs: _legalDocs,
      onDetailAction: _handleDetailAction,
      shouldLoadMiTab: _shouldLoadMiTab,
      guidanceBanner: _viewOnly
          ? null
          : EmployeeLeadGuidanceBanners(
              insight: _workflowInsight,
              onOpenTasks: _openViewTasks,
              onNextActionTap: _onNextActionTap,
            ),
    );

    return FomraAppShell(
      currentRoute: '/land-lead',
      backgroundColor: context.fomraPageBg,
      // The standard app header (search, notification bell, view scope, theme,
      // profile) with the module breadcrumb below it — the same one every other
      // page uses. Editing the site moves into the header actions.
      appBar: FomraAppBar(
        moduleName: 'Lead Details',
        breadcrumbs: FomraBreadcrumbs.under(
          const [FomraBreadcrumbs.landWorkspace],
          'Lead Details',
        ),
        actions: [
          if (_canEditSite)
            IconButton(
              onPressed: _openEdit,
              tooltip: 'Edit lead',
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OfflineStatusBanner(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Stack(
                      children: [
                        wide
                            ? SingleChildScrollView(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _ProfilePanel(
                                        lead: lead,
                                        displayName: _displayName,
                                        leadAgeDays: _leadAgeDays,
                                        taskCount:
                                            taskCountForLead(lead.leadId),
                                        readOnly: _viewOnly,
                                        onStatusChanged: _changeStatus,
                                        onCreateTask: _openCreateTask,
                                        onViewTasks: _openViewTasks,
                                        onNavigate:
                                            lead.gpsCoordinates.trim().isEmpty
                                                ? null
                                                : _navigateToProperty,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: workspace,
                                    ),
                                  ],
                                ),
                              )
                            : ListView(
                                children: [
                                  _ProfilePanel(
                                    lead: lead,
                                    displayName: _displayName,
                                    leadAgeDays: _leadAgeDays,
                                    taskCount: taskCountForLead(lead.leadId),
                                    readOnly: _viewOnly,
                                    onStatusChanged: _changeStatus,
                                    onCreateTask: _openCreateTask,
                                    onViewTasks: _openViewTasks,
                                  ),
                                  const SizedBox(height: 12),
                                  workspace,
                                ],
                              ),
                        if (!_viewOnly)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: EmployeeLeadQuickFab(
                              lead: lead,
                              onLaunchContact: _launchContact,
                              onDetailAction: _handleDetailAction,
                              onLeadUpdated: (updated) {
                                AppStore.instance.replaceLead(updated);
                                setState(() => lead = updated);
                              },
                              onActivityChanged: _loadActivityData,
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

class _ProfilePanel extends StatelessWidget {
  final LandLead lead;
  final String displayName;
  final int leadAgeDays;
  final int taskCount;
  final bool readOnly;
  final ValueChanged<LeadStatus?> onStatusChanged;
  final VoidCallback onCreateTask;
  final VoidCallback onViewTasks;
  final VoidCallback? onNavigate;

  const _ProfilePanel({
    required this.lead,
    required this.displayName,
    required this.leadAgeDays,
    required this.taskCount,
    this.readOnly = false,
    required this.onStatusChanged,
    required this.onCreateTask,
    required this.onViewTasks,
    this.onNavigate,
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
          boxShadow: context.fomraCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
                          if (onNavigate != null) ...[
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: onNavigate,
                                icon: const Icon(Icons.place_outlined, size: 16),
                                label: const Text('Navigate'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.purple,
                                  side: BorderSide(
                                      color: AppColors.purple
                                          .withValues(alpha: 0.4)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        InkWell(
                          onTap: onViewTasks,
                          borderRadius: BorderRadius.circular(14),
                          child: _LeadTaskCountBadge(count: taskCount),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 118,
                          child: FilledButton.icon(
                            onPressed: onCreateTask,
                            icon: const Icon(Icons.add_task_outlined, size: 14),
                            label: const Text('Create'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 118,
                          child: OutlinedButton.icon(
                            onPressed: onViewTasks,
                            icon: const Icon(Icons.list_alt_outlined, size: 14),
                            label: const Text('View Tasks'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              textStyle: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              side: BorderSide(
                                color: AppColors.primary.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                      readOnly: readOnly,
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
                    _LeadDetailsList(lead: lead, leadAgeDays: leadAgeDays),
                  ],
                ),
              ),
            ],
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

class _LeadTaskCountBadge extends StatelessWidget {
  final int count;

  const _LeadTaskCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
      ),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.task_alt_outlined,
              size: 17,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count == 1 ? 'Task' : 'Tasks',
            style: TextStyle(
              fontSize: 10,
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
  final bool readOnly;
  final TabController tabController;
  final List<String> tabs;
  final int siteVisitCount;
  final CallActivityMetrics callMetrics;
  final List<LeadCallLog> callLogs;
  final List<LandLeadSiteVisit> siteVisits;
  final List<LandLeadMeeting> meetings;
  final List<LandLeadLegalDocument> legalDocs;
  final ValueChanged<String> onDetailAction;
  final bool Function(int tabIndex) shouldLoadMiTab;
  final Widget? guidanceBanner;
  final String readOnlyNote;

  const _WorkspacePanel({
    required this.lead,
    this.readOnly = false,
    this.readOnlyNote =
        'View-only for management. Tap an activity to open its full history.',
    required this.tabController,
    required this.tabs,
    required this.siteVisitCount,
    required this.callMetrics,
    required this.callLogs,
    required this.siteVisits,
    this.meetings = const [],
    this.legalDocs = const [],
    required this.onDetailAction,
    required this.shouldLoadMiTab,
    this.guidanceBanner,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: context.fomraSurface,
          border: Border.all(color: context.fomraBorder),
          boxShadow: context.fomraCardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (guidanceBanner != null) ...[
              guidanceBanner!,
              const SizedBox(height: 12),
            ],
            if (!readOnly) ...[
              // Call / WhatsApp live in the Quick Actions FAB only — the
              // standalone header icons were removed to cut duplication.
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
            ] else ...[
              Text(
                'ACTIVITY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: context.fomraTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                readOnlyNote,
                style: TextStyle(
                  fontSize: 12,
                  color: context.fomraTextSecondary,
                ),
              ),
              const SizedBox(height: 10),
              _ActionToolbar(onAction: onDetailAction),
              const SizedBox(height: 16),
            ],
            _ActivitySummaryRow(
              siteVisitCount: siteVisitCount,
              callMetrics: callMetrics,
            ),
            const SizedBox(height: 14),
            if (readOnly) ...[
              _ActivityTimeline(
                lead: lead,
                callLogs: callLogs,
                siteVisits: siteVisits,
                meetings: meetings,
                legalDocs: legalDocs,
              ),
            ] else ...[
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
                    boxShadow: context.fomraCardShadow,
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
              // Render only the active tab at its natural height so the whole
              // page shares a single scroll (no inner tab scroll view).
              AnimatedBuilder(
                animation: tabController,
                builder: (context, _) {
                  switch (tabController.index) {
                    case 0:
                      return _ActivityTimeline(
                        lead: lead,
                        callLogs: callLogs,
                        siteVisits: siteVisits,
                        meetings: meetings,
                        legalDocs: legalDocs,
                      );
                    case 1:
                      return _SitePhotosTab(lead: lead);
                    case 2:
                      return _LazyMarketIntelTab(
                        active: shouldLoadMiTab(2),
                        lead: lead,
                        section: MarketIntelLeadSection.infrastructure,
                        scrollable: false,
                      );
                    case 3:
                      return _LazyMarketIntelTab(
                        active: shouldLoadMiTab(3),
                        lead: lead,
                        section: MarketIntelLeadSection.landRecords,
                        scrollable: false,
                      );
                    default:
                      // Only reachable for management: the tab isn't built for
                      // anyone else.
                      return _LazyMarketIntelTab(
                        active: shouldLoadMiTab(4),
                        lead: lead,
                        section: MarketIntelLeadSection.competitorProjects,
                        scrollable: false,
                      );
                  }
                },
              ),
            ],
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
      (Icons.sticky_note_2_outlined, 'Notes', AppColors.purple),
      (Icons.call_outlined, 'Calls', AppColors.purple),
      (Icons.location_on_outlined, 'Site visit', AppColors.purple),
      (Icons.apartment_outlined, 'Management site visit', AppColors.purple),
      (Icons.groups_outlined, 'Meeting', AppColors.purple),
      (Icons.gavel_outlined, 'Legal', AppColors.purple),
      (Icons.draw_outlined, 'Signed', AppColors.purple),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: action.$3.withValues(alpha: 0.07),
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
                        Icon(action.$1, size: 16, color: action.$3),
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
      (label: 'Conducted\nSite Visits', value: '$siteVisitCount', icon: Icons.location_on_outlined, color: AppColors.purple),
      (label: 'Outgoing\nNot Answered', value: '${callMetrics.outgoingNotAnswered}', icon: CallOutcome.notAnswered.icon, color: AppColors.warning),
      (label: 'Outgoing\nAnswered', value: '${callMetrics.outgoingAnswered}', icon: CallOutcome.answered.icon, color: AppColors.success),
      (label: 'Incoming\nNot Answered', value: '${callMetrics.incomingNotAnswered}', icon: CallOutcome.notAnswered.icon, color: AppColors.warning),
      (label: 'Incoming\nAnswered', value: '${callMetrics.incomingAnswered}', icon: CallOutcome.answered.icon, color: AppColors.success),
    ];

    Widget cell(int i) => Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: context.fomraSurfaceVar.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.fomraBorder),
          ),
          child: Column(
            children: [
              Icon(cells[i].icon, size: 18, color: cells[i].color),
              const SizedBox(height: 6),
              Text(
                cells[i].label,
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
                cells[i].value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: i == 0 ? AppColors.purple : context.fomraTextPrimary,
                ),
              ),
            ],
          ),
        );

    // Mobile web: wrap into rows of three so five cells aren't crushed into one
    // line; tablet/desktop keep the single equal-width row.
    if (FomraLayout.isMobile(context)) {
      const gap = 8.0;
      return LayoutBuilder(
        builder: (context, c) {
          const perRow = 3;
          final w = c.maxWidth.isFinite
              ? (c.maxWidth - gap * (perRow - 1)) / perRow
              : 104.0;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < cells.length; i++)
                SizedBox(width: w, child: cell(i)),
            ],
          );
        },
      );
    }

    return Row(
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: cell(i)),
        ],
      ],
    );
  }
}

enum _ActivityFilter {
  all,
  calls,
  siteVisits,
  managementSiteVisits,
  meetings,
  notes,
}

extension on _ActivityFilter {
  String get label => switch (this) {
        _ActivityFilter.all => 'All',
        _ActivityFilter.calls => 'Calls',
        _ActivityFilter.siteVisits => 'Site Visits',
        _ActivityFilter.managementSiteVisits => 'Management Site Visits',
        _ActivityFilter.meetings => 'Meetings',
        _ActivityFilter.notes => 'Notes',
      };
}

class _ActivityTimeline extends StatefulWidget {
  final LandLead lead;
  final List<LeadCallLog> callLogs;
  final List<LandLeadSiteVisit> siteVisits;
  final List<LandLeadMeeting> meetings;
  final List<LandLeadLegalDocument> legalDocs;

  const _ActivityTimeline({
    required this.lead,
    required this.callLogs,
    required this.siteVisits,
    this.meetings = const [],
    this.legalDocs = const [],
  });

  @override
  State<_ActivityTimeline> createState() => _ActivityTimelineState();
}

class _ActivityTimelineState extends State<_ActivityTimeline> {
  _ActivityFilter _filter = _ActivityFilter.all;

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final callLogs = widget.callLogs;
    final siteVisits = widget.siteVisits;
    final meetings = widget.meetings;

    final events = <({
      DateTime at,
      String title,
      String subtitle,
      IconData icon,
      String? audioUrl,
      _ActivityFilter category,
    })>[];

    for (final log in callLogs) {
      final subtitleParts = [
        _formatReceivedOn(log.calledAt),
        log.outcome.label,
        if (log.isAnswered && log.duration.isNotEmpty) '${log.duration} min',
        if (log.details.isNotEmpty) log.details,
      ];
      events.add((
        at: log.calledAt,
        title: '${log.direction.label} call',
        subtitle: subtitleParts.join('\n'),
        icon: log.outcome.icon,
        audioUrl: null,
        category: _ActivityFilter.calls,
      ));
    }

    for (final visit in siteVisits) {
      final isManagementVisit =
          visit.visitType == LandLeadSiteVisitType.management;
      final approval = isManagementVisit ? '\n${visit.approvalStatus.label}' : '';
      events.add((
        at: visit.visitedAt,
        title: visit.visitType.label,
        subtitle: visit.loggedByName.isEmpty
            ? '${_formatReceivedOn(visit.visitedAt)}$approval'
            : '${_formatReceivedOn(visit.visitedAt)}\n${visit.loggedByName}$approval',
        icon: isManagementVisit
            ? Icons.apartment_outlined
            : Icons.location_on_outlined,
        audioUrl: null,
        category: isManagementVisit
            ? _ActivityFilter.managementSiteVisits
            : _ActivityFilter.siteVisits,
      ));
    }

    for (final meeting in meetings) {
      events.add((
        at: meeting.metAt,
        title: 'Meeting',
        subtitle: [
          _formatReceivedOn(meeting.metAt),
          if (meeting.duration.isNotEmpty) '${meeting.duration} min',
          if (meeting.notes.isNotEmpty) meeting.notes,
          if (meeting.loggedByName.isNotEmpty) meeting.loggedByName,
        ].join('\n'),
        icon: Icons.groups_outlined,
        audioUrl: null,
        category: _ActivityFilter.meetings,
      ));
    }

    // Parse tagged notes (voice / GPS) into timeline entries. The nearby
    // information block is one entry, however many categories it lists.
    for (final entry in LeadAutoNotes.splitEntries(lead.notes)) {
      final isAuto = LeadAutoNotes.isAutoEntry(entry);
      final isVoice = entry.contains('[Voice Note]');
      final isGps = entry.contains('[GPS Check-in]');
      final audioUrl = isVoice
          ? VoiceNoteService.audioUrlFromNotesLine(entry)
          : null;
      events.add((
        at: lead.addedOn,
        title: isVoice
            ? 'Voice note'
            : (isGps
                ? 'GPS check-in'
                : (isAuto ? 'Nearby information' : 'Note')),
        subtitle: entry,
        icon: isVoice
            ? Icons.mic_none_rounded
            : (isGps
                ? Icons.my_location_rounded
                : (isAuto
                    ? Icons.travel_explore_outlined
                    : Icons.notes_outlined)),
        audioUrl: audioUrl,
        category: _ActivityFilter.notes,
      ));
    }

    events.sort((a, b) => b.at.compareTo(a.at));

    final filtered = _filter == _ActivityFilter.all
        ? events
        : events.where((e) => e.category == _filter).toList();

    final staticEvents = <({String title, String subtitle, IconData icon})>[
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
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Activity timeline',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.fomraTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _ActivityFilterBar(
          selected: _filter,
          onSelected: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              events.isEmpty
                  ? 'No activity yet — use quick actions to log the first step.'
                  : 'No ${_filter.label.toLowerCase()} activity yet.',
              style: TextStyle(
                fontSize: 12,
                color: context.fomraTextSecondary,
              ),
            ),
          ),
        for (final e in filtered)
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
                if (e.audioUrl != null && e.audioUrl!.isNotEmpty)
                  IconButton(
                    tooltip: 'Play voice note',
                    icon: const Icon(Icons.play_circle_outline, size: 22),
                    onPressed: () async {
                      final player = AudioPlayer();
                      await player.play(UrlSource(e.audioUrl!));
                    },
                  ),
              ],
            ),
          ),
        if (_filter == _ActivityFilter.all)
          for (final e in staticEvents)
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

class _ActivityFilterBar extends StatelessWidget {
  final _ActivityFilter selected;
  final ValueChanged<_ActivityFilter> onSelected;

  const _ActivityFilterBar({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _ActivityFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = _ActivityFilter.values[i];
          final isSelected = f == selected;
          return ChoiceChip(
            label: Text(f.label),
            selected: isSelected,
            onSelected: (_) => onSelected(f),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : context.fomraTextSecondary,
            ),
            backgroundColor: context.fomraSurfaceVar.withValues(alpha: 0.7),
            selectedColor: AppColors.purple,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }
}

class _LeadDetailsList extends StatelessWidget {
  final LandLead lead;
  final int leadAgeDays;

  const _LeadDetailsList({
    required this.lead,
    required this.leadAgeDays,
  });

  String _value(String raw) => raw.trim().isEmpty ? '—' : raw.trim();

  @override
  Widget build(BuildContext context) {
    final ownerRows = <(String, String)>[
      ('Owner', _value(lead.ownerName)),
      ('Contact', _value(lead.contactDetails)),
      ('Input Source', lead.inputSource.label),
      if (lead.createdByName.isNotEmpty)
        (lead.ownershipLabel, lead.createdByName),
    ];

    final locationRows = <(String, String)>[
      ('Location', _value(lead.location)),
      ('Village', _value(lead.village)),
      ('Taluk', _value(lead.taluk)),
      ('District', _value(lead.district)),
      ('Pincode', _value(lead.pincode)),
    ];

    final landRows = <(String, String)>[
      ('Land Type', lead.landType.label),
      ('Survey No.', _value(lead.surveyNumber)),
      ('Sub Division', _value(lead.subDivision)),
      ('Land Extent', _value(lead.landExtent)),
      if (lead.roadWidth.isNotEmpty) ('Road Width', lead.roadWidth),
      if (lead.accessDetails.isNotEmpty) ('Terms', lead.accessDetails),
    ];

    final statusRows = <(String, String)>[
      ('Status', lead.status.label),
      if (lead.status == LeadStatus.dropped &&
          lead.dropReason.trim().isNotEmpty)
        (
          'Drop reason',
          LeadDropReasonCatalogService.instance.displayLabelForRaw(lead.dropReason),
        ),
      if (lead.status == LeadStatus.dropped &&
          lead.dropNotes.trim().isNotEmpty)
        ('Drop notes', lead.dropNotes.trim()),
      ('Received On', _formatReceivedOn(lead.addedOn)),
      ('Lead Age', '$leadAgeDays days'),
      ("Lead's Current Date & Time", _formatReceivedOn(DateTime.now())),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LeadDetailsGroup(title: 'Owner & Contact', rows: ownerRows),
        const SizedBox(height: 18),
        _LeadDetailsGroup(title: 'Location', rows: locationRows),
        const SizedBox(height: 18),
        _LeadDetailsGroup(title: 'Land Details', rows: landRows),
        const SizedBox(height: 18),
        _LeadDetailsGroup(title: 'Status & Timeline', rows: statusRows),
      ],
    );
  }
}

class _LeadDetailsGroup extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;

  const _LeadDetailsGroup({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: context.fomraTextSecondary,
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final useTwoColumns = constraints.maxWidth >= 360;
            if (!useTwoColumns) {
              return _LeadDetailsColumn(rows: rows);
            }
            final split = (rows.length / 2).ceil();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _LeadDetailsColumn(rows: rows.sublist(0, split)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _LeadDetailsColumn(rows: rows.sublist(split)),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LeadDetailsColumn extends StatelessWidget {
  final List<(String, String)> rows;

  const _LeadDetailsColumn({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LeadDetailRow(label: row.$1, value: row.$2),
          ),
      ],
    );
  }
}

class _LeadDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _LeadDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.fomraTextSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              color: context.fomraTextPrimary,
            ),
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
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < urls.length; i++)
            _SitePhotoThumbnail(
              url: urls[i],
              size: _thumbSize,
              onTap: () => _showSitePhotoLightbox(context, urls[i]),
              onDownload: () => _downloadSitePhoto(context, urls[i]),
            ),
        ],
      ),
    );
  }
}

class _SitePhotoThumbnail extends StatelessWidget {
  final String url;
  final double size;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _SitePhotoThumbnail({
    required this.url,
    required this.size,
    required this.onTap,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.fomraBorder),
                    boxShadow: context.fomraCardShadow,
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
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onDownload,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(5),
                  child: Icon(
                    Icons.download_rounded,
                    size: 15,
                    color: Colors.white,
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

/// Downloads a site photo. Supabase Storage honours a `download` query param
/// by serving the file as an attachment, so the existing public URL is reused
/// rather than re-fetching the bytes.
Future<void> _downloadSitePhoto(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  final withDownload = uri.replace(
    queryParameters: {...uri.queryParameters, 'download': ''},
  );
  final ok = await launchUrl(withDownload, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    AppFeedback.error(context, 'Could not download this photo');
  }
}

Future<void> _showSitePhotoLightbox(BuildContext context, String url) {
  return showFomraDialog<void>(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => _downloadSitePhoto(ctx, url),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(
                          Icons.download_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Material(
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
                ],
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
  final bool readOnly;
  final ValueChanged<LeadStatus?> onStatusChanged;

  const _StageStatusField({
    required this.status,
    this.readOnly = false,
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
        if (readOnly)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(
                color: status.color.withValues(alpha: 0.45),
              ),
              borderRadius: BorderRadius.circular(10),
              color: status.color.withValues(alpha: 0.06),
            ),
            child: Row(
              children: [
                CircleAvatar(radius: 5, backgroundColor: status.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          MenuAnchor(
            alignmentOffset: const Offset(0, 4),
            style: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(context.fomraSurface),
              elevation: const WidgetStatePropertyAll(6),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(vertical: 4),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: context.fomraBorder),
                ),
              ),
            ),
            builder: (context, controller, _) {
              return InkWell(
                onTap: () => controller.isOpen
                    ? controller.close()
                    : controller.open(),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: status.color.withValues(alpha: 0.45),
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 5, backgroundColor: status.color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          status.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                      ),
                      Icon(
                        controller.isOpen
                            ? Icons.arrow_drop_up
                            : Icons.arrow_drop_down,
                        color: context.fomraTextSecondary,
                      ),
                    ],
                  ),
                ),
              );
            },
            menuChildren: [
              for (final s in leadStatusPipelineOrder)
                MenuItemButton(
                  onPressed: s == status
                      ? null
                      : () => onStatusChanged(s),
                  leadingIcon: CircleAvatar(
                    radius: 5,
                    backgroundColor: s.color,
                  ),
                  child: Text(
                    s.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _LazyMarketIntelTab extends StatelessWidget {
  final bool active;
  final LandLead lead;
  final MarketIntelLeadSection section;
  final bool scrollable;

  const _LazyMarketIntelTab({
    required this.active,
    required this.lead,
    required this.section,
    this.scrollable = true,
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
      embeddedScrollable: scrollable,
    );
  }
}

List<String> _sitePhotoUrls(LandLead lead) {
  if (lead.sitePhotoUrls.isNotEmpty) return lead.sitePhotoUrls;
  if (lead.sitePhotoUrl.isNotEmpty) return [lead.sitePhotoUrl];
  return const [];
}
