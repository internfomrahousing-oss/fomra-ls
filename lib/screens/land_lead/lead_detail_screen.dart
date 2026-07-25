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
import '../../models/land_lead_signed_request.dart';
import '../../services/land_lead_legal_service.dart';
import '../../services/land_lead_meeting_service.dart';
import '../../services/land_lead_service.dart';
import '../../services/land_lead_signed_service.dart';
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
import '../../widgets/fomra_breadcrumb.dart';
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
        Icons.gavel_outlined, _ActivityFilter.legal),
    e(10, 'Follow-up', 'Priya S', 'Scheduled',
        'Follow up on the pending EC before starting negotiation.',
        Icons.event_available_outlined, _ActivityFilter.followUp),
    e(12, 'Project Signed', 'Arun Kumar', 'Submitted for approval',
        'Signing package submitted and awaiting management approval.',
        Icons.draw_outlined, _ActivityFilter.signed),
  ];
}

class LeadDetailScreen extends StatefulWidget {
  final LandLead lead;

  /// Optional explicit breadcrumb trail (e.g. `Home > Project Map > Lead #7`)
  /// for callers that want to show where the lead was opened from. When null,
  /// the app bar falls back to the flat `Home > Lead #id` derived from title.
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
  List<LandLeadMeeting> _meetings = [];
  List<LandLeadLegalDocument> _legalDocs = [];
  List<LandLeadSignedRequest> _signedRequests = [];

  /// Shared Activity Timeline filter — driven by the five statistics cards and
  /// timeline chips only. Quick Actions open dialogs and do not select filters.
  _ActivityFilter _activityFilter = _ActivityFilter.all;
  _SiteVisitScope _siteVisitScope = _SiteVisitScope.self;
  _CallStatFilter _callStatFilter = _CallStatFilter.none;

  final GlobalKey _timelineKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

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

  /// Applies a single Activity Timeline filter, switches to the Activity tab,
  /// and smoothly scrolls the timeline into view. Returns after the scroll has
  /// been scheduled so callers can await a short settle before opening a dialog.
  ///
  /// Does not highlight Quick Actions — those are independent of timeline filters.
  Future<void> _applyActivityFilter({
    required _ActivityFilter filter,
    _SiteVisitScope? siteVisitScope,
    _CallStatFilter callStatFilter = _CallStatFilter.none,
  }) async {
    // Switch tab synchronously so the timeline mounts before we scroll to it.
    final needsTabSwitch = !_viewOnly && _tabController.index != 0;
    if (needsTabSwitch) {
      _tabController.index = 0;
    }
    setState(() {
      _activityFilter = filter;
      if (siteVisitScope != null) _siteVisitScope = siteVisitScope;
      _callStatFilter = callStatFilter;
    });
    await _scrollToTimeline(
      delay: needsTabSwitch
          ? const Duration(milliseconds: 120)
          : const Duration(milliseconds: 16),
    );
  }

