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

class _HomeScreenState extends State<HomeScreen> {
  List<AppNotification> _notifications = [];
  RealtimeChannel? _notifChannel;

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
    AppStore.instance.removeListener(_onStoreUpdate);
    _notifChannel?.unsubscribe();
    super.dispose();
  }

  void _onStoreUpdate() => setState(() {});

  Future<void> _loadNotifications() async {
    try {
      final list = await NotificationsService.getAll(audience: _notifAudience);
      final filtered = list
          .where((n) => !_isManagementLeadNotification(n) && _isForMe(n))
          .toList();
      if (mounted) setState(() => _notifications = filtered);
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

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationsSheet(
        notifications: _notifications,
        onMarkRead: (id) {
          setState(() {
            _notifications.firstWhere((n) => n.id == id).isRead = true;
          });
          NotificationsService.markRead(id).catchError((_) {});
        },
        onMarkAllRead: () {
          setState(() {
            for (final n in _notifications) { n.isRead = true; }
          });
          NotificationsService.markAllRead(audience: _notifAudience)
              .catchError((_) {});
        },
        onOpen: (n) {
          Navigator.pop(context); // close the notifications sheet
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
  }

  void _showProfileMenu(String name, String email) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        decoration: BoxDecoration(
          color: context.fomraSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: context.fomraCardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(Icons.person_outline,
                  size: 28, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Text(name,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.fomraTextPrimary)),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(email,
                  style: TextStyle(
                      fontSize: 13, color: context.fomraTextSecondary)),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_outline,
                    size: 20, color: AppColors.primary),
              ),
              title: const Text('Change Password',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ChangePasswordScreen()),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.logout_rounded,
                    size: 20, color: AppColors.error),
              ),
              title: const Text('Sign Out',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.error)),
              trailing: const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.error),
              onTap: () {
                Navigator.pop(ctx);
                AuthService.instance.logout();
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (_) => false);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _goTo(String route) => Navigator.pushNamed(context, route);

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final userName = user?.fullName ?? 'User';
    final userEmail = user?.email ?? '';
    final now = DateTime.now();
    final leads = AppStore.instance.leads;
    final newLeads =
        leads.where((l) => l.status == LeadStatus.new_).length;
    final negotiation =
        leads.where((l) => l.status == LeadStatus.negotiation).length;
    final pendingActions = newLeads + negotiation;
    final addedToday =
        leads.where((l) => portalIsSameDay(l.addedOn, now)).length;
    final teamRows = buildPortalTeamPerformance(leads);

    final quickActions = [
      PortalQuickAction(
        label: 'Add Lead',
        subtitle: 'Capture new parcel',
        icon: Icons.add_location_alt_outlined,
        accent: const Color(0xFF2563EB),
        onTap: () => _goTo('/land-lead'),
      ),
      PortalQuickAction(
        label: 'Create Task',
        subtitle: 'Assign the team',
        icon: Icons.playlist_add_check_circle_outlined,
        accent: const Color(0xFF8B5CF6),
        onTap: () => _goTo('/task-management'),
      ),
      PortalQuickAction(
        label: 'View Dashboard',
        subtitle: 'KPIs and funnel',
        icon: Icons.assessment_outlined,
        accent: const Color(0xFFF59E0B),
        onTap: () => _goTo('/dashboard'),
      ),
      PortalQuickAction(
        label: 'Search Property',
        subtitle: 'Open market intel',
        icon: Icons.travel_explore_outlined,
        accent: const Color(0xFF10B981),
        onTap: () => _goTo('/market-intelligence'),
      ),
      if (_isManagement)
        PortalQuickAction(
          label: 'Add Employee',
          subtitle: 'Manage workforce',
          icon: Icons.person_add_alt_1_outlined,
          accent: const Color(0xFF6366F1),
          onTap: () => _goTo('/employee-management'),
        ),
    ];

    return Scaffold(
      appBar: FomraAppBar(
        actions: [
          Stack(clipBehavior: Clip.none, children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, size: 22),
              onPressed: _showNotifications,
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  width: 14, height: 14,
                  decoration: const BoxDecoration(
                      color: AppColors.accent, shape: BoxShape.circle),
                  child: Center(
                    child: Text('$_unreadCount',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ]),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/home'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/home'),
      backgroundColor: context.fomraPageBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: FomraLayout.pagePadding(context),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PortalWelcomeHeader(
                    userName: userName,
                    dateLabel: portalDateLabel(now),
                    todayTasks: addedToday,
                    activeLeads: _activeLeads,
                    pendingActions: pendingActions,
                    onProfileTap: () =>
                        _showProfileMenu(userName, userEmail),
                  ),
                  const SizedBox(height: 20),
                  const SectionHeader(
                    title: 'Quick actions',
                    subtitle:
                        'Shortcuts into lead capture, tasks, and analytics.',
                    icon: Icons.flash_on_rounded,
                  ),
                  PortalQuickActionsGrid(actions: quickActions),
                  const SizedBox(height: 20),
                  PortalSectionCard(
                    title: _isManagement
                        ? 'Team performance'
                        : 'My performance',
                    subtitle: _isManagement
                        ? 'Ranking, progress, and today’s activity by team member.'
                        : 'Your lead contribution this period.',
                    icon: Icons.groups_rounded,
                    child: _isManagement
                        ? (teamRows.isEmpty
                            ? EmptyState(
                                icon: Icons.groups_outlined,
                                title: 'No leads yet',
                                message:
                                    'Create your first lead to start tracking team performance.',
                                action: PrimaryButton(
                                  label: 'Add Lead',
                                  icon: Icons.add_location_alt_outlined,
                                  onPressed: () => _goTo('/land-lead'),
                                ),
                              )
                            : Column(
                                children: [
                                  for (final row in teamRows) ...[
                                    PortalPerformanceRow(data: row),
                                    if (row != teamRows.last)
                                      const SizedBox(height: 12),
                                  ],
                                ],
                              ))
                        : _EmployeePerformanceCard(count: _myLeadCount),
                  ),
                  const SizedBox(height: 96),
                ],
              ),
            ),
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

// ── Notifications Sheet ───────────────────────────────────────────────────────

class _NotificationsSheet extends StatelessWidget {
  final List<AppNotification> notifications;
  final void Function(String id) onMarkRead;
  final VoidCallback onMarkAllRead;
  final void Function(AppNotification n) onOpen;
  const _NotificationsSheet({
    required this.notifications,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, controller) => Column(children: [
          const SizedBox(height: 10),
          Container(
            width: 32, height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(children: [
              const Text('Notifications',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (notifications.isNotEmpty)
                TextButton(
                  onPressed: () {
                    onMarkAllRead();
                    Navigator.pop(context);
                  },
                  child: const Text('Mark all read'),
                ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: context.fomraSurfaceVar,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.notifications_none,
                              size: 32, color: context.fomraTextSecondary),
                        ),
                        const SizedBox(height: 10),
                        Text('No notifications yet',
                            style: TextStyle(
                                color: context.fomraTextSecondary,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final n = notifications[i];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              _typeColor(n.type).withValues(alpha: 0.1),
                          child: Icon(_typeIcon(n.type),
                              color: _typeColor(n.type), size: 16),
                        ),
                        title: Text(n.title,
                            style: TextStyle(
                                fontWeight: n.isRead
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                                fontSize: 14)),
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
                            : AppColors.primary.withValues(alpha: 0.03),
                      );
                    },
                  ),
          ),
        ]),
      ),
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
