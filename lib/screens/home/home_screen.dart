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
import '../../theme/fomra_theme_context.dart';
import '../../models/app_notification.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';

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

  int get _totalLeads  => AppStore.instance.leads.length;
  int get _activeLeads => AppStore.instance.leads
      .where((l) => [LeadStatus.new_, LeadStatus.contacted,
                     LeadStatus.siteVisit, LeadStatus.negotiation]
          .contains(l.status))
      .length;
  int get _brokerLeads => AppStore.instance.leads
      .where((l) => l.inputSource == InputSource.broker).length;

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get _isManagement => AuthService.instance.isManagement;

  /// Per-employee "leads added" leaderboard, highest first.
  List<_LeadPerf> get _performance {
    final counts = <String, int>{};
    for (final l in AppStore.instance.leads) {
      final name = l.createdByName.trim();
      if (name.isEmpty) continue;
      // Management is not part of the employee leaderboard.
      if (name.toLowerCase() == 'management') continue;
      counts[name] = (counts[name] ?? 0) + 1;
    }

    final employees = AppStore.instance.employees;
    final result = <_LeadPerf>[];
    if (employees.isNotEmpty) {
      for (final e in employees) {
        result.add(_LeadPerf(
            e.fullName, e.designation, counts[e.fullName.trim()] ?? 0));
      }
      // Include lead creators who aren't in the roster (e.g. removed staff).
      for (final entry in counts.entries) {
        final inRoster =
            employees.any((e) => e.fullName.trim() == entry.key);
        if (!inRoster) result.add(_LeadPerf(entry.key, '', entry.value));
      }
    } else {
      for (final entry in counts.entries) {
        result.add(_LeadPerf(entry.key, '', entry.value));
      }
    }

    result.sort((a, b) => b.count.compareTo(a.count));
    return result;
  }

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

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final userName = user?.fullName ?? 'User';
    final userEmail = user?.email ?? '';

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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GreetingHeader(
              userName: userName,
              onProfileTap: () => _showProfileMenu(userName, userEmail),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HomeSection(
                    title: 'Overview',
                    child: Row(children: [
                      _KpiChip(
                        label: 'Total Leads',
                        value: _totalLeads,
                        color: const Color(0xFF2563EB),
                        icon: Icons.analytics_outlined,
                        trend: '+12%',
                      ),
                      const SizedBox(width: 12),
                      _KpiChip(
                        label: 'Active',
                        value: _activeLeads,
                        color: const Color(0xFF16A34A),
                        icon: Icons.trending_up_outlined,
                        trend: '+6%',
                      ),
                      const SizedBox(width: 12),
                      _KpiChip(
                        label: 'Broker',
                        value: _brokerLeads,
                        color: AppColors.purple,
                        icon: Icons.handshake_outlined,
                        trend: '+3%',
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  _HomeSection(
                    title: _isManagement ? 'Team performance' : 'My performance',
                    child: _isManagement
                        ? _PerformanceList(entries: _performance)
                        : _MyPerformanceContent(count: _myLeadCount),
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

// ── Greeting Header (clean, light) ────────────────────────────────────────────

class _GreetingHeader extends StatefulWidget {
  final String userName;
  final VoidCallback onProfileTap;
  const _GreetingHeader({required this.userName, required this.onProfileTap});

  @override
  State<_GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends State<_GreetingHeader> {
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.userName.trim().split(RegExp(r'\s+')).first;
    final greeting = firstName.isEmpty
        ? _greetingFor(_now)
        : '${_greetingFor(_now)}, $firstName';
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_greetIconFor(_now),
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: context.fomraTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formattedDate(_now),
                  style: TextStyle(
                      fontSize: 13, color: context.fomraTextSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.onProfileTap,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greetingFor(DateTime dt) {
    final hour = dt.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  IconData _greetIconFor(DateTime dt) {
    final hour = dt.hour;
    if (hour < 12) return Icons.wb_sunny_outlined;
    if (hour < 17) return Icons.wb_cloudy_outlined;
    return Icons.nights_stay_outlined;
  }

  String _formattedDate(DateTime now) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

// ── Section card (white card with a heading) ──────────────────────────────────

class _HomeSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _HomeSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.fomraSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.fomraBorder),
        boxShadow: context.fomraCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ── KPI Chip ─────────────────────────────────────────────────────────────────

// ── Performance ───────────────────────────────────────────────────────────────

class _LeadPerf {
  final String name;
  final String designation;
  final int count;
  const _LeadPerf(this.name, this.designation, this.count);
}

class _MyPerformanceContent extends StatelessWidget {
  final int count;
  const _MyPerformanceContent({required this.count});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF0EA5E9);
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.emoji_events_outlined, color: color, size: 22),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Leads added',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.fomraTextPrimary)),
          const SizedBox(height: 2),
          Text('Your total contribution',
              style: TextStyle(
                  fontSize: 12, color: context.fomraTextSecondary)),
        ]),
      ),
      Text('$count',
          style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5)),
    ]);
  }
}

class _PerformanceList extends StatelessWidget {
  final List<_LeadPerf> entries;
  const _PerformanceList({required this.entries});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF0EA5E9);
    final maxCount =
        entries.isEmpty ? 0 : entries.map((e) => e.count).reduce((a, b) => a > b ? a : b);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (entries.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text('No employee lead activity yet.',
              style: TextStyle(
                  fontSize: 13, color: context.fomraTextSecondary)),
        )
      else
        ...List.generate(entries.length, (i) {
            final e = entries[i];
            final frac = maxCount == 0 ? 0.0 : e.count / maxCount;
            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.12),
                  child: Text(
                    e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(
                            e.name.isEmpty ? 'Unknown' : e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.fomraTextPrimary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${e.count}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: color)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 6,
                          backgroundColor: color.withValues(alpha: 0.10),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      if (e.designation.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(e.designation,
                            style: TextStyle(
                                fontSize: 11,
                                color: context.fomraTextSecondary)),
                      ],
                    ],
                  ),
                ),
              ]),
            );
          }),
    ]);
  }
}

class _KpiChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;
  final String trend;
  const _KpiChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.fomraSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withValues(alpha: 0.22)),
            boxShadow: context.fomraCardShadow,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  trend,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Text('$value',
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0,
                    letterSpacing: -1.0)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.fomraTextSecondary)),
          ]),
        ),
      );
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
