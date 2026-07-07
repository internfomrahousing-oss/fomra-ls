import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/land_lead.dart';
import '../land_lead/lead_detail_screen.dart';
import '../settings/change_password_screen.dart';
import '../../services/auth_service.dart';
import '../../services/app_store.dart';
import '../../services/employee_service.dart';
import '../../services/land_lead_service.dart';
import '../../services/notifications_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../models/app_notification.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
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
  DateTime _clock = DateTime.now();

  // Anchored notification dropdown (opens under the bell on click).
  final LayerLink _notifLink = LayerLink();
  OverlayEntry? _notifOverlay;
  bool get _notifOpen => _notifOverlay != null;

  String get _notifAudience =>
      AuthService.instance.isManagement ? 'management' : 'employee';

  int get _activeLeads => AppStore.instance.leads
      .where((l) => [
            LeadStatus.new_,
            LeadStatus.contacted,
            LeadStatus.siteVisit,
            LeadStatus.negotiation,
          ].contains(l.status))
      .length;

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get _isManagement => AuthService.instance.isManagement;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppStore.instance.addListener(_onStoreUpdate);
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

  void _toggleNotifications() {
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
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromLTWH(
        details.globalPosition.dx,
        details.globalPosition.dy,
        1,
        1,
      ),
      Offset.zero & overlay.size,
    );
    final action = await showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      items: const [
        PopupMenuItem<String>(
          value: 'change_password',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.lock_outline),
            title: Text('Change Password'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem<String>(
          value: 'sign_out',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.logout_rounded, color: AppColors.error),
            title: Text('Sign Out', style: TextStyle(color: AppColors.error)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
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

    final quickActions = [
      PortalQuickAction(
        label: 'Add Lead',
        icon: Icons.add_location_alt_outlined,
        accent: AppColors.primary,
        onTap: () => _goTo('/land-lead'),
      ),
      PortalQuickAction(
        label: 'Create Task',
        icon: Icons.playlist_add_check_circle_outlined,
        accent: AppColors.purple,
        onTap: () => _goTo('/task-management'),
      ),
      PortalQuickAction(
        label: 'View Dashboard',
        icon: Icons.assessment_outlined,
        accent: AppColors.warning,
        onTap: () => _goTo('/dashboard'),
      ),
      PortalQuickAction(
        label: 'Search Property',
        icon: Icons.travel_explore_outlined,
        accent: AppColors.success,
        onTap: () => _goTo('/market-intelligence'),
      ),
      if (_isManagement)
        PortalQuickAction(
          label: 'Add Employee',
          icon: Icons.person_add_alt_1_outlined,
          accent: AppColors.secondary,
          onTap: () => _goTo('/employee-management'),
        ),
    ];

    return Scaffold(
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
      drawer: const AppDrawer(currentRoute: '/home'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/home'),
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
                                      'Create your first lead to start tracking employee performance.',
                                  action: PrimaryButton(
                                    label: 'Add Lead',
                                    icon: Icons.add_location_alt_outlined,
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
                                  PortalPerformanceRow(data: row),
                                  if (row != teamRows.last)
                                    const SizedBox(height: AppSpacing.sm),
                                ],
                              ],
                            ))
                      : _EmployeePerformanceCard(count: _myLeadCount),
                ),
              ),
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
