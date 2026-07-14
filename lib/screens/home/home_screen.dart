import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/land_lead.dart';
import '../land_lead/add_lead_screen.dart';
import '../../models/lead_list_filter.dart';
import '../land_lead/filtered_leads_screen.dart';
import '../land_lead/lead_detail_screen.dart';
import '../land_lead/leads_map_screen.dart';
import '../land_lead/management_visit_review_dialog.dart';
import '../../services/auth_service.dart';
import '../../services/app_store.dart';
import '../../services/employee_service.dart';
import '../../services/land_lead_service.dart';
import '../../services/lead_drop_approval_service.dart';
import '../../services/land_lead_signed_service.dart';
import '../../services/land_lead_site_visit_service.dart';
import '../../services/notification_center_service.dart';
import '../../services/notifications_service.dart';
import '../../services/push_service.dart';
import '../../services/role_access.dart';
import '../../services/universal_search_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../models/app_notification.dart';
import '../../models/land_lead_signed_request.dart';
import '../../models/land_lead_site_visit.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/ui/app_feedback.dart';
import '../../widgets/management_executive_dashboard.dart';
import '../../widgets/offline_status_banner.dart';
import '../../widgets/portal_home_sections.dart';
import '../../widgets/ui/app_components.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<AppNotification> _notifications = [];
  RealtimeChannel? _notifChannel;
  // Ids we've already surfaced, so a realtime refresh only toasts genuinely new
  // notifications. Primed on the first load so history doesn't toast at once.
  final Set<String> _seenNotifIds = {};
  bool _notifPrimed = false;
  // Top-right toast overlay (SnackBars can't anchor to the top).
  final GlobalKey<_ToastStackState> _toastStackKey = GlobalKey();
  OverlayEntry? _toastHost;
  DateTime _clock = DateTime.now();

  // Anchored notification dropdown (opens under the bell on click).
  final LayerLink _notifLink = LayerLink();
  OverlayEntry? _notifOverlay;
  bool get _notifOpen => _notifOverlay != null;

  List<LandLeadSiteVisit> _pendingApprovals = [];
  List<LandLeadSignedRequest> _pendingSigned = [];
  List<LeadDropApprovalRequest> _pendingDropApprovals = [];
  bool _loadingApprovals = false;
  Timer? _reminderSyncTimer;

  String get _notifAudience =>
      AuthService.instance.isManagement ? 'management' : 'employee';

  int get _activeLeads =>
      _homeSummaryLeads.where((l) => l.status.isActive).length;

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get _isManagement => AuthService.instance.isManagement;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppStore.instance.addListener(_onStoreUpdate);
    // Register this device for push under the signed-in audience (guarded).
    PushService.syncToken();
    _loadNotifications();
    _loadPerformanceData();
    if (_isManagement) _loadPendingApprovals();
    UniversalSearchService.warmDocumentIndex();
    NotificationCenterService.syncAlerts().then((_) {
      if (mounted) _loadNotifications();
    });
    _notifChannel = NotificationsService.subscribe(
      audience: _notifAudience,
      onChange: _loadNotifications,
    );
    // Keep Field Calendar (and other) reminders flowing into the Notification
    // Center while the app stays open, not just on screen load.
    _reminderSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      NotificationCenterService.syncAlerts().then((_) {
        if (mounted) _loadNotifications();
      });
    });
  }

  /// Make sure leads are loaded so both the management leaderboard and an
  /// employee's own "leads added" count have data before those screens are
  /// opened. The employee roster is only needed for the management leaderboard.
  Future<void> _loadPerformanceData() async {
    if (AppStore.instance.leads.isEmpty) {
      try {
        final leads = await LandLeadService.getAll();
        AppStore.instance.setLeads(leads);
      } catch (_) {/* keep whatever is cached */}
    }
    if (_isManagement && AppStore.instance.employees.isEmpty) {
      try {
        final employees = await EmployeeService.getAll();
        if (employees.isNotEmpty) AppStore.instance.setEmployees(employees);
      } catch (_) {/* fall back to lead-derived names */}
    }
  }

  /// Leads added by the currently signed-in user (matched by creator name).
  List<LandLead> get _myLeads => AppStore.instance.visibleLeads;

  /// Summary tiles on home — all leads for management, own leads for employees.
  List<LandLead> get _homeSummaryLeads =>
      _isManagement ? AppStore.instance.leads : _myLeads;

  int get _myLeadCount => _myLeads.length;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppStore.instance.removeListener(_onStoreUpdate);
    _reminderSyncTimer?.cancel();
    _notifChannel?.unsubscribe();
    _notifOverlay?.remove();
    _notifOverlay = null;
    _toastHost?.remove();
    _toastHost = null;
    super.dispose();
  }

  void _onStoreUpdate() => setState(() {});

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _clock = DateTime.now());
    }
  }


  Future<void> _loadNotifications() async {
    try {
      final list = await NotificationsService.getAll(audience: _notifAudience);
      final filtered = list
          .where((n) =>
              !_isManagementLeadNotification(n) &&
              !_isNewLeadUploadNotification(n) &&
              _isForMe(n))
          .toList();
      if (mounted) {
        _emitNewNotificationToasts(filtered);
        setState(() => _notifications = filtered);
        _notifOverlay?.markNeedsBuild(); // refresh the open dropdown live
        if (_isManagement) _loadPendingApprovals();
      }
    } catch (_) {
      // Keep the current list if the fetch fails (e.g. table not created yet).
    }
  }

  // Don't surface lead notifications for leads management uploaded itself.
  bool _isManagementLeadNotification(AppNotification n) =>
      (n.type == NotificationType.lead ||
          n.type == NotificationType.assignedLead) &&
      n.title.toLowerCase().contains('by management');

  bool _isNewLeadUploadNotification(AppNotification n) =>
      (n.type == NotificationType.lead ||
          n.type == NotificationType.assignedLead) &&
      n.title.toLowerCase().contains('new lead uploaded');

  /// An assignment notification is only for the employees it was assigned to.
  /// The assignees are named in the message ("… — assigned to pooja, vijay"),
  /// so an employee only sees it when their own name is in that list. Management
  /// and all non-assignment notifications are shown as-is.
  bool _isForMe(AppNotification n) {
    if (_isManagement) return true;
    const marker = 'assigned to ';
    final msg = n.message.toLowerCase();
    final idx = msg.lastIndexOf(marker);
    final me = (AuthService.instance.currentUser?.fullName ?? '')
        .trim()
        .toLowerCase();
    if (idx != -1 && me.isNotEmpty) {
      final assignees =
          msg.substring(idx + marker.length).split(',').map((s) => s.trim());
      if (!assignees.contains(me)) return false;
    }
    // Notifications are stored in a shared 'employee' audience bucket (no
    // per-user column in the schema), so any notification tied to a specific
    // lead only belongs to this Executive if that lead is one of theirs.
    final leadId = (n.leadId ?? '').trim();
    if (leadId.isNotEmpty) {
      final myLeadIds =
          AppStore.instance.visibleLeads.map((l) => l.leadId).toSet();
      if (!myLeadIds.contains(leadId)) return false;
    }
    return true;
  }

  /// On the first refresh we only record the existing ids (so the whole history
  /// doesn't toast at once). After that, any id we haven't seen before is a live
  /// insert and pops a toast — newest last so it's the one left on screen.
  void _emitNewNotificationToasts(List<AppNotification> latest) {
    final fresh =
        latest.where((n) => !_seenNotifIds.contains(n.id)).toList();
    for (final n in latest) {
      _seenNotifIds.add(n.id);
    }
    if (!_notifPrimed) {
      _notifPrimed = true;
      return;
    }
    for (final n in fresh.take(3).toList().reversed) {
      _showNotificationToast(n);
    }
  }

  void _showNotificationToast(AppNotification n) {
    _ensureToastHost();
    // The stack may not be mounted on the frame the host is first inserted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _toastStackKey.currentState?.push(_ToastData(
        title: n.title,
        message: n.message,
        color: _notifTypeColor(n.type),
        icon: _notifTypeIcon(n.type),
      ));
    });
  }

  void _ensureToastHost() {
    if (_toastHost != null) return;
    _toastHost = OverlayEntry(builder: (_) => _ToastStack(key: _toastStackKey));
    Overlay.of(context, rootOverlay: true).insert(_toastHost!);
  }

  Color _notifTypeColor(NotificationType t) => switch (t) {
        NotificationType.lead ||
        NotificationType.assignedLead =>
          AppColors.info,
        NotificationType.pendingLead => AppColors.warning,
        NotificationType.pendingApproval => AppColors.secondary,
        NotificationType.slaBreach ||
        NotificationType.overdueTask ||
        NotificationType.alert =>
          AppColors.error,
        NotificationType.reminder || NotificationType.siteVisit =>
          AppColors.primary,
        NotificationType.task => AppColors.warning,
        NotificationType.document => AppColors.success,
        NotificationType.verification => AppColors.secondary,
      };

  IconData _notifTypeIcon(NotificationType t) => switch (t) {
        NotificationType.lead ||
        NotificationType.assignedLead =>
          Icons.person_add_alt_1_outlined,
        NotificationType.pendingLead => Icons.hourglass_top_rounded,
        NotificationType.pendingApproval => Icons.approval_outlined,
        NotificationType.slaBreach => Icons.timer_off_outlined,
        NotificationType.overdueTask => Icons.warning_amber_rounded,
        NotificationType.reminder => Icons.notifications_active_outlined,
        NotificationType.task => Icons.task_alt,
        NotificationType.document => Icons.description,
        NotificationType.alert => Icons.warning_amber,
        NotificationType.verification => Icons.verified,
        NotificationType.siteVisit => Icons.apartment_outlined,
      };

  void _toggleNotifications() {
    // Tapping the bell is a user gesture — use it to request push permission
    // (browsers suppress the auto prompt on page load) and register the token.
    PushService.promptAndSync();
    if (_notifOpen) {
      _hideNotifications();
    } else {
      _openNotifications();
    }
  }

  void _hideNotifications() {
    _notifOverlay?.remove();
    _notifOverlay = null;
    if (mounted) setState(() {}); // repaint the bell (pressed state / badge)
  }

  void _openNotifications() {
    _notifOverlay = OverlayEntry(
      builder: (_) => _NotificationsDropdown(
        link: _notifLink,
        notifications: _notifications,
        onDismiss: _hideNotifications,
        onMarkRead: (id) {
          setState(() {
            _notifications.firstWhere((n) => n.id == id).isRead = true;
          });
          _notifOverlay?.markNeedsBuild();
          NotificationsService.markRead(id).catchError((_) {});
        },
        onMarkAllRead: () {
          setState(() {
            for (final n in _notifications) { n.isRead = true; }
          });
          _notifOverlay?.markNeedsBuild();
          NotificationsService.markAllRead(audience: _notifAudience)
              .catchError((_) {});
        },
        onViewAll: () {
          _hideNotifications();
          Navigator.pushNamed(context, '/notifications');
        },
        onOpen: (n) async {
          _hideNotifications();
          if ((n.type == NotificationType.siteVisit ||
                  n.type == NotificationType.pendingApproval) &&
              _isManagement) {
            var visitId = n.referenceId;
            if (visitId == null && n.leadId != null) {
              visitId = await LandLeadSiteVisitService.findPendingManagementVisitId(
                n.leadId!,
              );
            }
            if (!mounted) return;
            if (visitId != null) {
              await showManagementVisitReviewDialog(
                context,
                visitId: visitId,
                leadId: n.leadId,
              );
              return;
            }
          }
          if (n.type != NotificationType.lead && n.type != NotificationType.siteVisit) {
            return;
          }
          LandLead? lead;
          for (final l in AppStore.instance.leads) {
            if (l.leadId == n.leadId) {
              lead = l;
              break;
            }
          }
          if (lead != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead!)),
            );
          } else if (n.leadId != null) {
            Navigator.pushNamed(context, '/land-lead');
          }
        },
      ),
    );
    Overlay.of(context).insert(_notifOverlay!);
    setState(() {}); // repaint the bell in its active state
  }

  Future<void> _loadPendingApprovals() async {
    if (!_isManagement) return;
    setState(() => _loadingApprovals = true);
    List<LandLeadSiteVisit> visits = const [];
    try {
      visits = await LandLeadSiteVisitService.getPendingManagementVisits();
    } catch (_) {/* keep existing */}
    List<LandLeadSignedRequest> signed = const [];
    try {
      signed = await LandLeadSignedService.getPending();
    } catch (_) {/* table may not exist yet */}
    List<LeadDropApprovalRequest> dropRequests = const [];
    try {
      dropRequests = await LeadDropApprovalService.getPending();
    } catch (_) {/* notification storage may not exist yet */}
    if (mounted) {
      setState(() {
        _pendingApprovals = visits;
        _pendingSigned = signed;
        _pendingDropApprovals = dropRequests;
        _loadingApprovals = false;
      });
    }
  }

  Future<void> _approveDropRequest(LeadDropApprovalRequest request) async {
    if (!RoleAccess.canApprove) {
      if (!mounted) return;
      AppFeedback.error(context, RoleAccess.deniedMessage('approve requests'));
      return;
    }
    try {
      await LeadDropApprovalService.review(request: request, approve: true);
      if (!mounted) return;
      AppFeedback.success(context, 'Drop request approved and lead dropped');
      await _loadPendingApprovals();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Could not approve drop request: $e');
    }
  }

  Future<void> _rejectDropRequest(LeadDropApprovalRequest request) async {
    if (!RoleAccess.canApprove) {
      if (!mounted) return;
      AppFeedback.error(context, RoleAccess.deniedMessage('approve requests'));
      return;
    }
    try {
      await LeadDropApprovalService.review(request: request, approve: false);
      if (!mounted) return;
      AppFeedback.info(context, 'Drop request rejected');
      await _loadPendingApprovals();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Could not reject drop request: $e');
    }
  }

  Future<void> _approveSignedRequest(LandLeadSignedRequest request) async {
    if (!RoleAccess.canApprove) {
      if (!mounted) return;
      AppFeedback.error(context, RoleAccess.deniedMessage('approve requests'));
      return;
    }
    try {
      await LandLeadSignedService.review(id: request.id, approve: true);
      if (!mounted) return;
      AppFeedback.success(context, 'Project approved and marked as Signed');
      await _loadPendingApprovals();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Could not approve: $e');
    }
  }

  Future<void> _rejectSignedRequest(LandLeadSignedRequest request) async {
    if (!RoleAccess.canApprove) {
      if (!mounted) return;
      AppFeedback.error(context, RoleAccess.deniedMessage('approve requests'));
      return;
    }
    try {
      await LandLeadSignedService.review(id: request.id, approve: false);
      if (!mounted) return;
      AppFeedback.info(context, 'Signed request rejected');
      await _loadPendingApprovals();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Could not reject: $e');
    }
  }

  Future<void> _reviewPendingVisit(LandLeadSiteVisit visit) async {
    final ok = await showManagementVisitReviewDialog(
      context,
      visitId: visit.id,
      leadId: visit.leadId,
    );
    if (ok == true && mounted) await _loadPendingApprovals();
  }

  Future<void> _approvePendingVisit(LandLeadSiteVisit visit) async {
    if (!RoleAccess.canApprove) {
      if (!mounted) return;
      AppFeedback.error(context, RoleAccess.deniedMessage('approve visits'));
      return;
    }
    try {
      await LandLeadSiteVisitService.review(
        visitId: visit.id,
        status: SiteVisitApprovalStatus.approved,
        notes: '',
      );
      if (!mounted) return;
      AppFeedback.success(context, 'Management site visit approved');
      await _loadPendingApprovals();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.error(context, 'Could not approve visit: $e');
    }
  }

  Future<void> _rejectPendingVisit(LandLeadSiteVisit visit) async {
    await _reviewPendingVisit(visit);
  }

  void _goTo(String route) => Navigator.pushNamed(context, route);

  void _openAllProjectsMap(List<LandLead> leads) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LeadsMapScreen(leads: leads)),
    );
  }

  void _openAddLead() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddLeadScreen()),
    ).then((saved) {
      if (saved is! LandLead || !mounted) return;
      AppStore.instance.addLead(saved);
      AppFeedback.success(context, 'Site ${saved.leadId} saved.');
    });
  }

  Widget _quickActionsSection(List<PortalQuickAction> actions) {
    return PortalFadeSection(
      index: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: 'Quick actions',
            icon: Icons.flash_on_rounded,
          ),
          PortalQuickActionsGrid(actions: actions),
        ],
      ),
    );
  }

  /// Opens the pending approvals list (management) directly — replaces the old
  /// always-visible Approvals dashboard section.
  void _openApprovalsList() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.fomraSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Future<void> wrap(Future<void> Function() fn) async {
            await fn();
            setSheet(() {});
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            maxChildSize: 0.95,
            minChildSize: 0.4,
            builder: (ctx, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.fomraBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PortalApprovalsSection(
                  visits: _pendingApprovals,
                  signedRequests: _pendingSigned,
                  dropRequests: _pendingDropApprovals,
                  leads: AppStore.instance.leads,
                  loading: _loadingApprovals,
                  onReview: (v) => wrap(() => _reviewPendingVisit(v)),
                  onApprove: (v) => wrap(() => _approvePendingVisit(v)),
                  onReject: (v) => wrap(() => _rejectPendingVisit(v)),
                  onApproveSigned: (r) => wrap(() => _approveSignedRequest(r)),
                  onRejectSigned: (r) => wrap(() => _rejectSignedRequest(r)),
                  onApproveDrop: (r) => wrap(() => _approveDropRequest(r)),
                  onRejectDrop: (r) => wrap(() => _rejectDropRequest(r)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final userName = user?.fullName ?? 'User';
    final displayName = portalHomeDisplayName(
      fullName: userName,
      isManagement: _isManagement,
    );
    final greeting = portalTimeGreeting(_clock, displayName);
    final dateLabel = portalHomeDateLabel(_clock);
    final leads = AppStore.instance.leads;
    final summaryLeads = _homeSummaryLeads;
    final totalLeads = summaryLeads.length;
    final ownerMeetingPending = summaryLeads
        .where((l) => l.status == LeadStatus.prospectMeetingPending)
        .length;
    final teamRows = buildPortalTeamPerformance(leads);

    final dropApprovalPending = _pendingDropApprovals.length;
    final approvalCount =
      _pendingApprovals.length + _pendingSigned.length + dropApprovalPending;

    final quickActions = [
      if (!_isManagement)
        PortalQuickAction(
          label: 'Add Lead',
          icon: Icons.add_location_alt_outlined,
          accent: AppColors.primary,
          onTap: _openAddLead,
        ),
      PortalQuickAction(
        label: 'Show All Projects',
        icon: Icons.map_outlined,
        accent: AppColors.info,
        onTap: () => _openAllProjectsMap(leads),
      ),
      PortalQuickAction(
        label: 'Owner Details',
        icon: Icons.person_outline,
        accent: AppColors.success,
        onTap: () => _goTo('/owner-history'),
      ),
      PortalQuickAction(
        label: 'Broker Details',
        icon: Icons.handshake_outlined,
        accent: AppColors.secondary,
        onTap: () => _goTo('/broker-management'),
      ),
    ];

    return FomraAppShell(
      currentRoute: '/home',
      appBar: FomraAppBar(
        actions: [
          CompositedTransformTarget(
            link: _notifLink,
            child: Stack(clipBehavior: Clip.none, children: [
            IconButton(
              icon: Icon(
                _notifOpen
                    ? Icons.notifications
                    : Icons.notifications_outlined,
                size: 22,
              ),
              onPressed: _toggleNotifications,
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _unreadCount > 9 ? '9+' : '$_unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ]),
          ),
        ],
      ),
      backgroundColor: context.fomraPageBg,
      body: Column(
        children: [
          const OfflineStatusBanner(),
          Expanded(
            child: SingleChildScrollView(
        padding: FomraLayout.pagePadding(context),
        child: portalHomeWidthConstraint(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PortalFadeSection(
                index: 0,
                child: PortalWelcomeHeader(
                  greeting: greeting,
                  dateLabel: dateLabel,
                  totalLeads: totalLeads,
                  activeLeads: _activeLeads,
                  thirdLabel:
                      _isManagement ? 'Approval Pending' : 'Owner meeting pending',
                  thirdValue:
                      _isManagement ? approvalCount : ownerMeetingPending,
                  thirdIcon: _isManagement
                      ? Icons.approval_outlined
                      : Icons.event_available_outlined,
                    onThirdTap: _isManagement
                      ? _openApprovalsList
                      : () => FilteredLeadsScreen.open(
                          context, LeadListFilter.ownerMeetingPending),
                  onSummaryTap: (filter) {
                    // "Total sites" opens the full Land Workspace directly;
                    // the other tiles open their filtered list.
                    if (filter == LeadListFilter.totalLeads) {
                      _goTo('/land-lead');
                    } else {
                      FilteredLeadsScreen.open(context, filter);
                    }
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_isManagement) ...[
                _quickActionsSection(quickActions),
                const SizedBox(height: AppSpacing.lg),
                PortalFadeSection(
                  index: 2,
                  child: ManagementExecutiveDashboard(
                    leads: leads,
                    teamRows: teamRows,
                    notifications: _notifications,
                    widgetIds: const [
                      'pipelineDeals',
                      'leaderboard',
                      'bottlenecks',
                      'district',
                      'ageing',
                    ],
                    onViewLead: (lead) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LeadDetailScreen(lead: lead),
                        ),
                      );
                    },
                  ),
                ),
              ] else ...[
                // Employee order: Greeting, Today's Tasks, Quick Actions, Perf.
                PortalFadeSection(
                  index: 1,
                  child: _EmployeeTodayTasksSection(
                    employeeName: userName,
                    onOpenLead: (lead) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LeadDetailScreen(lead: lead),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _quickActionsSection(quickActions),
                const SizedBox(height: AppSpacing.lg),
                PortalFadeSection(
                  index: 3,
                  child: PortalSectionCard(
                    title: 'My performance',
                    subtitle: 'Your site contribution this period',
                    icon: Icons.groups_rounded,
                    child: _EmployeePerformanceCard(
                      count: _myLeadCount,
                      onTap: () => _goTo('/land-lead'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 88),
            ],
          ),
        ),
      ),
          ),
        ],
      ),
    );
  }
}

class _EmployeePerformanceCard extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const _EmployeePerformanceCard({required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      radius: AppColors.radiusMd,
      interactive: onTap != null,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.emoji_events_outlined,
              size: 17,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sites Added',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.fomraTextPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Your total contribution to the pipeline',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: context.fomraTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCounter(
            value: count,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: 18,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeTodayTasksSection extends StatelessWidget {
  final String employeeName;
  final ValueChanged<LandLead> onOpenLead;

  const _EmployeeTodayTasksSection({
    required this.employeeName,
    required this.onOpenLead,
  });

  String _leadLabel(LandLead lead) {
    if (lead.ownerName.trim().isNotEmpty) return lead.ownerName.trim();
    return 'Site #${lead.leadId}';
  }

  List<LandLead> get _myActiveLeads => AppStore.instance.leads
      .where((l) =>
          l.createdByName.trim() == employeeName.trim() && l.status.isActive)
      .toList();

  void _openCategory(
    BuildContext context,
    String title,
    Color color,
    List<LandLead> leads,
  ) {
    if (leads.isEmpty) return;
    FilteredLeadsScreen.openList(
      context,
      title: title,
      subtitle: '$title follow-up queue',
      leads: leads,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = _myActiveLeads;
    final categories = <
        ({String label, IconData icon, Color color, List<LandLead> leads})>[
      (
        label: 'Call Pending',
        icon: Icons.call_outlined,
        color: AppColors.info,
        leads: mine
            .where((l) => l.status == LeadStatus.negotiation)
            .toList(),
      ),
      (
        label: 'Meeting Pending',
        icon: Icons.groups_outlined,
        color: LeadStatus.prospectMeetingPending.color,
        leads: mine
            .where((l) => l.status == LeadStatus.prospectMeetingPending)
            .toList(),
      ),
      (
        label: 'Site Visit Pending',
        icon: Icons.location_on_outlined,
        color: LeadStatus.prospectMeetingCompleted.color,
        leads: mine
            .where((l) => l.status == LeadStatus.prospectMeetingCompleted)
            .toList(),
      ),
      (
        label: 'Legal Pending',
        icon: Icons.gavel_outlined,
        color: LeadStatus.legal.color,
        leads: mine.where((l) => l.status == LeadStatus.legal).toList(),
      ),
    ];
    final total = categories.fold<int>(0, (s, c) => s + c.leads.length);

    return PortalSectionCard(
      title: "Today's tasks",
      subtitle: 'Compact follow-up cards',
      icon: Icons.today_rounded,
      child: total == 0
          ? const EmptyState(
              icon: Icons.task_alt_outlined,
              title: 'No pending tasks',
              message:
                  'Active leads you add will show pending follow-ups here.',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final twoCols = constraints.maxWidth >= 360;
                final cardWidth = twoCols
                    ? (constraints.maxWidth - AppSpacing.sm) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final c in categories)
                      SizedBox(
                        width: cardWidth,
                        child: _TaskSummaryCard(
                          label: c.label,
                          count: c.leads.length,
                          icon: c.icon,
                          color: c.color,
                          subtitle: switch (c.label) {
                            'Call Pending' => 'Follow up by call',
                            'Meeting Pending' => 'Land owner meeting due',
                            'Site Visit Pending' => 'Schedule the site visit',
                            _ => 'Legal verification pending',
                          },
                          onTap: c.leads.isEmpty
                              ? null
                              : () => _openCategory(context, c.label, c.color, c.leads),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _TaskSummaryCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _TaskSummaryCard({
    required this.label,
    required this.subtitle,
    required this.count,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      radius: AppColors.radiusMd,
      interactive: onTap != null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle,
              style: TextStyle(fontSize: 10.5, color: context.fomraTextSecondary)),
        ],
      ),
    );
  }
}

// ── Notifications Dropdown ────────────────────────────────────────────────────

/// An anchored dropdown panel that opens under the notification bell on click.
class _NotificationsDropdown extends StatelessWidget {
  final LayerLink link;
  final List<AppNotification> notifications;
  final VoidCallback onDismiss;
  final void Function(String id) onMarkRead;
  final VoidCallback onMarkAllRead;
  final void Function(AppNotification n) onOpen;
  final VoidCallback? onViewAll;
  const _NotificationsDropdown({
    required this.link,
    required this.notifications,
    required this.onDismiss,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onOpen,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final width = screen.width < 400 ? screen.width - 24 : 380.0;
    final maxHeight = (screen.height * 0.6).clamp(240.0, 520.0);

    return Stack(
      children: [
        // Tap outside to close.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: link,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(8, 10),
          child: Align(
            alignment: Alignment.topRight,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: width,
                constraints: BoxConstraints(maxHeight: maxHeight),
                decoration: BoxDecoration(
                  color: context.fomraSurface,
                  borderRadius: BorderRadius.circular(AppColors.radiusLg),
                  border: Border.all(color: context.fomraBorder),
                  boxShadow: AppColors.elevatedShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(18, 14, 10, 10),
                      child: Row(children: [
                        const Text('Notifications',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (notifications.isNotEmpty)
                          TextButton(
                            onPressed: onMarkAllRead,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('Mark all read',
                                style: TextStyle(fontSize: 12)),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: onDismiss,
                        ),
                      ]),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: notifications.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 36),
                              child: EmptyState(
                                icon: Icons.notifications_none_rounded,
                                title: 'No notifications yet',
                                message:
                                    'Updates about leads, tasks, and assignments will show up here.',
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: notifications.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final n = notifications[i];
                                return ListTile(
                                  dense: true,
                                  leading: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: _typeColor(n.type)
                                        .withValues(alpha: 0.1),
                                    child: Icon(_typeIcon(n.type),
                                        color: _typeColor(n.type), size: 15),
                                  ),
                                  title: Text(n.title,
                                      style: TextStyle(
                                          fontWeight: n.isRead
                                              ? FontWeight.normal
                                              : FontWeight.w600,
                                          fontSize: 13.5)),
                                  subtitle: Text(n.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12)),
                                  trailing: n.isRead
                                      ? null
                                      : Container(
                                          width: 7, height: 7,
                                          decoration: const BoxDecoration(
                                              color: AppColors.primary,
                                              shape: BoxShape.circle),
                                        ),
                                  onTap: () {
                                    onMarkRead(n.id);
                                    onOpen(n);
                                  },
                                  tileColor: n.isRead
                                      ? null
                                      : AppColors.primary
                                          .withValues(alpha: 0.03),
                                );
                              },
                            ),
                    ),
                    const Divider(height: 1),
                    if (onViewAll != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                        child: TextButton.icon(
                          onPressed: onViewAll,
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Open Notification Center'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _typeColor(NotificationType t) => switch (t) {
        NotificationType.lead ||
        NotificationType.assignedLead =>
          AppColors.info,
        NotificationType.pendingLead => AppColors.warning,
        NotificationType.pendingApproval => AppColors.secondary,
        NotificationType.slaBreach ||
        NotificationType.overdueTask ||
        NotificationType.alert =>
          AppColors.error,
        NotificationType.reminder || NotificationType.siteVisit =>
          AppColors.primary,
        NotificationType.task => AppColors.warning,
        NotificationType.document => AppColors.success,
        NotificationType.verification => AppColors.secondary,
      };

  IconData _typeIcon(NotificationType t) => switch (t) {
        NotificationType.lead ||
        NotificationType.assignedLead =>
          Icons.person_add_alt_1_outlined,
        NotificationType.pendingLead => Icons.hourglass_top_rounded,
        NotificationType.pendingApproval => Icons.approval_outlined,
        NotificationType.slaBreach => Icons.timer_off_outlined,
        NotificationType.overdueTask => Icons.warning_amber_rounded,
        NotificationType.reminder => Icons.notifications_active_outlined,
        NotificationType.task => Icons.task_alt,
        NotificationType.document => Icons.description,
        NotificationType.alert => Icons.warning_amber,
        NotificationType.verification => Icons.verified,
        NotificationType.siteVisit => Icons.apartment_outlined,
      };
}

// ── Top-right toast overlay ───────────────────────────────────────────────────

class _ToastData {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  _ToastData({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });
}

/// Hosts a top-right column of stacked toasts. New toasts slide in from the
/// right, auto-dismiss after 4s, and can be swiped right to close.
class _ToastStack extends StatefulWidget {
  const _ToastStack({super.key});

  @override
  State<_ToastStack> createState() => _ToastStackState();
}

class _ToastStackState extends State<_ToastStack> {
  final List<({int id, _ToastData data})> _toasts = [];
  int _seq = 0;

  void push(_ToastData data) {
    final id = _seq++;
    setState(() => _toasts.add((id: id, data: data)));
    Future.delayed(const Duration(seconds: 4), () => _remove(id));
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() => _toasts.removeWhere((t) => t.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Anchor bottom-right, clearing the floating bottom nav bar (~72px + inset).
    return Positioned(
      bottom: media.padding.bottom + 88,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final t in _toasts)
                _ToastCard(
                  key: ValueKey(t.id),
                  data: t.data,
                  onDismiss: () => _remove(t.id),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  final _ToastData data;
  final VoidCallback onDismiss;
  const _ToastCard({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    final d = widget.data;
    // Slide the whole card in from off the right edge.
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.15, 0),
          end: Offset.zero,
        ).animate(curve),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: ValueKey('toast-${widget.key}'),
            direction: DismissDirection.startToEnd, // swipe right to close
            onDismissed: (_) => widget.onDismiss(),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: AppColors.border),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1F000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Colored icon chip keeps the type accent on the white card.
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: d.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(d.icon, color: d.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (d.message.isNotEmpty)
                          Text(
                            d.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Close (X) button — tap to dismiss.
                  InkWell(
                    onTap: widget.onDismiss,
                    borderRadius: BorderRadius.circular(999),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close,
                          color: AppColors.textSecondary, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
