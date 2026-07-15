import 'package:flutter/material.dart';

import '../screens/home/home_screen.dart';
import '../services/fomra_trail.dart';
import '../theme/fomra_theme_context.dart';

enum FomraBreadcrumbAction { home, pop, namedRoute }

class FomraBreadcrumbItem {
  final String label;
  final FomraBreadcrumbAction? action;
  final String? route;
  final int popCount;

  const FomraBreadcrumbItem({
    required this.label,
    this.action,
    this.route,
    this.popCount = 1,
  });

  bool get isCurrent => action == null;

  const FomraBreadcrumbItem.current(String label)
      : this(label: label);

  const FomraBreadcrumbItem.home()
      : this(label: 'Home', action: FomraBreadcrumbAction.home);

  const FomraBreadcrumbItem.pop(String label)
      : this(label: label, action: FomraBreadcrumbAction.pop);

  const FomraBreadcrumbItem.route(String label, String route)
      : this(label: label, action: FomraBreadcrumbAction.namedRoute, route: route);
}

/// Common breadcrumb trails used across the app.
class FomraBreadcrumbs {
  static List<FomraBreadcrumbItem> module(String moduleLabel) => [
        const FomraBreadcrumbItem.home(),
        FomraBreadcrumbItem.current(moduleLabel),
      ];

  static List<FomraBreadcrumbItem> fromSettings(String pageLabel) => [
        const FomraBreadcrumbItem.home(),
        const FomraBreadcrumbItem.pop('Settings'),
        FomraBreadcrumbItem.current(pageLabel),
      ];

  static List<FomraBreadcrumbItem> fromWorkspace(String pageLabel) => [
        const FomraBreadcrumbItem.home(),
        const FomraBreadcrumbItem.route('Land Workspace', '/land-lead'),
        FomraBreadcrumbItem.current(pageLabel),
      ];

  /// Filtered lead list opened from home or workspace summaries.
  static List<FomraBreadcrumbItem> fromWorkspaceFilter(String pageLabel) => [
        const FomraBreadcrumbItem.home(),
        const FomraBreadcrumbItem.route('Land Workspace', '/land-lead'),
        FomraBreadcrumbItem.current(pageLabel),
      ];

  /// Lead detail opened from a filtered lead list.
  static List<FomraBreadcrumbItem> fromFilteredLeadDetail({
    required String filterLabel,
    required String leadId,
  }) =>
      [
        const FomraBreadcrumbItem.home(),
        const FomraBreadcrumbItem.route('Land Workspace', '/land-lead'),
        FomraBreadcrumbItem(
          label: filterLabel,
          action: FomraBreadcrumbAction.pop,
          popCount: 1,
        ),
        FomraBreadcrumbItem.current('Lead $leadId'),
      ];

  static List<FomraBreadcrumbItem> fromUserManagement(String pageLabel) => [
        const FomraBreadcrumbItem.home(),
        const FomraBreadcrumbItem(
          label: 'Settings',
          action: FomraBreadcrumbAction.pop,
          popCount: 2,
        ),
        const FomraBreadcrumbItem.pop('User Management'),
        FomraBreadcrumbItem.current(pageLabel),
      ];
}

void fomraNavigateHome(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => const HomeScreen(),
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 250),
    ),
    (_) => false,
  );
}

void fomraNavigateBreadcrumb(BuildContext context, FomraBreadcrumbItem item) {
  switch (item.action) {
    case FomraBreadcrumbAction.home:
      fomraNavigateHome(context);
    case FomraBreadcrumbAction.pop:
      for (var i = 0; i < item.popCount; i++) {
        if (!Navigator.canPop(context)) break;
        Navigator.pop(context);
      }
    case FomraBreadcrumbAction.namedRoute:
      final route = item.route;
      if (route != null && route.isNotEmpty) {
        Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
      }
    case null:
      break;
  }
}

/// Explorer-style path shown directly below the main app header.
class FomraBreadcrumbBar extends StatelessWidget implements PreferredSizeWidget {
  final List<FomraBreadcrumbItem> items;

  const FomraBreadcrumbBar({super.key, required this.items});

  static const _height = 40.0;

  @override
  Size get preferredSize =>
      items.length < 2 ? Size.zero : const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    if (items.length < 2) return const SizedBox.shrink();

    return Material(
      color: context.fomraSurface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.fomraBorder)),
        ),
        child: SizedBox(
          height: _height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: context.fomraTextTertiary,
              ),
            ),
            itemBuilder: (_, index) {
              final item = items[index];
              final isLast = index == items.length - 1;

              if (item.isCurrent || isLast) {
                return Center(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                );
              }

              return Center(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: () => fomraNavigateBreadcrumb(context, item),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.isDarkMode
                              ? const Color(0xFF93C5FD)
                              : const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Inline breadcrumb for screens with a custom header (e.g. add lead).
class FomraBreadcrumbStrip extends StatelessWidget {
  final List<FomraBreadcrumbItem> items;

  const FomraBreadcrumbStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return FomraBreadcrumbBar(items: items);
  }
}

/// Breadcrumbs built from the pages actually visited ([FomraTrail]) rather than
/// a per-screen hardcoded trail.
///
/// Names its own page [label], then renders `Home > …ancestors… > label`. Each
/// ancestor pops back exactly as far as it sits in the Navigator stack, so the
/// stack — and with it browser Back/Forward — stays consistent.
class FomraTrailBreadcrumbBar extends StatefulWidget
    implements PreferredSizeWidget {
  /// What this page calls itself in the trail.
  final String label;

  const FomraTrailBreadcrumbBar({super.key, required this.label});

  /// Fixed: every page that shows this bar has at least `Home > itself`, so the
  /// height never depends on trail state the Scaffold can't see.
  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  State<FomraTrailBreadcrumbBar> createState() =>
      _FomraTrailBreadcrumbBarState();
}

class _FomraTrailBreadcrumbBarState extends State<FomraTrailBreadcrumbBar> {
  @override
  void initState() {
    super.initState();
    FomraTrail.instance.addListener(_onTrailChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute is only reachable once dependencies are available.
    FomraTrail.instance.nameCurrentPage(context, widget.label);
  }

  @override
  void didUpdateWidget(covariant FomraTrailBreadcrumbBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.label != widget.label) {
      FomraTrail.instance.nameCurrentPage(context, widget.label);
    }
  }

  @override
  void dispose() {
    FomraTrail.instance.removeListener(_onTrailChanged);
    super.dispose();
  }

  void _onTrailChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final steps = FomraTrail.instance.steps();

    // Always begin with Home, and never twice — the home page names itself too.
    final items = <FomraBreadcrumbItem>[const FomraBreadcrumbItem.home()];
    for (final step in steps) {
      if (step.label == 'Home') continue;
      items.add(
        step.depthFromTop == 0
            ? FomraBreadcrumbItem.current(step.label)
            : FomraBreadcrumbItem(
                label: step.label,
                action: FomraBreadcrumbAction.pop,
                popCount: step.depthFromTop,
              ),
      );
    }

    // Before this page is registered (first frame) fall back to naming it, so
    // the bar never flashes as just "Home".
    if (items.length == 1) {
      items.add(FomraBreadcrumbItem.current(widget.label));
    }
    return FomraBreadcrumbBar(items: items);
  }
}
