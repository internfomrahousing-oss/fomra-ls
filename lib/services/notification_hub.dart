import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import 'app_store.dart';
import 'auth_service.dart';
import 'notification_center_service.dart';
import 'notifications_service.dart';

/// App-wide notification state behind the header bell.
///
/// Every page renders its own [FomraNotificationBell], but they all read from
/// this one store, so the badge count and the panel contents stay identical no
/// matter which page you're on. [start] is idempotent — the first bell to mount
/// opens the realtime channel and the reminder-sync timer, and later bells just
/// attach as listeners.
class NotificationHub extends ChangeNotifier {
  static final NotificationHub instance = NotificationHub._();
  NotificationHub._();

  List<AppNotification> _items = const [];
  List<AppNotification> get notifications => List.unmodifiable(_items);

  int get unreadCount => _items.where((n) => !n.isRead).length;

  RealtimeChannel? _channel;
  Timer? _syncTimer;
  String? _audience;

  /// Ids already surfaced, so a realtime refresh only announces genuinely new
  /// notifications. Primed on the first load so history doesn't toast at once.
  final Set<String> _seenIds = {};
  bool _primed = false;

  final List<ValueChanged<AppNotification>> _newListeners = [];

  /// Called for each notification that arrives after the first load. Used by
  /// the toast host; register exactly one presenter so a notification toasts
  /// once even when several bells are mounted across stacked routes.
  void addNewNotificationListener(ValueChanged<AppNotification> fn) =>
      _newListeners.add(fn);

  void removeNewNotificationListener(ValueChanged<AppNotification> fn) =>
      _newListeners.remove(fn);

  String get _audienceForCurrentUser =>
      AuthService.instance.isManagement ? 'management' : 'employee';

  bool get _isManagement => AuthService.instance.isManagement;

  /// Safe to call from every bell on every page. Re-subscribes when the signed
  /// in audience changed (i.e. a different role signed in since last time).
  ///
  /// The bell is in the shared header, so this runs on every page — including
  /// before Supabase is initialized (startup, widget tests). Never let that
  /// take the whole header down: without a backend the bell just shows an
  /// empty, badge-less panel.
  void start() {
    final audience = _audienceForCurrentUser;
    if (_channel != null && _audience == audience) return;
    stop();
    try {
      _channel = NotificationsService.subscribe(
        audience: audience,
        onChange: refresh,
      );
    } catch (_) {
      return; // No backend yet — a later bell will retry.
    }
    _audience = audience;
    refresh();
    _syncAlerts();
    // Keep Field Calendar (and other) reminders flowing into the Notification
    // Center while the app stays open, not just on page load.
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) => _syncAlerts());
  }

  Future<void> _syncAlerts() async {
    try {
      await NotificationCenterService.syncAlerts();
      await refresh();
    } catch (_) {
      // Alert sync is best-effort; the list still shows what's already stored.
    }
  }

  /// Drops the subscription and clears state — call on sign-out so the next
  /// user never sees the previous one's notifications.
  void stop() {
    try {
      _channel?.unsubscribe();
    } catch (_) {/* channel may already be gone with the client */}
    _channel = null;
    _syncTimer?.cancel();
    _syncTimer = null;
    _audience = null;
    _items = const [];
    _seenIds.clear();
    _primed = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      final list = await NotificationsService.getAllForCurrentUser();
      final filtered = list
          .where((n) =>
              !_isManagementLeadNotification(n) &&
              !_isNewLeadUploadNotification(n) &&
              _isForMe(n))
          .toList();
      _announceNew(filtered);
      _items = filtered;
      notifyListeners();
    } catch (_) {
      // Keep the current list if the fetch fails (e.g. table not created yet).
    }
  }

  void markRead(String id) {
    for (final n in _items) {
      if (n.id == id) n.isRead = true;
    }
    notifyListeners();
    NotificationsService.markRead(id).catchError((_) {});
  }

  void markAllRead() {
    for (final n in _items) {
      n.isRead = true;
    }
    notifyListeners();
    NotificationsService.markAllReadForCurrentUser().catchError((_) {});
  }

  /// On the first refresh we only record the existing ids (so the whole history
  /// doesn't toast at once). After that, any id we haven't seen before is a live
  /// insert — newest last so it's the one left on screen.
  void _announceNew(List<AppNotification> latest) {
    final fresh = latest.where((n) => !_seenIds.contains(n.id)).toList();
    for (final n in latest) {
      _seenIds.add(n.id);
    }
    if (!_primed) {
      _primed = true;
      return;
    }
    if (_newListeners.isEmpty) return;
    for (final n in fresh.take(3).toList().reversed) {
      for (final fn in [..._newListeners]) {
        fn(n);
      }
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
    // Approval routing addresses a specific Reporting Manager / Head /
    // Executive by using their email as the audience. Those are already
    // personally targeted, so they bypass the name/lead-ownership heuristics
    // below (an approver's queue is about their team's leads, not their own).
    final myEmail =
        (AuthService.instance.currentUser?.email ?? '').trim().toLowerCase();
    if (myEmail.isNotEmpty && n.audience.trim().toLowerCase() == myEmail) {
      return true;
    }
    const marker = 'assigned to ';
    final msg = n.message.toLowerCase();
    final idx = msg.lastIndexOf(marker);
    final me =
        (AuthService.instance.currentUser?.fullName ?? '').trim().toLowerCase();
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
}
