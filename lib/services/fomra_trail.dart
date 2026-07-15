import 'package:flutter/widgets.dart';

/// The pages actually visited to get here, in order.
///
/// Breadcrumbs used to be hardcoded per screen ("Land Workspace > Lead 12"
/// regardless of where you came from). This tracks the live [Navigator] stack
/// instead, so a lead opened from a Negotiation list reads
/// `Home > Land Workspace > Negotiation > Lead 12` and the same lead opened
/// from Reports reads `Home > Reports > Lead 12`.
///
/// Screens don't describe a trail — each only names itself (via
/// `FomraAppBar.moduleName` or an explicit label) and the order comes from the
/// navigation that actually happened. Because the source of truth is the
/// Navigator, browser Back/Forward and a refresh stay consistent for free: the
/// trail is whatever the Navigator restored.
class FomraTrail extends ChangeNotifier {
  static final FomraTrail instance = FomraTrail._();
  FomraTrail._();

  final List<Route<dynamic>> _stack = [];
  final Map<Route<dynamic>, String> _labels = {};

  /// Only full pages are steps in a trail — dialogs, popups and the notification
  /// panel are not places you can navigate "back" to.
  bool _isPage(Route<dynamic> route) =>
      route is PageRoute && route.settings.name != '/login';

  void _add(Route<dynamic> route) {
    if (!_isPage(route)) return;
    _stack.add(route);
    _notify();
  }

  void _drop(Route<dynamic> route) {
    if (!_stack.remove(route)) return;
    _labels.remove(route);
    _notify();
  }

  void _swap(Route<dynamic>? oldRoute, Route<dynamic>? newRoute) {
    if (oldRoute == null) return;
    final index = _stack.indexOf(oldRoute);
    if (index == -1) return;
    _labels.remove(oldRoute);
    if (newRoute != null && _isPage(newRoute)) {
      _stack[index] = newRoute;
    } else {
      _stack.removeAt(index);
    }
    _notify();
  }

  /// Names the page owning [context]. Safe to call from build — a redundant
  /// call is a no-op, and a real change is announced after the current frame so
  /// it never mutates the tree mid-build.
  void nameCurrentPage(BuildContext context, String label) {
    final route = ModalRoute.of(context);
    if (route == null || !_isPage(route)) return;
    final trimmed = label.trim();
    if (trimmed.isEmpty || _labels[route] == trimmed) return;
    _labels[route] = trimmed;
    _notify();
  }

  bool _notifyScheduled = false;

  /// Trail changes originate from build and from Navigator callbacks that fire
  /// mid-frame, so coalesce them into one notification after the frame.
  void _notify() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      notifyListeners();
    });
  }

  /// The named pages on the stack, oldest first, each with how many routes sit
  /// above it (how far back tapping it should go).
  List<({String label, int depthFromTop})> steps() {
    final result = <({String label, int depthFromTop})>[];
    for (var i = 0; i < _stack.length; i++) {
      final label = _labels[_stack[i]];
      if (label == null) continue;
      result.add((label: label, depthFromTop: _stack.length - 1 - i));
    }
    return result;
  }

  @visibleForTesting
  void debugReset() {
    _stack.clear();
    _labels.clear();
  }
}

/// Feeds [FomraTrail] from the real navigation. Attach once, on [MaterialApp].
class FomraTrailObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      FomraTrail.instance._add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      FomraTrail.instance._drop(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      FomraTrail.instance._drop(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      FomraTrail.instance._swap(oldRoute, newRoute);
}
