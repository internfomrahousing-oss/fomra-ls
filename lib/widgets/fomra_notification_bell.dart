import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../models/land_lead.dart';
import '../models/notification_type_ext.dart';
import '../screens/land_lead/lead_detail_screen.dart';
import '../screens/land_lead/management_visit_review_dialog.dart';
import '../services/app_store.dart';
import '../services/auth_service.dart';
import '../services/land_lead_site_visit_service.dart';
import '../services/notification_hub.dart';
import '../services/push_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'ui/app_components.dart';

/// The notification bell in [FomraAppBar] — one per page, all reading the same
/// [NotificationHub], so the badge and panel are identical everywhere.
class FomraNotificationBell extends StatefulWidget {
  const FomraNotificationBell({super.key});

  @override
  State<FomraNotificationBell> createState() => _FomraNotificationBellState();
}

class _FomraNotificationBellState extends State<FomraNotificationBell> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;

  bool get _open => _overlay != null;

  @override
  void initState() {
    super.initState();
    NotificationHub.instance.start();
    // The overlay isn't reachable until the first frame is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) NotificationToastHost.install(context);
    });
  }

  @override
  void dispose() {
    NotificationToastHost.uninstall();
    _overlay?.remove();
    _overlay = null;
    super.dispose();
  }

  void _toggle() {
    // Tapping the bell is a user gesture — use it to request push permission
    // (browsers suppress the auto prompt on page load) and register the token.
    PushService.promptAndSync();
    if (_open) {
      _hide();
    } else {
      _show();
    }
  }

  void _hide() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {}); // repaint the bell (pressed state / badge)
  }

  void _show() {
    _overlay = OverlayEntry(
      builder: (_) => ListenableBuilder(
        listenable: NotificationHub.instance,
        builder: (_, __) => _NotificationsDropdown(
          link: _link,
          notifications: NotificationHub.instance.notifications,
          onDismiss: _hide,
          onMarkRead: NotificationHub.instance.markRead,
          onMarkAllRead: NotificationHub.instance.markAllRead,
          onViewAll: () {
            _hide();
            Navigator.pushNamed(context, '/notifications');
          },
          onOpen: _openNotification,
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
    setState(() {}); // repaint the bell in its active state
  }

  Future<void> _openNotification(AppNotification n) async {
    _hide();
    final isManagement = AuthService.instance.isManagement;
    if ((n.type == NotificationType.siteVisit ||
            n.type == NotificationType.pendingApproval) &&
        isManagement) {
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
    if (n.type != NotificationType.lead &&
        n.type != NotificationType.siteVisit) {
      return;
    }
    LandLead? lead;
    for (final l in AppStore.instance.leads) {
      if (l.leadId == n.leadId) {
        lead = l;
        break;
      }
    }
    if (!mounted) return;
    if (lead != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead!)),
      );
    } else if (n.leadId != null) {
      Navigator.pushNamed(context, '/land-lead');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NotificationHub.instance,
      builder: (context, _) {
        final unread = NotificationHub.instance.unreadCount;
        return CompositedTransformTarget(
          link: _link,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: 'Notifications',
                icon: Icon(
                  _open ? Icons.notifications : Icons.notifications_outlined,
                  size: 22,
                ),
                onPressed: _toggle,
              ),
              if (unread > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
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
    final isMobile = screen.width < 480;
    final width = screen.width < 400 ? screen.width - 24 : 380.0;
    final maxHeight = (screen.height * 0.6).clamp(240.0, 520.0);

    final panel = Material(
              color: Colors.transparent,
              child: Container(
                width: isMobile ? double.infinity : width,
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
                      padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
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
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                                    backgroundColor:
                                        n.type.color.withValues(alpha: 0.1),
                                    child: Icon(n.type.icon,
                                        color: n.type.color, size: 15),
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
                                          width: 7,
                                          height: 7,
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
            );

    return Stack(
      children: [
        // Tap outside to close.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        // Mobile: pin the panel below the header with equal side margins so it
        // never overflows off-screen. Wider screens anchor it to the bell.
        if (isMobile)
          Positioned(
            top: MediaQuery.of(context).padding.top + kToolbarHeight + 6,
            left: 12,
            right: 12,
            child: panel,
          )
        else
          CompositedTransformFollower(
            link: link,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(8, 10),
            child: Align(alignment: Alignment.topRight, child: panel),
          ),
      ],
    );
  }
}

// ── Top-right toast overlay ───────────────────────────────────────────────────

/// Hosts the app's single toast stack in the root overlay.
///
/// Bells install/uninstall it as they mount, but only the first install creates
/// the overlay entry and registers with the hub — so a notification that lands
/// while several bells are alive (stacked routes) still toasts exactly once.
class NotificationToastHost {
  NotificationToastHost._();

  static final GlobalKey<_ToastStackState> _stackKey = GlobalKey();
  static OverlayEntry? _entry;
  static int _refs = 0;

  static void install(BuildContext context) {
    _refs++;
    if (_entry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      _refs--;
      return;
    }
    _entry = OverlayEntry(builder: (_) => _ToastStack(key: _stackKey));
    overlay.insert(_entry!);
    NotificationHub.instance.addNewNotificationListener(_present);
  }

  static void uninstall() {
    if (_refs == 0) return;
    _refs--;
    if (_refs > 0) return;
    NotificationHub.instance.removeNewNotificationListener(_present);
    _entry?.remove();
    _entry = null;
  }

  static void _present(AppNotification n) {
    // The stack may not be mounted on the frame the host is first inserted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _stackKey.currentState?.push(_ToastData(
        title: n.title,
        message: n.message,
        color: n.type.color,
        icon: n.type.icon,
      ));
    });
  }
}

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

/// Hosts a bottom-right column of stacked toasts. New toasts slide in from the
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
                            style:
                                const TextStyle(color: AppColors.textSecondary),
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
