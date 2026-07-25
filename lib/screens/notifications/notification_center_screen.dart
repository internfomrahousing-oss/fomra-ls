import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_notification.dart';
import '../../models/land_lead.dart';
import '../../models/notification_type_ext.dart';
import '../../services/app_store.dart';
import '../../services/auth_service.dart';
import '../../services/notification_center_service.dart';
import '../../services/notifications_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/app_loader.dart';
import '../land_lead/lead_detail_screen.dart';
import '../land_lead/management_visit_review_dialog.dart';
import '../settings/monthly_target_approvals_page.dart';

enum _NotifFilter { all, unread, read }

bool _isMonthlyTargetNotification(AppNotification n) =>
    n.title.trim().toLowerCase().startsWith('monthly target');

/// Full Notification Center — Read / Unread / Mark All Read.
class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  bool _loading = true;
  String? _error;
  _NotifFilter _filter = _NotifFilter.all;
  List<AppNotification> _items = const [];
  RealtimeChannel? _channel;

  String get _audience =>
      AuthService.instance.isManagement ? 'management' : 'employee';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await NotificationCenterService.syncAlerts();
    await _load();
    _channel = NotificationsService.subscribe(
      audience: _audience,
      onChange: _load,
    );
  }

  Future<void> _load() async {
    try {
      final rows = await NotificationsService.getAll(
        audience: _audience,
        limit: 200,
      );
      if (!mounted) return;
      setState(() {
        _items = _visible(rows);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<AppNotification> _visible(List<AppNotification> rows) {
    if (!AuthService.instance.isManagement) {
      final me =
          (AuthService.instance.currentUser?.fullName ?? '').trim().toLowerCase();
      // Notifications are stored in a shared 'employee' audience bucket (no
      // per-user column in the schema), so scope client-side: a lead-linked
      // notification only belongs to this Executive if the lead is one of
      // theirs. Notifications without a lead reference (general alerts)
      // still show, since ownership can't be determined for those.
      final myLeadIds =
          AppStore.instance.visibleLeads.map((l) => l.leadId).toSet();
      return rows.where((n) {
        if (n.type == NotificationType.lead ||
            n.type == NotificationType.assignedLead) {
          final msg = n.message.toLowerCase();
          if (me.isNotEmpty &&
              msg.contains('assigned to') &&
              !msg.contains(me)) {
            return false;
          }
        }
        if ((n.leadId ?? '').trim().isNotEmpty &&
            !myLeadIds.contains(n.leadId)) {
          return false;
        }
        return true;
      }).toList();
    }
    return rows;
  }

  List<AppNotification> get _filtered {
    return switch (_filter) {
      _NotifFilter.all => _items,
      _NotifFilter.unread => _items.where((n) => !n.isRead).toList(),
      _NotifFilter.read => _items.where((n) => n.isRead).toList(),
    };
  }

  int get _unreadCount => _items.where((n) => !n.isRead).length;

  Future<void> _markRead(AppNotification n) async {
    if (n.isRead) return;
    setState(() => n.isRead = true);
    try {
      await NotificationsService.markRead(n.id);
    } catch (_) {}
  }

  Future<void> _markAllRead() async {
    setState(() {
      for (final n in _items) {
        n.isRead = true;
      }
    });
    try {
      await NotificationsService.markAllRead(audience: _audience);
    } catch (_) {}
  }

  Future<void> _open(AppNotification n) async {
    await _markRead(n);
    if (!mounted) return;

    if (_isMonthlyTargetNotification(n) &&
        (n.type == NotificationType.siteVisit ||
            n.type == NotificationType.pendingApproval) &&
        AuthService.instance.isManagement) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MonthlyTargetApprovalsPage()),
      );
      return;
    }

    if (n.type == NotificationType.siteVisit ||
        n.type == NotificationType.pendingApproval) {
      if (AuthService.instance.isManagement &&
          (n.referenceId ?? '').isNotEmpty) {
        await showManagementVisitReviewDialog(
          context,
          visitId: n.referenceId!,
          leadId: n.leadId,
        );
        return;
      }
    }

    final leadId = n.leadId?.trim() ?? '';
    if (leadId.isEmpty) return;
    LandLead? lead;
    for (final l in AppStore.instance.leads) {
      if (l.leadId == leadId) {
        lead = l;
        break;
      }
    }
    if (lead == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pad = FomraLayout.pagePadding(context);
    final stamp = DateFormat('dd MMM, h:mm a');

    final body = RefreshIndicator(
      onRefresh: () async {
        await NotificationCenterService.syncAlerts(force: true);
        await _load();
      },
      child: ListView(
        padding: pad,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notification Center',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Assigned leads, pending work, approvals, SLA breaches, overdue tasks, and reminders.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_unreadCount > 0)
                TextButton(
                  onPressed: _markAllRead,
                  child: Text('Mark all read ($_unreadCount)'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final f in _NotifFilter.values)
                FilterChip(
                  label: Text(switch (f) {
                    _NotifFilter.all => 'All (${_items.length})',
                    _NotifFilter.unread => 'Unread ($_unreadCount)',
                    _NotifFilter.read =>
                      'Read (${_items.length - _unreadCount})',
                  }),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                  selectedColor: AppColors.primary.withValues(alpha: 0.18),
                  checkmarkColor: AppColors.primary,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: AppLoader.center(message: 'Loading notifications…'),
            )
          else if (_error != null)
            EmptyState(
              title: 'Could not load notifications',
              message: _error,
              icon: Icons.error_outline_rounded,
            )
          else if (_filtered.isEmpty)
            AppCard(
              child: EmptyState(
                icon: Icons.notifications_none_rounded,
                title: _filter == _NotifFilter.unread
                    ? 'All caught up'
                    : 'No notifications',
                message: _filter == _NotifFilter.unread
                    ? 'You have no unread notifications.'
                    : 'Alerts for leads, approvals, SLA, and tasks will appear here.',
              ),
            )
          else
            ..._filtered.map((n) {
              final accent = n.type.color;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => _open(n),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: accent.withValues(alpha: 0.12),
                        child: Icon(n.type.icon, color: accent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    n.type.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (!n.isRead)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    n.isRead ? FontWeight.w500 : FontWeight.w700,
                                color: context.fomraTextPrimary,
                              ),
                            ),
                            if (n.message.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                n.message,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.fomraTextSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            Text(
                              stamp.format(n.time),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.fomraTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );

    return FomraAppShell(
      currentRoute: '/notifications',
      body: body,
    );
  }
}
