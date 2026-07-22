import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
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
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/offline_status_banner.dart';
import '../../widgets/portal_page_layout.dart';
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

/// Realistic sample activity for the timeline, used ONLY in debug/demo builds
/// when a lead has no real records (see the kDebugMode guard at the call site).
/// Purely local — never persisted — so production data and logic are untouched.
List<
    ({
      DateTime at,
      String title,
      String subtitle,
      IconData icon,
      String? audioUrl,
      _ActivityFilter category,
    })> _demoTimelineEvents(LandLead lead) {
  final now = DateTime.now();
  ({
    DateTime at,
    String title,
    String subtitle,
    IconData icon,
    String? audioUrl,
    _ActivityFilter category,
  }) e(
    int daysAgo,
    String title,
    String employee,
    String status,
    String description,
    IconData icon,
    _ActivityFilter category,
  ) {
    final at = now.subtract(Duration(days: daysAgo, hours: daysAgo));
    return (
      at: at,
      title: title,
      subtitle: [_formatReceivedOn(at), employee, status, description].join('\n'),
      icon: icon,
      audioUrl: null,
      category: category,
    );
  }

  return [
    e(1, 'Outgoing call', 'Arun Kumar', 'Answered · 4 min',
        'Owner confirmed interest and asked to schedule a site visit.',
        Icons.call_outlined, _ActivityFilter.calls),
    e(2, 'Note', 'Priya S', 'Logged',
        'Owner prefers weekend meetings close to the site.',
        Icons.notes_outlined, _ActivityFilter.notes),
    e(3, 'Meeting', 'Arun Kumar', 'Completed · 45 min',
        'Discussed pricing and boundary details with the land owner.',
        Icons.groups_outlined, _ActivityFilter.meetings),
    e(5, 'Site Visit', 'Karthik R', 'Completed',
        'Verified the access road and marked the corner coordinates.',
        Icons.location_on_outlined, _ActivityFilter.siteVisits),
    e(7, 'Management Site Visit', 'Management', 'Approved',
        'Management reviewed the parcel and cleared it for legal checks.',
        Icons.apartment_outlined, _ActivityFilter.managementSiteVisits),
    e(9, 'Legal Update', 'Legal Desk', 'Verified',
        'Patta and Chitta collected; FMB sketch has been requested.',
        Icons.gavel_outlined, _ActivityFilter.notes),
    e(10, 'Task Created', 'Priya S', 'Open',
        'Follow up on the pending EC before starting negotiation.',
        Icons.checklist_rounded, _ActivityFilter.notes),
    e(12, 'Project Signed', 'Arun Kumar', 'Submitted for approval',
        'Signing package submitted and awaiting management approval.',
        Icons.draw_outlined, _ActivityFilter.notes),
  ];
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
        'Photos',
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
    // ── Discrete sections, composed per breakpoint below ────────────────────
    final summary = _LeadSummaryCard(
      lead: lead,
      displayName: _displayName,
      leadAgeDays: _leadAgeDays,
      taskCount: taskCountForLead(lead.leadId),
      readOnly: _viewOnly,
      onStatusChanged: _changeStatus,
      onCreateTask: _openCreateTask,
      onViewTasks: _openViewTasks,
      onEdit: _canEditSite ? _openEdit : null,
      onNavigate:
          lead.gpsCoordinates.trim().isEmpty ? null : _navigateToProperty,
    );

    // Next Action + Due/Overdue/Pending KPIs — only for the working executive.
    final Widget? guidance = _viewOnly
        ? null
        : EmployeeLeadGuidanceBanners(
            insight: _workflowInsight,
            onOpenTasks: _openViewTasks,
            onNextActionTap: _onNextActionTap,
          );

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
      onOpenTasks: _openViewTasks,
      shouldLoadMiTab: _shouldLoadMiTab,
    );

    final infoCards = _LeadInfoCards(lead: lead, leadAgeDays: _leadAgeDays);

    return FomraAppShell(
      currentRoute: '/land-lead',
      backgroundColor: context.fomraPageBg,
      // A drill-down sub-page header with a real Back button, so returning goes
      // to the actual previous page (workspace, map, search, notifications…)
      // instead of always jumping Home. The breadcrumb names the lead itself.
      appBar: FomraSubPageAppBar(
        title: 'Lead #${lead.leadId}',
        subtitle: _displayName == 'Lead #${lead.leadId}' ? null : _displayName,
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
                    // Tighter gutters on phones so cards get more usable width.
                    padding: FomraLayout.isMobile(context)
                        ? const EdgeInsets.fromLTRB(8, 6, 8, 8)
                        : const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Stack(
                      children: [
                        wide
                            // Desktop / tablet: a reference column (summary +
                            // information cards) beside a work column (next
                            // action + KPIs + workspace) so width is filled and
                            // no section leaves a large empty gap.
                            ? SingleChildScrollView(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          summary,
                                          const SizedBox(height: 12),
                                          infoCards,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          if (guidance != null) ...[
                                            guidance,
                                            const SizedBox(height: 12),
                                          ],
                                          workspace,
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            // Mobile: one natural top-to-bottom flow — summary →
                            // next action → KPIs → workspace → information.
                            : ListView(
                                children: [
                                  summary,
                                  if (guidance != null) ...[
                                    const SizedBox(height: 12),
                                    guidance,
                                  ],
                                  const SizedBox(height: 12),
                                  workspace,
                                  const SizedBox(height: 12),
                                  infoCards,
                                ],
                              ),
                        if (!_viewOnly)
                          Positioned(
                            // A roomier margin on phones keeps the FAB clear of
                            // the bottom edge / gesture bar and page content.
                            right: FomraLayout.isMobile(context) ? 16 : 8,
                            bottom: FomraLayout.isMobile(context) ? 20 : 8,
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

/// Compact lead summary header (point 3): identity, stage, location, and the
/// key facts (age / extent / terms / type / executive) as scannable pills, plus
/// the quick actions — all in a short card instead of the old tall hero.
class _LeadSummaryCard extends StatelessWidget {
  final LandLead lead;
  final String displayName;
  final int leadAgeDays;
  final int taskCount;
  final bool readOnly;
  final ValueChanged<LeadStatus?> onStatusChanged;
  final VoidCallback onCreateTask;
  final VoidCallback onViewTasks;
  final VoidCallback? onNavigate;

  /// Edit the lead. Null when the current user can't edit this lead.
  final VoidCallback? onEdit;

  const _LeadSummaryCard({
    required this.lead,
    required this.displayName,
    required this.leadAgeDays,
    required this.taskCount,
    this.readOnly = false,
    required this.onStatusChanged,
    required this.onCreateTask,
    required this.onViewTasks,
    this.onNavigate,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final locationLabel = [
      if (lead.village.trim().isNotEmpty) lead.village.trim(),
      if (lead.district.trim().isNotEmpty) lead.district.trim(),
    ].join(', ');
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '#';

    final metrics = <(String, String)>[
      ('Age', '$leadAgeDays days'),
      ('Extent', lead.landExtent.trim().isEmpty ? '—' : lead.landExtent.trim()),
      if (lead.accessDetails.trim().isNotEmpty) ('Terms', lead.accessDetails.trim()),
      ('Type', lead.landType.label),
      if (lead.createdByName.trim().isNotEmpty)
        ('Executive', lead.createdByName.trim()),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.fomraSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.fomraBorder),
        boxShadow: context.fomraCardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: lead.status.color.withValues(alpha: 0.16),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: lead.status.color,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                        const SizedBox(width: 8),
                        Flexible(child: _StageBadge(status: lead.status)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                    if (locationLabel.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 13, color: context.fomraTextSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              locationLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: context.fomraTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onViewTasks,
                borderRadius: BorderRadius.circular(14),
                child: _LeadTaskCountBadge(count: taskCount),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Compact metric strip — the summary facts, scannable at a glance.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in metrics) _MetricPill(label: m.$1, value: m.$2),
            ],
          ),
          const SizedBox(height: 12),
          // Editable stage keeps the existing status-change workflow intact.
          _StageStatusField(
            status: lead.status,
            readOnly: readOnly,
            onStatusChanged: onStatusChanged,
          ),
          const SizedBox(height: 12),
          // Quick actions — wrap automatically, compact, aligned icons.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onNavigate != null)
                OutlinedButton.icon(
                  onPressed: onNavigate,
                  icon: const Icon(Icons.navigation_outlined, size: 16),
                  label: const Text('Navigate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    side: BorderSide(
                        color: AppColors.purple.withValues(alpha: 0.4)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              if (onEdit != null)
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.4)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              FilledButton.icon(
                onPressed: onCreateTask,
                icon: const Icon(Icons.add_task_outlined, size: 16),
                label: const Text('Create Task'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  final LeadStatus status;
  const _StageBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: status.color,
        ),
      ),
    );
  }
}

/// A single compact "LABEL value" pill used in the summary metric strip.
class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  const _MetricPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.fomraBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: context.fomraTextSecondary,
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 170),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.fomraTextPrimary,
              ),
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
        mainAxisSize: MainAxisSize.min,
        children: [
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
  final VoidCallback onOpenTasks;
  final bool Function(int tabIndex) shouldLoadMiTab;
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
    required this.onOpenTasks,
    required this.shouldLoadMiTab,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: context.fomraSurface,
          border: Border.all(color: context.fomraBorder),
          boxShadow: context.fomraCardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              _ActionToolbar(
                  onAction: onDetailAction, onOpenTasks: onOpenTasks),
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
              _ActionToolbar(
                  onAction: onDetailAction, onOpenTasks: onOpenTasks),
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
              // Modern enterprise segmented tabs — the active segment is a
              // filled accent pill inside a bordered track.
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.fomraSurfaceVar.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.fomraBorder),
                ),
                child: TabBar(
                  controller: tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: context.fomraTextSecondary,
                  indicator: BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  overlayColor:
                      WidgetStatePropertyAll(AppColors.purple.withValues(alpha: 0.08)),
                  labelPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: [for (final t in tabs) Tab(text: t, height: 30)],
                ),
              ),
              const SizedBox(height: 12),
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
  final VoidCallback onOpenTasks;

  const _ActionToolbar({required this.onAction, required this.onOpenTasks});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.sticky_note_2_outlined, 'Notes', AppColors.purple),
      (Icons.call_outlined, 'Calls', AppColors.purple),
      (Icons.location_on_outlined, 'Site visit', AppColors.purple),
      (Icons.apartment_outlined, 'Management site visit', AppColors.purple),
      (Icons.groups_outlined, 'Meeting', AppColors.purple),
      // Tasks opens the task list rather than an activity dialog.
      (Icons.checklist_rounded, 'Tasks', AppColors.purple),
      (Icons.gavel_outlined, 'Legal', AppColors.purple),
      (Icons.draw_outlined, 'Signed', AppColors.purple),
    ];

    Widget pill((IconData, String, Color) action) {
      return Material(
        color: action.$3.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () =>
              action.$2 == 'Tasks' ? onOpenTasks() : onAction(action.$2),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action.$1, size: 16, color: action.$3),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    action.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // One equal-width wrapping grid at every size: 2 columns on phones, more as
    // width allows. Tiles wrap automatically and share a consistent size.
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth.isFinite ? c.maxWidth : 360.0;
        // Aim for ~150px tiles, clamped to 2–4 columns.
        final cols = (maxW / 158).floor().clamp(2, 4);
        final cellW = (maxW - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final action in actions)
              SizedBox(width: cellW, child: pill(action)),
          ],
        );
      },
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

    // Compact stat card: icon + value on one line, label beneath — shorter and
    // easier to scan than the old tall centred cell.
    Widget cell(int i) => Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          decoration: BoxDecoration(
            color: context.fomraSurfaceVar.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.fomraBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(cells[i].icon, size: 15, color: cells[i].color),
                  const SizedBox(width: 6),
                  Text(
                    cells[i].value,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color:
                          i == 0 ? AppColors.purple : context.fomraTextPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                cells[i].label.replaceAll('\n', ' '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: context.fomraTextSecondary,
                ),
              ),
            ],
          ),
        );

    // One responsive grid at every width — all five across on desktop, wrapping
    // to 2–3 columns as space tightens. Cards keep an equal width.
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth.isFinite ? c.maxWidth : 360.0;
        final cols = (maxW / 132).floor().clamp(2, cells.length);
        final w = (maxW - gap * (cols - 1)) / cols;
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

    // Demo/development only: when a lead has no real activity, seed a realistic
    // sample timeline so the page isn't empty in demos. Guarded by kDebugMode,
    // rendered locally and NEVER written to Supabase — zero production impact.
    if (kDebugMode && events.isEmpty) {
      events.addAll(_demoTimelineEvents(lead));
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

/// The lead's reference detail, split into compact, scannable cards (point 8):
/// Owner / Location / Land / Acquisition / Timeline — laid out in a responsive
/// grid instead of one long section.
class _LeadInfoCards extends StatelessWidget {
  final LandLead lead;
  final int leadAgeDays;

  const _LeadInfoCards({
    required this.lead,
    required this.leadAgeDays,
  });

  String _v(String raw) => raw.trim().isEmpty ? '—' : raw.trim();

  @override
  Widget build(BuildContext context) {
    final cards = <({String title, IconData icon, List<(String, String)> rows})>[
      (
        title: 'Owner Information',
        icon: Icons.person_outline,
        rows: [
          ('Owner', _v(lead.ownerName)),
          ('Contact', _v(lead.contactDetails)),
        ],
      ),
      (
        title: 'Location Information',
        icon: Icons.place_outlined,
        rows: [
          ('Location', _v(lead.location)),
          ('Village', _v(lead.village)),
          ('Taluk', _v(lead.taluk)),
          ('District', _v(lead.district)),
          ('Pincode', _v(lead.pincode)),
        ],
      ),
      (
        title: 'Land Information',
        icon: Icons.landscape_outlined,
        rows: [
          ('Land Type', lead.landType.label),
          ('Survey No.', _v(lead.surveyNumber)),
          ('Sub Division', _v(lead.subDivision)),
          ('Land Extent', _v(lead.landExtent)),
          if (lead.roadWidth.trim().isNotEmpty) ('Road Width', lead.roadWidth),
        ],
      ),
      (
        title: 'Acquisition Details',
        icon: Icons.handshake_outlined,
        rows: [
          ('Input Source', lead.inputSource.label),
          if (lead.createdByName.trim().isNotEmpty)
            (lead.ownershipLabel, lead.createdByName.trim()),
          if (lead.brokerName.trim().isNotEmpty) ('Broker', lead.brokerName.trim()),
          if (lead.accessDetails.trim().isNotEmpty)
            ('Terms', lead.accessDetails.trim()),
        ],
      ),
      (
        title: 'Timeline Information',
        icon: Icons.schedule_outlined,
        rows: [
          ('Status', lead.status.label),
          if (lead.status == LeadStatus.dropped &&
              lead.dropReason.trim().isNotEmpty)
            (
              'Drop reason',
              LeadDropReasonCatalogService.instance
                  .displayLabelForRaw(lead.dropReason),
            ),
          if (lead.status == LeadStatus.dropped &&
              lead.dropNotes.trim().isNotEmpty)
            ('Drop notes', lead.dropNotes.trim()),
          ('Received On', _formatReceivedOn(lead.addedOn)),
          ('Lead Age', '$leadAgeDays days'),
          ('Current Date & Time', _formatReceivedOn(DateTime.now())),
        ],
      ),
    ];

    const gap = 12.0;
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = c.maxWidth.isFinite ? c.maxWidth : 360.0;
        final cols = (maxW / 300).floor().clamp(1, 2);
        final w = (maxW - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(
                width: cols == 1 ? maxW : w,
                child: _LeadInfoCard(
                  title: card.title,
                  icon: card.icon,
                  rows: card.rows,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _LeadInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<(String, String)> rows;

  const _LeadInfoCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fomraSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.fomraBorder),
        boxShadow: context.fomraCardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.purple),
              const SizedBox(width: 7),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: context.fomraTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _LeadDetailsColumn(rows: rows),
        ],
      ),
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