  /// Scrolls the Activity Timeline into view. Retries a few frames so a just-
  /// switched Activity tab has time to mount under [_timelineKey].
  Future<void> _scrollToTimeline({Duration delay = Duration.zero}) async {
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (!mounted) return;

    for (var attempt = 0; attempt < 5; attempt++) {
      final ctx = _timelineKey.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeInOut,
          alignment: 0.08,
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
      // Give the framework one frame between retries.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
  }

  void _clearActivityFilter() {
    _applyActivityFilter(filter: _ActivityFilter.all);
  }

  void _onTimelineFilterSelected(_ActivityFilter filter) {
    _applyActivityFilter(
      filter: filter,
      callStatFilter: _CallStatFilter.none,
    );
  }

  void _onSiteVisitScopeSelected(_SiteVisitScope scope) {
    _applyActivityFilter(
      filter: _ActivityFilter.siteVisits,
      siteVisitScope: scope,
      callStatFilter: _CallStatFilter.none,
    );
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
        LandLeadSignedService.getForLead(lead.leadId),
      ]);
      if (!mounted) return;
      setState(() {
        _callLogs = results[0] as List<LeadCallLog>;
        _siteVisits = results[1] as List<LandLeadSiteVisit>;
        _meetings = results[2] as List<LandLeadMeeting>;
        _legalDocs = results[3] as List<LandLeadLegalDocument>;
        _signedRequests = results[4] as List<LandLeadSignedRequest>;
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
    _scrollController.dispose();
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

  /// Non-rejected site visits — matches what Conducted Site Visits filters to.
  int get _conductedSiteVisitCount => _siteVisits
      .where((v) => v.approvalStatus != SiteVisitApprovalStatus.rejected)
      .length;

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

  Future<void> _handleDetailAction(String label) async {
    // Quick Actions only open their log/action dialog — they do NOT drive the
    // Activity Timeline filters. Filtering is owned by the five statistics
    // cards (Conducted Site Visits + call buckets) and the timeline chips.
    await _showActionDialog(label);
  }

  void _handleStatCardTap(_StatCardKind kind) {
    // Statistics cards drive the Activity Timeline filter chips directly.
    // Quick Actions stay unhighlighted — filters live only on these cards + chips.
    switch (kind) {
      case _StatCardKind.conductedSiteVisits:
        // Card counts every non-rejected visit (executive + management), so the
        // timeline filter must use the matching "all" scope — not Myself only.
        _applyActivityFilter(
          filter: _ActivityFilter.siteVisits,
          siteVisitScope: _SiteVisitScope.all,
          callStatFilter: _CallStatFilter.none,
        );
      case _StatCardKind.outgoingNotAnswered:
        _applyActivityFilter(
          filter: _ActivityFilter.calls,
          callStatFilter: _CallStatFilter.outgoingNotAnswered,
        );
      case _StatCardKind.outgoingAnswered:
        _applyActivityFilter(
          filter: _ActivityFilter.calls,
          callStatFilter: _CallStatFilter.outgoingAnswered,
        );
      case _StatCardKind.incomingNotAnswered:
        _applyActivityFilter(
          filter: _ActivityFilter.calls,
          callStatFilter: _CallStatFilter.incomingNotAnswered,
        );
      case _StatCardKind.incomingAnswered:
        _applyActivityFilter(
          filter: _ActivityFilter.calls,
          callStatFilter: _CallStatFilter.incomingAnswered,
        );
    }
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
      await _loadActivityData();
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
            leadAgeDays: _leadAgeDays,
            receivedOnLabel: _formatReceivedOn(lead.addedOn),
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
      siteVisitCount: _conductedSiteVisitCount,
      callMetrics: _callMetrics,
      callLogs: _callLogs,
      siteVisits: _siteVisits,
      meetings: _meetings,
      legalDocs: _legalDocs,
      signedRequests: _signedRequests,
      activityFilter: _activityFilter,
      siteVisitScope: _siteVisitScope,
      callStatFilter: _callStatFilter,
      timelineKey: _timelineKey,
      onDetailAction: _handleDetailAction,
      onStatCardTap: _handleStatCardTap,
      onTimelineFilterSelected: _onTimelineFilterSelected,
      onSiteVisitScopeSelected: _onSiteVisitScopeSelected,
      onClearFilter: _clearActivityFilter,
      onOpenTasks: _openViewTasks,
      shouldLoadMiTab: _shouldLoadMiTab,
    );

    // The Status & Timeline card lives in the guidance row (between Next Action
    // and Tasks) for the working executive; keep it in the left panel only when
    // that row isn't shown (management view-only).
    final infoCards = _LeadInfoCards(
      lead: lead,
      leadAgeDays: _leadAgeDays,
      showStatusTimeline: _viewOnly,
    );

    return FomraAppShell(
      currentRoute: '/land-lead',
      backgroundColor: context.fomraPageBg,
      // A drill-down sub-page header with a real Back button, so returning goes
      // to the actual previous page (workspace, map, search, notifications…)
      // instead of always jumping Home. The breadcrumb names the lead itself.
      appBar: FomraSubPageAppBar(
        title: 'Lead #${lead.leadId}',
        subtitle: _displayName == 'Lead #${lead.leadId}' ? null : _displayName,
        breadcrumbs: widget.breadcrumbs,
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
                                controller: _scrollController,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Compact reference column — slightly
                                    // narrower so the work column gets more
                                    // usable width and the two columns balance.
                                    Expanded(
                                      flex: 3,
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
                                      flex: 5,
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
                                controller: _scrollController,
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
  final List<LandLeadSignedRequest> signedRequests;
  final _ActivityFilter activityFilter;
  final _SiteVisitScope siteVisitScope;
  final _CallStatFilter callStatFilter;
  final GlobalKey timelineKey;
  final ValueChanged<String> onDetailAction;
  final ValueChanged<_StatCardKind> onStatCardTap;
  final ValueChanged<_ActivityFilter> onTimelineFilterSelected;
  final ValueChanged<_SiteVisitScope> onSiteVisitScopeSelected;
  final VoidCallback onClearFilter;
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
    this.signedRequests = const [],
    required this.activityFilter,
    required this.siteVisitScope,
    required this.callStatFilter,
    required this.timelineKey,
    required this.onDetailAction,
    required this.onStatCardTap,
    required this.onTimelineFilterSelected,
    required this.onSiteVisitScopeSelected,
    required this.onClearFilter,
    required this.onOpenTasks,
    required this.shouldLoadMiTab,
  });

  Widget _timeline() => KeyedSubtree(
        key: timelineKey,
        child: _ActivityTimeline(
          lead: lead,
          callLogs: callLogs,
          siteVisits: siteVisits,
          meetings: meetings,
          legalDocs: legalDocs,
          signedRequests: signedRequests,
          filter: activityFilter,
          siteVisitScope: siteVisitScope,
          callStatFilter: callStatFilter,
          onFilterSelected: onTimelineFilterSelected,
          onSiteVisitScopeSelected: onSiteVisitScopeSelected,
          onClearFilter: onClearFilter,
        ),
      );

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
                onAction: onDetailAction,
                onOpenTasks: onOpenTasks,
              ),
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
                onAction: onDetailAction,
                onOpenTasks: onOpenTasks,
              ),
              const SizedBox(height: 16),
            ],
            _ActivitySummaryRow(
              siteVisitCount: siteVisitCount,
              callMetrics: callMetrics,
              activityFilter: activityFilter,
              siteVisitScope: siteVisitScope,
              callStatFilter: callStatFilter,
              onStatCardTap: onStatCardTap,
            ),
            const SizedBox(height: 14),
            if (readOnly) ...[
              _timeline(),
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
                      return _timeline();
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

  const _ActionToolbar({
    required this.onAction,
    required this.onOpenTasks,
  });

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
      // Quick Actions never show a "selected/filter" highlight — filtering
      // belongs to the statistics cards and timeline chips only.
      return DecoratedBox(
        decoration: BoxDecoration(
          color: action.$3.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
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
  final _ActivityFilter activityFilter;
  final _SiteVisitScope siteVisitScope;
  final _CallStatFilter callStatFilter;
  final ValueChanged<_StatCardKind> onStatCardTap;

  const _ActivitySummaryRow({
    required this.siteVisitCount,
    required this.callMetrics,
    required this.activityFilter,
    required this.siteVisitScope,
    required this.callStatFilter,
    required this.onStatCardTap,
  });

  bool _isSelected(_StatCardKind kind) => switch (kind) {
        // Conducted Site Visits highlights for any Site Visits scope (including
        // the card's own "all" scope).
        _StatCardKind.conductedSiteVisits =>
          activityFilter == _ActivityFilter.siteVisits &&
              callStatFilter == _CallStatFilter.none,
        _StatCardKind.outgoingNotAnswered =>
          callStatFilter == _CallStatFilter.outgoingNotAnswered,
        _StatCardKind.outgoingAnswered =>
          callStatFilter == _CallStatFilter.outgoingAnswered,
        _StatCardKind.incomingNotAnswered =>
          callStatFilter == _CallStatFilter.incomingNotAnswered,
        _StatCardKind.incomingAnswered =>
          callStatFilter == _CallStatFilter.incomingAnswered,
      };

  @override
  Widget build(BuildContext context) {
    final cells = [
      (
        kind: _StatCardKind.conductedSiteVisits,
        label: 'Conducted\nSite Visits',
        value: '$siteVisitCount',
        icon: Icons.location_on_outlined,
        color: AppColors.purple,
      ),
      (
        kind: _StatCardKind.outgoingNotAnswered,
        label: 'Outgoing\nNot Answered',
        value: '${callMetrics.outgoingNotAnswered}',
        icon: CallOutcome.notAnswered.icon,
        color: AppColors.warning,
      ),
      (
        kind: _StatCardKind.outgoingAnswered,
        label: 'Outgoing\nAnswered',
        value: '${callMetrics.outgoingAnswered}',
        icon: CallOutcome.answered.icon,
        color: AppColors.success,
      ),
      (
        kind: _StatCardKind.incomingNotAnswered,
        label: 'Incoming\nNot Answered',
        value: '${callMetrics.incomingNotAnswered}',
        icon: CallOutcome.notAnswered.icon,
        color: AppColors.warning,
      ),
      (
        kind: _StatCardKind.incomingAnswered,
        label: 'Incoming\nAnswered',
        value: '${callMetrics.incomingAnswered}',
        icon: CallOutcome.answered.icon,
        color: AppColors.success,
      ),
    ];

    // Opaque GestureDetector so the whole tile is a reliable hit target on web
    // (decoration alone is not tappable; InkWell alone can miss nested hits).
    Widget cell(int i) {
      final selected = _isSelected(cells[i].kind);
      final accent = cells[i].color;
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => onStatCardTap(cells[i].kind),
          borderRadius: BorderRadius.circular(12),
          mouseCursor: SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.14)
                  : context.fomraSurfaceVar.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.55)
                    : context.fomraBorder,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(cells[i].icon, size: 15, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      cells[i].value,
                      style: TextStyle(
                        fontSize: 17,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: i == 0
                            ? AppColors.purple
                            : context.fomraTextPrimary,
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
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? accent : context.fomraTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

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

enum _StatCardKind {
  conductedSiteVisits,
  outgoingNotAnswered,
  outgoingAnswered,
  incomingNotAnswered,
  incomingAnswered,
}

/// Fine-grained Calls filter applied by the statistics cards.
enum _CallStatFilter {
  none,
  outgoingNotAnswered,
  outgoingAnswered,
  incomingNotAnswered,
  incomingAnswered,
}

enum _ActivityFilter {
  all,
  calls,
  siteVisits,
  managementSiteVisits,
  meetings,
  notes,
  legal,
  followUp,
  signed,
}

extension on _ActivityFilter {
  String get label => switch (this) {
        _ActivityFilter.all => 'All',
        _ActivityFilter.calls => 'Calls',
        _ActivityFilter.siteVisits => 'Site Visits',
        _ActivityFilter.managementSiteVisits => 'Management Site Visits',
        _ActivityFilter.meetings => 'Meetings',
        _ActivityFilter.notes => 'Notes',
        _ActivityFilter.legal => 'Legal',
        _ActivityFilter.followUp => 'Follow-up',
        _ActivityFilter.signed => 'Signed',
      };
}

/// The sub-scope of the unified "Site Visits" filter. [self] means the working
/// executive's own visits ("Myself" on the employee portal, "Executive" on
/// management); [management] means management site visits; [all] means every
/// completed visit (used by the Conducted Site Visits statistics card).
enum _SiteVisitScope { self, management, all }

/// Site Visits stays a single dropdown chip; Legal / Follow-up / Signed sit
/// beside the original categories so Quick Actions can target them directly.
const _kChipFilters = [
  _ActivityFilter.all,
  _ActivityFilter.calls,
  _ActivityFilter.siteVisits,
  _ActivityFilter.meetings,
  _ActivityFilter.notes,
  _ActivityFilter.legal,
  _ActivityFilter.followUp,
  _ActivityFilter.signed,
];

class _ActivityTimeline extends StatelessWidget {
  final LandLead lead;
  final List<LeadCallLog> callLogs;
  final List<LandLeadSiteVisit> siteVisits;
  final List<LandLeadMeeting> meetings;
  final List<LandLeadLegalDocument> legalDocs;
  final List<LandLeadSignedRequest> signedRequests;
  final _ActivityFilter filter;
  final _SiteVisitScope siteVisitScope;
  final _CallStatFilter callStatFilter;
  final ValueChanged<_ActivityFilter> onFilterSelected;
  final ValueChanged<_SiteVisitScope> onSiteVisitScopeSelected;
  final VoidCallback onClearFilter;

  const _ActivityTimeline({
    required this.lead,
    required this.callLogs,
    required this.siteVisits,
    this.meetings = const [],
    this.legalDocs = const [],
    this.signedRequests = const [],
    required this.filter,
    required this.siteVisitScope,
    required this.callStatFilter,
    required this.onFilterSelected,
    required this.onSiteVisitScopeSelected,
    required this.onClearFilter,
  });

  bool _isCompletedVisit(LandLeadSiteVisit visit) =>
      visit.approvalStatus != SiteVisitApprovalStatus.rejected;

  @override
  Widget build(BuildContext context) {
    final events = <({
      DateTime at,
      String title,
      String subtitle,
      IconData icon,
      String? audioUrl,
      _ActivityFilter category,
      CallDirection? direction,
      CallOutcome? outcome,
      bool completedVisit,
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
        direction: log.direction,
        outcome: log.outcome,
        completedVisit: false,
      ));
      if (log.needsFollowUp && log.followUpAt != null) {
        events.add((
          at: log.followUpAt!,
          title: 'Follow-up',
          subtitle: [
            _formatReceivedOn(log.followUpAt!),
            '${log.direction.label} call · ${log.outcome.label}',
            if (log.details.isNotEmpty) log.details,
            if (log.loggedByName.isNotEmpty) log.loggedByName,
          ].join('\n'),
          icon: Icons.event_available_outlined,
          audioUrl: null,
          category: _ActivityFilter.followUp,
          direction: log.direction,
          outcome: log.outcome,
          completedVisit: false,
        ));
      }
    }

    for (final visit in siteVisits) {
      final isManagementVisit =
          visit.visitType == LandLeadSiteVisitType.management;
      final approval =
          isManagementVisit ? '\n${visit.approvalStatus.label}' : '';
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
        direction: null,
        outcome: null,
        completedVisit: _isCompletedVisit(visit),
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
        direction: null,
        outcome: null,
        completedVisit: false,
      ));
    }

    for (final doc in legalDocs) {
      events.add((
        at: doc.verifiedAt,
        title: 'Legal document',
        subtitle: [
          _formatReceivedOn(doc.verifiedAt),
          if (doc.fileName.isNotEmpty) doc.fileName,
          if (doc.loggedByName.isNotEmpty) doc.loggedByName,
        ].join('\n'),
        icon: Icons.gavel_outlined,
        audioUrl: null,
        category: _ActivityFilter.legal,
        direction: null,
        outcome: null,
        completedVisit: false,
      ));
    }

    for (final request in signedRequests) {
      events.add((
        at: request.reviewedAt ?? request.createdAt,
        title: 'Project Signed',
        subtitle: [
          _formatReceivedOn(request.reviewedAt ?? request.createdAt),
          request.status.label,
          if (request.note.isNotEmpty) request.note,
          if (request.requestedByName.isNotEmpty) request.requestedByName,
        ].join('\n'),
        icon: Icons.draw_outlined,
        audioUrl: null,
        category: _ActivityFilter.signed,
        direction: null,
        outcome: null,
        completedVisit: false,
      ));
    }

    // Parse tagged notes (voice / GPS) into timeline entries. The nearby
    // information block is one entry, however many categories it lists.
    for (final entry in LeadAutoNotes.splitEntries(lead.notes)) {
      final isAuto = LeadAutoNotes.isAutoEntry(entry);
      final isVoice = entry.contains('[Voice Note]');
      final isGps = entry.contains('[GPS Check-in]');
      final audioUrl =
          isVoice ? VoiceNoteService.audioUrlFromNotesLine(entry) : null;
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
        direction: null,
        outcome: null,
        completedVisit: false,
      ));
    }

    // Demo/development only: when a lead has no real activity, seed a realistic
    // sample timeline so the page isn't empty in demos. Guarded by kDebugMode,
    // rendered locally and NEVER written to Supabase — zero production impact.
    if (kDebugMode && events.isEmpty) {
      for (final e in _demoTimelineEvents(lead)) {
        events.add((
          at: e.at,
          title: e.title,
          subtitle: e.subtitle,
          icon: e.icon,
          audioUrl: e.audioUrl,
          category: e.category,
          direction: null,
          outcome: null,
          completedVisit: e.category == _ActivityFilter.siteVisits ||
              e.category == _ActivityFilter.managementSiteVisits,
        ));
      }
    }

    events.sort((a, b) => b.at.compareTo(a.at));

    // Counts drive the filter chip labels and update live with the records shown.
    final selfVisitCount =
        events.where((e) => e.category == _ActivityFilter.siteVisits).length;
    final mgmtVisitCount = events
        .where((e) => e.category == _ActivityFilter.managementSiteVisits)
        .length;
    final filterCounts = <_ActivityFilter, int>{
      for (final f in _ActivityFilter.values)
        if (f != _ActivityFilter.managementSiteVisits)
          f: f == _ActivityFilter.all
              ? events.length
              : events.where((e) => e.category == f).length,
    };

    // Apply filters independently: call-stat cards win when set; otherwise the
    // selected chip (including Site Visits scope) drives the list.
    final filtered = events.where((e) {
      if (callStatFilter != _CallStatFilter.none) {
        if (e.category != _ActivityFilter.calls) return false;
        if (e.direction == null || e.outcome == null) return false;
        return switch (callStatFilter) {
          _CallStatFilter.outgoingNotAnswered =>
            e.direction == CallDirection.outgoing &&
                e.outcome == CallOutcome.notAnswered,
          _CallStatFilter.outgoingAnswered =>
            e.direction == CallDirection.outgoing &&
                e.outcome == CallOutcome.answered,
          _CallStatFilter.incomingNotAnswered =>
            e.direction == CallDirection.incoming &&
                e.outcome == CallOutcome.notAnswered,
          _CallStatFilter.incomingAnswered =>
            e.direction == CallDirection.incoming &&
                e.outcome == CallOutcome.answered,
          _CallStatFilter.none => true,
        };
      }
      if (filter == _ActivityFilter.all) return true;
      if (filter == _ActivityFilter.siteVisits) {
        final isVisit = e.category == _ActivityFilter.siteVisits ||
            e.category == _ActivityFilter.managementSiteVisits;
        if (!isVisit || !e.completedVisit) return false;
        return switch (siteVisitScope) {
          _SiteVisitScope.self => e.category == _ActivityFilter.siteVisits,
          _SiteVisitScope.management =>
            e.category == _ActivityFilter.managementSiteVisits,
          _SiteVisitScope.all => true,
        };
      }
      return e.category == filter;
    }).toList();

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

    final hasActiveFilter =
        filter != _ActivityFilter.all || callStatFilter != _CallStatFilter.none;

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
          selected: filter,
          onSelected: onFilterSelected,
          siteVisitScope: siteVisitScope,
          onSiteVisitScope: onSiteVisitScopeSelected,
          isManagement: AuthService.instance.isManagement,
          selfVisitCount: selfVisitCount,
          managementVisitCount: mgmtVisitCount,
          filterCounts: filterCounts,
          callStatFilter: callStatFilter,
        ),
        const SizedBox(height: 10),
        if (filtered.isEmpty)
          _ActivityEmptyState(
            hasActiveFilter: hasActiveFilter,
            onClearFilter: onClearFilter,
          )
        else
          for (final e in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TimelineAvatar(icon: e.icon),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          e.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
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
        if (filter == _ActivityFilter.all &&
            callStatFilter == _CallStatFilter.none)
          for (final e in staticEvents)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TimelineAvatar(icon: e.icon, muted: true),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.title,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          e.subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
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

class _ActivityEmptyState extends StatelessWidget {
  final bool hasActiveFilter;
  final VoidCallback onClearFilter;

  const _ActivityEmptyState({
    required this.hasActiveFilter,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(
            Icons.filter_alt_off_outlined,
            size: 28,
            color: context.fomraTextSecondary.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 10),
          Text(
            hasActiveFilter
                ? 'No matching activities found.'
                : 'No activity yet — use quick actions to log the first step.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.fomraTextSecondary,
            ),
          ),
          if (hasActiveFilter) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onClearFilter,
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Clear Filter'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Circular avatar for a timeline entry — a tinted disc holding the entry's
/// icon, giving the timeline a richer, more scannable enterprise look. Static
/// milestones render [muted] so real logged activity stands out.
class _TimelineAvatar extends StatelessWidget {
  final IconData icon;
  final bool muted;

  const _TimelineAvatar({required this.icon, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final tint = muted ? context.fomraTextSecondary : AppColors.purple;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: muted ? 0.10 : 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, size: 16, color: tint),
    );
  }
}

class _ActivityFilterBar extends StatelessWidget {
  final _ActivityFilter selected;
  final ValueChanged<_ActivityFilter> onSelected;
  final _SiteVisitScope siteVisitScope;
  final ValueChanged<_SiteVisitScope> onSiteVisitScope;
  final bool isManagement;
  final int selfVisitCount;
  final int managementVisitCount;
  final Map<_ActivityFilter, int> filterCounts;
  final _CallStatFilter callStatFilter;

  const _ActivityFilterBar({
    required this.selected,
    required this.onSelected,
    required this.siteVisitScope,
    required this.onSiteVisitScope,
    required this.isManagement,
    required this.selfVisitCount,
    required this.managementVisitCount,
    required this.filterCounts,
    required this.callStatFilter,
  });

  /// The label for the "own visits" scope differs by portal.
  String get _selfLabel => isManagement ? 'Executive' : 'Myself';

  String _scopeLabel(_SiteVisitScope s) => switch (s) {
        _SiteVisitScope.management => 'Management',
        _SiteVisitScope.self => _selfLabel,
        _SiteVisitScope.all => 'All',
      };

  int _scopeCount(_SiteVisitScope s) => switch (s) {
        _SiteVisitScope.management => managementVisitCount,
        _SiteVisitScope.self => selfVisitCount,
        _SiteVisitScope.all => selfVisitCount + managementVisitCount,
      };

  /// Scopes offered in the Site Visits dropdown (Conducted-card "all" is not
  /// listed here — it is reached from the statistics row).
  static const _dropdownScopes = [
    _SiteVisitScope.self,
    _SiteVisitScope.management,
  ];

  String _chipLabel(_ActivityFilter f) {
    if (f == _ActivityFilter.calls &&
        callStatFilter != _CallStatFilter.none) {
      final sub = switch (callStatFilter) {
        _CallStatFilter.outgoingNotAnswered => 'Outgoing Not Answered',
        _CallStatFilter.outgoingAnswered => 'Outgoing Answered',
        _CallStatFilter.incomingNotAnswered => 'Incoming Not Answered',
        _CallStatFilter.incomingAnswered => 'Incoming Answered',
        _CallStatFilter.none => 'Calls',
      };
      return 'Calls · $sub';
    }
    if (f == _ActivityFilter.all) return f.label;
    final count = filterCounts[f];
    if (count == null) return f.label;
    return '${f.label} ($count)';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _kChipFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = _kChipFilters[i];
          if (f == _ActivityFilter.siteVisits) return _siteVisitsChip(context);
          // Calls chip stays highlighted for call-stat sub-filters too.
          final selectedChip = f == selected ||
              (f == _ActivityFilter.calls &&
                  callStatFilter != _CallStatFilter.none);
          return _chip(
            context,
            label: _chipLabel(f),
            isSelected: selectedChip,
            onTap: () => onSelected(f),
          );
        },
      ),
    );
  }

  /// The chip's padded, coloured body — shared by the tappable chips and the
  /// Site Visits dropdown (whose tap is handled by PopupMenuButton, so it must
  /// not carry its own InkWell).
  Widget _chipBody(
    BuildContext context, {
    required String label,
    required bool isSelected,
    Widget? trailing,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.purple
            : context.fomraSurfaceVar.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : context.fomraTextSecondary,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), trailing],
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: _chipBody(context,
            label: label, isSelected: isSelected, trailing: trailing),
      ),
    );
  }

  /// Unified Site Visits chip: tapping opens a dropdown to pick the scope
  /// (Myself/Executive · Management), each showing its live count.
  Widget _siteVisitsChip(BuildContext context) {
    final isSelected = selected == _ActivityFilter.siteVisits &&
        callStatFilter == _CallStatFilter.none;
    return PopupMenuButton<_SiteVisitScope>(
      tooltip: 'Filter site visits',
      position: PopupMenuPosition.under,
      onSelected: onSiteVisitScope,
      itemBuilder: (_) => [
        for (final s in _dropdownScopes)
          PopupMenuItem(
            value: s,
            child: Row(
              children: [
                if (isSelected && siteVisitScope == s)
                  const Icon(Icons.check_rounded,
                      size: 16, color: AppColors.purple)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(_scopeLabel(s)),
                const Spacer(),
                Text('${_scopeCount(s)}',
                    style: TextStyle(
                        fontSize: 12, color: context.fomraTextSecondary)),
              ],
            ),
          ),
      ],
      child: _chipBody(
        context,
        label:
            'Site Visits · ${_scopeLabel(siteVisitScope)} (${_scopeCount(siteVisitScope)})',
        isSelected: isSelected,
        trailing: Icon(
          Icons.arrow_drop_down_rounded,
          size: 18,
          color: isSelected ? Colors.white : context.fomraTextSecondary,
        ),
      ),
    );
  }
}

