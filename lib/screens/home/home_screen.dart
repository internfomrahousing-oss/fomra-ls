import 'package:flutter/material.dart';
import '../../models/land_lead.dart';
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

  int get _totalLeads  => AppStore.instance.leads.length;
  int get _activeLeads => AppStore.instance.leads
      .where((l) => [LeadStatus.new_, LeadStatus.contacted,
                     LeadStatus.siteVisit, LeadStatus.negotiation]
          .contains(l.status))
      .length;
  int get _acquired    => AppStore.instance.leads
      .where((l) => l.status == LeadStatus.closed).length;
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

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final greetIcon = hour < 12 ? Icons.wb_sunny_outlined
        : hour < 17 ? Icons.wb_cloudy_outlined : Icons.nights_stay_outlined;

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
            _HeroBanner(greeting: greeting, greetIcon: greetIcon),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── KPI strip ─────────────────────────────────────
                  Row(children: [
                    _KpiChip(label: 'Total', value: _totalLeads,
                        color: AppColors.primary),
                    const SizedBox(width: 8),
                    _KpiChip(label: 'Active', value: _activeLeads,
                        color: AppColors.success),
                    const SizedBox(width: 8),
                    _KpiChip(label: 'Acquired', value: _acquired,
                        color: AppColors.secondary),
                    const SizedBox(width: 8),
                    _KpiChip(label: 'Broker', value: _brokerLeads,
                        color: AppColors.accent),
                  ]),
                  const SizedBox(height: 24),

                  // ── Quick actions ──────────────────────────────────
                  const _SectionHeader('Quick Actions'),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3.4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: const [
                      _ActionCard(
                        icon: Icons.space_dashboard_outlined,
                        label: 'Land Workspace',
                        sub: 'Leads, Market & Legal',
                        route: '/land-lead',
                        gradient: LinearGradient(
                          colors: [Color(0xFF0F3EB5), Color(0xFF2563EB)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.insights_outlined,
                        label: 'Market Intel',
                        sub: 'Maps, POI & Patta',
                        route: '/market-intelligence',
                        gradient: LinearGradient(
                          colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.assessment_outlined,
                        label: 'Reports',
                        sub: 'Pipeline & analytics',
                        route: '/dashboard',
                        gradient: LinearGradient(
                          colors: [Color(0xFF047857), Color(0xFF059669)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                      _ActionCard(
                        icon: Icons.gavel_outlined,
                        label: 'Legal Review',
                        sub: 'Document checks',
                        route: '/legal-verification',
                        gradient: LinearGradient(
                          colors: [Color(0xFFB45309), Color(0xFFD97706)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                      ),
                    ],
                  ),
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

// ── Hero Banner ───────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final String greeting;
  final IconData greetIcon;
  const _HeroBanner({required this.greeting, required this.greetIcon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: Stack(children: [
        // Decorative blobs
        const Positioned(right: -40, top: -40,
            child: _Blob(200, Colors.white, 0.04)),
        const Positioned(right: 60, bottom: -30,
            child: _Blob(120, Colors.white, 0.04)),
        const Positioned(left: -30, bottom: 10,
            child: _Blob(90, AppColors.accent, 0.08)),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Greeting pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(greetIcon, color: AppColors.accentLight, size: 13),
                const SizedBox(width: 5),
                Text(greeting,
                    style: const TextStyle(
                        color: AppColors.accentLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 12),
            const Text('Welcome to FomraLS',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4)),
            const SizedBox(height: 3),
            Text('Fomra Housing — Land Management',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w400)),
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.calendar_today_outlined,
                    color: Colors.white54, size: 11),
                const SizedBox(width: 5),
                Text(_formattedDate(),
                    style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
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
  const _KpiChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$value',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.75))),
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
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
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
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          boxShadow: AppColors.coloredShadow(gradient.colors.first),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(sub,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios,
              size: 11, color: Colors.white.withValues(alpha: 0.5)),
        ]),
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
                          decoration: const BoxDecoration(
                            color: AppColors.background,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.notifications_none,
                              size: 32, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
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
