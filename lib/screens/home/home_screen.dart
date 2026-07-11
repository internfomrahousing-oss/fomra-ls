import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/land_lead.dart';
import '../../utils/employee_today_tasks.dart';
import '../land_lead/add_lead_screen.dart';
import '../land_lead/filtered_leads_screen.dart';
import '../land_lead/lead_detail_screen.dart';
import '../land_lead/leads_map_screen.dart';
import '../task_management/task_management_screen.dart';
import 'contact_directory_screen.dart';
import '../settings/change_password_screen.dart';
import '../../services/auth_service.dart';
import '../../services/app_store.dart';
import '../../services/employee_service.dart';
import '../../services/land_lead_service.dart';
import '../../services/notifications_service.dart';
import '../../services/push_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../models/app_notification.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
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

  String get _notifAudience =>
      AuthService.instance.isManagement ? 'management' : 'employee';

  int get _activeLeads =>
      AppStore.instance.leads.where((l) => l.status.isActive).length;

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
    _notifChannel = NotificationsService.subscribe(
      audience: _notifAudience,
      onChange: _loadNotifications,
    );
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
  int get _myLeadCount {
    final me = (AuthService.instance.currentUser?.fullName ?? '').trim();
    if (me.isEmpty) return 0;
    return AppStore.instance.leads
        .where((l) => l.createdByName.trim() == me)
        .length;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AppStore.instance.removeListener(_onStoreUpdate);
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

  String get _profileRole =>
      _isManagement ? 'Administrator' : 'Employee';

  Future<void> _loadNotifications() async {
    try {
      final list = await NotificationsService.getAll(audience: _notifAudience);
      final filtered = list
          .where((n) => !_isManagementLeadNotification(n) && _isForMe(n))
          .toList();
      if (mounted) {
        _emitNewNotificationToasts(filtered);
        setState(() => _notifications = filtered);
        _notifOverlay?.markNeedsBuild(); // refresh the open dropdown live
      }
    } catch (_) {
      // Keep the current list if the fetch fails (e.g. table not created yet).
    }
  }

  // Don't surface lead notifications for leads management uploaded itself.
  bool _isManagementLeadNotification(AppNotification n) =>
      n.type == NotificationType.lead &&
      n.title.toLowerCase().contains('by management');

  /// An assignment notification is only for the employees it was assigned to.
  /// The assignees are named in the message ("… — assigned to pooja, vijay"),
  /// so an employee only sees it when their own name is in that list. Management
  /// and all non-assignment notifications are shown as-is.
  bool _isForMe(AppNotification n) {
    if (_isManagement) return true;
    const marker = 'assigned to ';
    final msg = n.message.toLowerCase();
    final idx = msg.lastIndexOf(marker);
    if (idx == -1) return true; // can't tell who it's for → show it
    final me = (AuthService.instance.currentUser?.fullName ?? '')
        .trim()
        .toLowerCase();
    if (me.isEmpty) return true;
    final assignees =
        msg.substring(idx + marker.length).split(',').map((s) => s.trim());
    return assignees.contains(me);
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
        NotificationType.lead         => AppColors.info,
        NotificationType.task         => AppColors.warning,
        NotificationType.document     => AppColors.success,
        NotificationType.alert        => AppColors.error,
        NotificationType.verification => AppColors.secondary,
      };

  IconData _notifTypeIcon(NotificationType t) => switch (t) {
        NotificationType.lead         => Icons.location_on,
        NotificationType.task         => Icons.task_alt,
        NotificationType.document     => Icons.description,
        NotificationType.alert        => Icons.warning_amber,
        NotificationType.verification => Icons.verified,
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
        onOpen: (n) {
          _hideNotifications();
          if (n.type != NotificationType.lead) return;
          // Open the specific lead's detail when we can resolve it; otherwise
          // fall back to the land lead list.
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
          } else {
            Navigator.pushNamed(context, '/land-lead');
          }
        },
      ),
    );
    Overlay.of(context).insert(_notifOverlay!);
    setState(() {}); // repaint the bell in its active state
  }

  Future<void> _showProfileMenu(TapDownDetails details) async {
    final user = AuthService.instance.currentUser;
    final userName = user?.fullName ?? 'User';
    final profileName = _isManagement ? 'Management' : userName;
    final initial =
        profileName.isNotEmpty ? profileName[0].toUpperCase() : 'U';

    final action = await showPortalProfileMenu(
      context: context,
      anchor: details.globalPosition,
      name: profileName,
      role: _profileRole,
      initial: initial,
    );
    if (!mounted) return;
    if (action == 'change_password') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
      );
      return;
    }
    if (action == 'sign_out') {
      final confirmed = await confirmSignOut(context);
      if (!confirmed || !mounted) return;
      AuthService.instance.logout();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
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
    final totalLeads = leads.length;
    final brokerLeads =
        leads.where((l) => l.inputSource == InputSource.broker).length;
    final teamRows = buildPortalTeamPerformance(leads);
    final leadsByEmployee = <String, List<LandLead>>{};
    for (final lead in leads) {
      final name = lead.createdByName.trim();
      if (name.isEmpty || name.toLowerCase() == 'management') continue;
      leadsByEmployee.putIfAbsent(name, () => []).add(lead);
    }

    final quickActions = [
      if (_isManagement)
        PortalQuickAction(
          label: 'View Leads',
          icon: Icons.list_alt_outlined,
          accent: AppColors.primary,
          onTap: () => _goTo('/land-lead'),
        )
      else
        PortalQuickAction(
          label: 'Add Leads',
          icon: Icons.add_location_alt_outlined,
          accent: AppColors.primary,
          onTap: _openAddLead,
        ),
      if (_isManagement)
        PortalQuickAction(
          label: 'Show all projects map',
          icon: Icons.map_outlined,
          accent: AppColors.info,
          onTap: () => _openAllProjectsMap(leads),
        ),
      PortalQuickAction(
        label: 'Owner details',
        icon: Icons.person_outline,
        accent: AppColors.success,
        onTap: () => ContactDirectoryScreen.open(
          context,
          kind: ContactDirectoryKind.owner,
        ),
      ),
      PortalQuickAction(
        label: 'Broker details',
        icon: Icons.handshake_outlined,
        accent: AppColors.secondary,
        onTap: () => ContactDirectoryScreen.open(
          context,
          kind: ContactDirectoryKind.broker,
        ),
      ),
      if (_isManagement)
        PortalQuickAction(
          label: 'View Dashboard',
          icon: Icons.assessment_outlined,
          accent: AppColors.warning,
          onTap: () => _goTo('/dashboard'),
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
      body: SingleChildScrollView(
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
                  profileName: _isManagement ? 'Management' : userName,
                  profileRole: _profileRole,
                  totalLeads: totalLeads,
                  activeLeads: _activeLeads,
                  brokerLeads: brokerLeads,
                  onProfileTapDown: _showProfileMenu,
                  onSummaryTap: (filter) =>
                      FilteredLeadsScreen.open(context, filter),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PortalFadeSection(
                index: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: 'Quick actions',
                      icon: Icons.flash_on_rounded,
                    ),
                    PortalQuickActionsGrid(actions: quickActions),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              PortalFadeSection(
                index: 2,
                child: PortalSectionCard(
                  title: _isManagement
                      ? 'Employee performance'
                      : 'My performance',
                  subtitle: _isManagement
                      ? 'Ranking and activity by employee'
                      : 'Your lead contribution this period',
                  icon: Icons.groups_rounded,
                  child: _isManagement
                      ? (teamRows.isEmpty
                          ? Column(
                              children: [
                                EmptyState(
                                  icon: Icons.groups_outlined,
                                  title: 'No leads yet',
                                  message:
                                      'Leads added by your employees will appear here automatically.',
                                  action: PrimaryButton(
                                    label: 'View Leads',
                                    icon: Icons.list_alt_outlined,
                                    onPressed: () => _goTo('/land-lead'),
                                  ),
                                ),
                                const PortalEmptyHint(
                                  hint:
                                      'Leads added by your employees will appear here automatically.',
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                for (final row in teamRows) ...[
                                  PortalPerformanceRow(
                                    data: row,
                                    leads: leadsByEmployee[row.name] ?? const [],
                                    onViewLead: (lead) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              LeadDetailScreen(lead: lead),
                                        ),
                                      );
                                    },
                                  ),
                                  if (row != teamRows.last)
                                    const SizedBox(height: AppSpacing.sm),
                                ],
                              ],
                            ))
                      : _EmployeePerformanceCard(count: _myLeadCount),
                ),
              ),
              if (!_isManagement) ...[
                const SizedBox(height: AppSpacing.lg),
                PortalFadeSection(
                  index: 3,
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
              ],
              const SizedBox(height: 88),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeePerformanceCard extends StatelessWidget {
  final int count;

  const _EmployeePerformanceCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      radius: AppColors.radiusMd,
      interactive: false,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.emoji_events_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leads added',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.fomraTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your total contribution to the pipeline',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.fomraTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCounter(
            value: count,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
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
    return 'Lead #${lead.leadId}';
  }

  String _formatDue(DateTime due) {
    final local = due.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final items = buildEmployeeTodayTasks(
      employeeName: employeeName,
      leads: AppStore.instance.leads,
      tasks: sharedTasks,
    );

    return PortalSectionCard(
      title: "Today's tasks",
      subtitle: 'Lead follow-ups and pending work for today',
      icon: Icons.today_rounded,
      child: items.isEmpty
          ? EmptyState(
              icon: Icons.task_alt_outlined,
              title: 'No tasks for today',
              message:
                  'Active leads you add will show follow-ups and pending work here.',
            )
          : Column(
              children: [
                for (final item in items) ...[
                  AppCard(
                    padding: const EdgeInsets.all(16),
                    radius: AppColors.radiusMd,
                    interactive: true,
                    onTap: () => onOpenLead(item.lead),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: item.lead.status.color
                                    .withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.person_pin_circle_outlined,
                                color: item.lead.status.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _leadLabel(item.lead),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: context.fomraTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Lead #${item.lead.leadId} · ${item.lead.status.shortLabel}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.fomraTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: context.fomraTextTertiary,
                            ),
                          ],
                        ),
                        if (item.followUp.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.notifications_active_outlined,
                                size: 16,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Follow-up',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.4,
                                        color: context.fomraTextSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.followUp,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: context.fomraTextPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (item.pendingWork.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Pending work',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                              color: context.fomraTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final work in item.pendingWork)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    work.isOverdue
                                        ? Icons.error_outline_rounded
                                        : work.isDueToday
                                            ? Icons.schedule_rounded
                                            : Icons.radio_button_unchecked_rounded,
                                    size: 15,
                                    color: work.isOverdue
                                        ? AppColors.error
                                        : work.isDueToday
                                            ? AppColors.warning
                                            : context.fomraTextSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      work.isOverdue
                                          ? '${work.label} · Overdue (${_formatDue(work.dueDate)})'
                                          : work.isDueToday
                                              ? '${work.label} · Due today'
                                              : '${work.label} · Due ${_formatDue(work.dueDate)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: work.isOverdue
                                            ? AppColors.error
                                            : context.fomraTextPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ] else if (item.followUp.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'No tasks created yet — tap to open lead and log activity.',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.fomraTextTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item != items.last) const SizedBox(height: AppSpacing.sm),
                ],
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
  const _NotificationsDropdown({
    required this.link,
    required this.notifications,
    required this.onDismiss,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onOpen,
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
        NotificationType.lead         => AppColors.info,
        NotificationType.task         => AppColors.warning,
        NotificationType.document     => AppColors.success,
        NotificationType.alert        => AppColors.error,
        NotificationType.verification => AppColors.secondary,
      };

  IconData _typeIcon(NotificationType t) => switch (t) {
        NotificationType.lead         => Icons.location_on,
        NotificationType.task         => Icons.task_alt,
        NotificationType.document     => Icons.description,
        NotificationType.alert        => Icons.warning_amber,
        NotificationType.verification => Icons.verified,
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