/// Rendering style for a single key-value fact in an info card.
enum _FieldStyle { plain, accent, badge, chips }

/// One labelled fact in an info card. [wide] forces a full-width cell; long
/// plain values auto-span. [color] tints [badge]/[accent] styles.
class _Field {
  final String label;
  final String value;
  final _FieldStyle style;
  final Color? color;
  final bool wide;

  const _Field(
    this.label,
    this.value, {
    this.style = _FieldStyle.plain,
    this.color,
    this.wide = false,
  });
}

/// The lead's reference detail, merged into three compact, scannable cards —
/// Contact & Lead / Property Information / Status & Timeline — laid out as a
/// responsive two-column key-value grid instead of one long form.
class _LeadInfoCards extends StatelessWidget {
  final LandLead lead;
  final int leadAgeDays;

  /// Whether to include the Status & Timeline card. It moves to the guidance
  /// row for the working executive, so the left panel only keeps it when that
  /// row isn't shown (management view-only). Dropped leads always keep it so
  /// the drop reason/notes stay visible.
  final bool showStatusTimeline;

  const _LeadInfoCards({
    required this.lead,
    required this.leadAgeDays,
    this.showStatusTimeline = true,
  });

  String _v(String raw) => raw.trim().isEmpty ? '—' : raw.trim();

