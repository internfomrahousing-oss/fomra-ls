import 'package:flutter/material.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';
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

  int get _totalLeads => AppStore.instance.leads.length;
  static const int _legalPending = 0;

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
          for (final n in _notifications) {
            n.isRead = true;
          }
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';
    final greetIcon = hour < 12
        ? Icons.wb_sunny_outlined
        : hour < 17
            ? Icons.wb_cloudy_outlined
            : Icons.nights_stay_outlined;

    return Scaffold(
      appBar: FomraAppBar(
        actions: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              margin: const EdgeInsets.only(right: 4),
              child: IconButton(
                icon: const Icon(Icons.notifications_outlined, size: 24),
                onPressed: _showNotifications,
              ),
            ),
            if (_unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                      color: AppColors.accent, shape: BoxShape.circle),
                  child: Center(
                    child: Text('$_unreadCount',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ]),
          const SizedBox(width: 4),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/'),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero Banner ────────────────────────────────────────
            _HeroBanner(greeting: greeting, greetIcon: greetIcon),
            const SizedBox(height: 24),

            // ── Overview Stats ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader('Overview'),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.add_location_alt_outlined,
                        label: 'Total\nLeads',
                        count: _totalLeads,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: () =>
                            Navigator.pushNamed(context, '/land-lead'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.gavel_outlined,
                        label: 'Legal\nPending',
                        count: _legalPending,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFF87171)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        onTap: () => Navigator.pushNamed(
                            context, '/legal-verification'),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 24),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.2)),
      ]);
}

// ── Hero Banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final String greeting;
  final IconData greetIcon;
  const _HeroBanner({required this.greeting, required this.greetIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(children: [
        // Decorative circles
        Positioned(
          right: -30,
          top: -30,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
        ),
        Positioned(
          right: 40,
          bottom: -20,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
        ),
        Positioned(
          left: -20,
          bottom: 20,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
        ),
        // Content
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(greetIcon,
                      color: AppColors.accentLight, size: 14),
                  const SizedBox(width: 6),
                  Text(greeting,
                      style: const TextStyle(
                          color: AppColors.accentLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
              const SizedBox(height: 14),
              const Text('Welcome to FomraLS',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
              const SizedBox(height: 4),
              const Text('Fomra Housing Land Management',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      fontWeight: FontWeight.w400)),
              const SizedBox(height: 16),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.calendar_today_outlined,
                        color: Colors.white60, size: 12),
                    const SizedBox(width: 6),
                    Text(_formattedDate(),
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const days = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

// ── Stat Card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios,
                  size: 10,
                  color: Colors.white.withValues(alpha: 0.5)),
            ]),
            const SizedBox(height: 12),
            Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    height: 1.4)),
          ],
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, controller) => Column(children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              const Text('Notifications',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (notifications.isNotEmpty)
                TextButton(
                  onPressed: () {
                    onMarkAllRead();
                    Navigator.pop(context);
                  },
                  child: const Text('Mark all read',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
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
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_none,
                              size: 36,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        const Text('No notifications yet',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : ListView.separated(
                    controller: controller,
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final n = notifications[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              _typeColor(n.type).withValues(alpha: 0.12),
                          child: Icon(_typeIcon(n.type),
                              color: _typeColor(n.type), size: 18),
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
                            style:
                                const TextStyle(fontSize: 12)),
                        trailing: n.isRead
                            ? null
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle),
                              ),
                        onTap: () => onMarkRead(n.id),
                        tileColor: n.isRead
                            ? null
                            : AppColors.primary
                                .withValues(alpha: 0.03),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  Color _typeColor(NotificationType t) => switch (t) {
        NotificationType.lead => AppColors.info,
        NotificationType.task => AppColors.warning,
        NotificationType.document => AppColors.success,
        NotificationType.alert => AppColors.error,
        NotificationType.verification => const Color(0xFF8B5CF6),
      };

  IconData _typeIcon(NotificationType t) => switch (t) {
        NotificationType.lead => Icons.location_on,
        NotificationType.task => Icons.task_alt,
        NotificationType.document => Icons.description,
        NotificationType.alert => Icons.warning_amber,
        NotificationType.verification => Icons.verified,
      };
}
