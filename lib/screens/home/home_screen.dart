import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/land_lead.dart';
import '../../services/auth_service.dart';
import '../../services/app_store.dart';
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
  final List<AppNotification> _notifications = [];

  int get _totalLeads  => AppStore.instance.leads.length;
  int get _activeLeads => AppStore.instance.leads
      .where((l) => [LeadStatus.new_, LeadStatus.contacted,
                     LeadStatus.siteVisit, LeadStatus.negotiation]
          .contains(l.status))
      .length;
  int get _brokerLeads => AppStore.instance.leads
      .where((l) => l.inputSource == InputSource.broker).length;

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;


  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_onStoreUpdate);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() => setState(() {});

  void _showNotifications() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationsSheet(
        notifications: _notifications,
        onMarkRead: (id) => setState(() {
          _notifications.firstWhere((n) => n.id == id).isRead = true;
        }),
        onMarkAllRead: () => setState(() {
          for (final n in _notifications) { n.isRead = true; }
        }),
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
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings_outlined,
                    size: 20, color: AppColors.primary),
              ),
              title: const Text('Settings',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
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
          const SizedBox(width: 4),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/home'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/home'),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeroBanner(
              userName: userName,
              userEmail: userEmail,
              onProfileTap: () => _showProfileMenu(userName, userEmail),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader('Overview'),
                  const SizedBox(height: 12),
                  Row(children: [
                    _KpiChip(
                      label: 'Total Leads',
                      value: _totalLeads,
                      color: const Color(0xFF2563EB),
                      icon: Icons.analytics_outlined,
                      trend: '+12%',
                    ),
                    const SizedBox(width: 16),
                    _KpiChip(
                      label: 'Active',
                      value: _activeLeads,
                      color: const Color(0xFF16A34A),
                      icon: Icons.trending_up_outlined,
                      trend: '+6%',
                    ),
                    const SizedBox(width: 16),
                    _KpiChip(
                      label: 'Broker',
                      value: _brokerLeads,
                      color: const Color(0xFF7C3AED),
                      icon: Icons.handshake_outlined,
                      trend: '+3%',
                    ),
                  ]),
                  const SizedBox(height: 24),

                  const _SectionHeader('Quick Actions'),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.8,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const _ActionCard(
                        icon: Icons.space_dashboard_outlined,
                        label: 'Land Workspace',
                        sub: 'Open',
                        route: '/land-lead',
                        gradient: LinearGradient(
                          colors: [Color(0xFF041E42), Color(0xFF1E3A8A)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      const _ActionCard(
                        icon: Icons.insights_outlined,
                        label: 'Market Intel',
                        sub: 'Open',
                        route: '/market-intelligence',
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F2B6E), Color(0xFF2563EB)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      if (AuthService.instance.isManagement)
                        const _ActionCard(
                          icon: Icons.dashboard_outlined,
                          label: 'Dashboard',
                          sub: 'Open',
                          route: '/dashboard',
                          gradient: LinearGradient(
                            colors: [Color(0xFF0A2348), Color(0xFF1A3A7A)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight,
                          ),
                        ),
                      const _ActionCard(
                        icon: Icons.settings_outlined,
                        label: 'Settings',
                        sub: 'Open',
                        route: '/settings',
                        gradient: LinearGradient(
                          colors: [Color(0xFF1E1B4B), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero Banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatefulWidget {
  final String userName;
  final String userEmail;
  final VoidCallback onProfileTap;
  const _HeroBanner({
    required this.userName,
    required this.userEmail,
    required this.onProfileTap,
  });

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat(reverse: true);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = _formattedTime(_now);
    final greeting = _greetingFor(_now);
    final greetIcon = _greetIconFor(_now);
    final isDark = context.isDarkMode;
    final greetColor = _greetingAccent(_now);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(gradient: context.fomraHeroGradient),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => Stack(children: [
          Positioned(
            right: -35 + (_controller.value * 18),
            top: -32,
            child: _Blob(
              170,
              isDark ? AppColors.primaryLight : Colors.white,
              isDark ? 0.14 : 0.05,
            ),
          ),
          Positioned(
            right: 48,
            bottom: -30 + (_controller.value * 12),
            child: _Blob(
              118,
              isDark ? AppColors.secondary : Colors.white,
              isDark ? 0.12 : 0.04,
            ),
          ),
          Positioned(
            left: -24 + (_controller.value * 10),
            bottom: 4,
            child: _Blob(84, AppColors.accent, isDark ? 0.16 : 0.09),
          ),
          if (isDark)
            Positioned(
              left: 120 + (_controller.value * 8),
              top: 8,
              child: const _Blob(56, Color(0xFF22D3EE), 0.1),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: isDark
                                ? [
                                    Colors.white,
                                    AppColors.primaryLight,
                                    const Color(0xFFC4B5FD),
                                  ]
                                : [Colors.white, Colors.white],
                          ).createShader(bounds),
                          child: const Text(
                            'Welcome to FomraLS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1.05,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fomra Housing - Land Management',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onProfileTap,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isDark
                              ? LinearGradient(
                                  colors: [
                                    AppColors.primaryLight.withValues(alpha: 0.28),
                                    AppColors.secondary.withValues(alpha: 0.22),
                                  ],
                                )
                              : null,
                          color: isDark
                              ? null
                              : Colors.white.withValues(alpha: 0.18),
                          border: Border.all(
                            color: isDark
                                ? AppColors.primaryLight.withValues(alpha: 0.45)
                                : Colors.white.withValues(alpha: 0.24),
                          ),
                        ),
                        child: const Icon(Icons.person_outline,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(
                          colors: [
                            AppColors.primaryLight.withValues(alpha: 0.14),
                            AppColors.secondary.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: isDark
                      ? null
                      : Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? greetColor.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: greetColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(greetIcon, color: greetColor, size: 15),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      greeting,
                      style: TextStyle(
                        color: greetColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$time  |  ${_formattedDate(_now)}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _greetingFor(DateTime dt) {
    final hour = dt.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  IconData _greetIconFor(DateTime dt) {
    final hour = dt.hour;
    if (hour < 12) return Icons.wb_sunny_outlined;
    if (hour < 17) return Icons.wb_cloudy_outlined;
    return Icons.nights_stay_outlined;
  }

  Color _greetingAccent(DateTime dt) {
    final hour = dt.hour;
    if (hour < 12) return const Color(0xFFFBBF24);
    if (hour < 17) return const Color(0xFF38BDF8);
    return const Color(0xFFC4B5FD);
  }

  String _formattedTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$min:$sec $suffix';
  }

  String _formattedDate(DateTime now) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const _Blob(this.size, this.color, this.opacity);

  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      );
}

// ── KPI Chip ─────────────────────────────────────────────────────────────────

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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.fomraSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
            boxShadow: context.fomraCardShadow,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const Spacer(),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ]),
            const SizedBox(height: 10),
            Text('$value',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5)),
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

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 3, height: 16,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.fomraTextPrimary,
                letterSpacing: 0.1)),
      ]);
}

// ── Action Card ───────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final String route;
  final LinearGradient gradient;
  const _ActionCard({
    required this.icon,
    required this.label,
    required this.sub,
    required this.route,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return _HoverActionCard(
      onTap: () => Navigator.pushNamed(context, route),
      gradient: gradient,
      icon: icon,
      label: label,
      sub: sub,
    );
  }
}

class _HoverActionCard extends StatefulWidget {
  final VoidCallback onTap;
  final LinearGradient gradient;
  final IconData icon;
  final String label;
  final String sub;

  const _HoverActionCard({
    required this.onTap,
    required this.gradient,
    required this.icon,
    required this.label,
    required this.sub,
  });

  @override
  State<_HoverActionCard> createState() => _HoverActionCardState();
}

class _HoverActionCardState extends State<_HoverActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        scale: _hovered ? 1.01 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppColors.coloredShadow(widget.gradient.colors.first),
            ),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(widget.icon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      widget.sub,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.9), size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Notifications Sheet ───────────────────────────────────────────────────────

class _NotificationsSheet extends StatelessWidget {
  final List<AppNotification> notifications;
  final void Function(String id) onMarkRead;
  final VoidCallback onMarkAllRead;
  const _NotificationsSheet({
    required this.notifications,
    required this.onMarkRead,
    required this.onMarkAllRead,
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
                        onTap: () => onMarkRead(n.id),
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