  @override
  Widget build(BuildContext context) {
    final cards = <({String title, IconData icon, List<_Field> fields})>[
      (
        title: 'Contact & Lead',
        icon: Icons.contacts_outlined,
        fields: [
          _Field('Owner', _v(lead.ownerName)),
          _Field('Contact', _v(lead.contactDetails)),
          _Field('Executive', _v(lead.createdByName),
              style: _FieldStyle.badge, color: AppColors.purple),
          _Field('Broker', _v(lead.brokerName)),
          _Field('Input Source', lead.inputSource.label),
        ],
      ),
      (
        title: 'Property Information',
        icon: Icons.home_work_outlined,
        fields: [
          _Field('Village', _v(lead.village)),
          _Field('District', _v(lead.district)),
          _Field('Survey No.', _v(lead.surveyNumber),
              style: _FieldStyle.badge, color: AppColors.primary),
          _Field('Land Type', lead.landType.label),
          _Field('Land Extent', _v(lead.landExtent),
              style: _FieldStyle.badge, color: AppColors.success),
          _Field('Road Width', _v(lead.roadWidth)),
          if (lead.accessDetails.trim().isNotEmpty)
            _Field('Terms', lead.accessDetails.trim(),
                style: _FieldStyle.chips, wide: true),
        ],
      ),
      if (showStatusTimeline || lead.status == LeadStatus.dropped)
        (
          title: 'Status & Timeline',
          icon: Icons.timeline_outlined,
          fields: [
            _Field('Current Stage', lead.status.label,
                style: _FieldStyle.badge, color: lead.status.color),
            _Field('Lead Age', '$leadAgeDays days', style: _FieldStyle.accent),
            _Field('Received On', _formatReceivedOn(lead.addedOn)),
            if (lead.status == LeadStatus.dropped &&
                lead.dropReason.trim().isNotEmpty)
              _Field(
                'Drop reason',
                LeadDropReasonCatalogService.instance
                    .displayLabelForRaw(lead.dropReason),
                wide: true,
              ),
            if (lead.status == LeadStatus.dropped &&
                lead.dropNotes.trim().isNotEmpty)
              _Field('Drop notes', lead.dropNotes.trim(), wide: true),
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
                  fields: card.fields,
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
  final List<_Field> fields;

  const _LeadInfoCard({
    required this.title,
    required this.icon,
    required this.fields,
  });

  /// A field takes the full card width when flagged [wide] or its plain value
  /// is long, so it never crams into a half-width cell.
  static bool _isWide(_Field f) => f.wide || f.value.trim().length > 18;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fomraSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.fomraBorder),
        boxShadow: context.fomraCardShadow,
      ),
      // Tighter padding keeps the left column compact without feeling cramped.
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
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
          const SizedBox(height: 11),
          // Two key-value pairs per row on comfortable widths, single column on
          // narrow ones — packs short fields together to cut vertical height.
          LayoutBuilder(
            builder: (context, c) {
              const gap = 14.0;
              final twoCol = c.maxWidth >= 300;
              final cellW = twoCol ? (c.maxWidth - gap) / 2 : c.maxWidth;
              return Wrap(
                spacing: gap,
                runSpacing: 10,
                children: [
                  for (final f in fields)
                    SizedBox(
                      width: (!twoCol || _isWide(f)) ? c.maxWidth : cellW,
                      child: _LeadDetailRow(field: f),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Compact stacked key-value cell — a small muted label above a prominent
/// value that can render as plain text, an accent, a colored badge, or chips.
class _LeadDetailRow extends StatelessWidget {
  final _Field field;

  const _LeadDetailRow({required this.field});

  static List<String> _splitChips(String raw) {
    final parts = raw
        .split(RegExp(r'[,\n;•]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? [raw.trim()] : parts;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          field.label.toUpperCase(),
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: context.fomraTextSecondary,
          ),
        ),
        const SizedBox(height: 3),
        _value(context),
      ],
    );
  }

  Widget _value(BuildContext context) {
    switch (field.style) {
      case _FieldStyle.badge:
        final color = field.color ?? AppColors.primary;
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              field.value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        );
      case _FieldStyle.accent:
        return Text(
          field.value,
          style: const TextStyle(
            fontSize: 13.5,
            height: 1.2,
            fontWeight: FontWeight.w800,
            color: AppColors.purple,
          ),
        );
      case _FieldStyle.chips:
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final chip in _splitChips(field.value))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: context.fomraSurfaceVar,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: context.fomraBorder),
                ),
                child: Text(
                  chip,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.fomraTextPrimary,
                  ),
                ),
              ),
          ],
        );
      case _FieldStyle.plain:
        return Text(
          field.value,
          style: TextStyle(
            fontSize: 13,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: context.fomraTextPrimary,
          ),
        );
    }
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
                      fontWeight: FontWeight.w700,
                      color: status.color,
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
                            fontWeight: FontWeight.w700,
                            color: status.color,
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
