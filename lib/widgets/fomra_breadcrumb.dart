import 'package:flutter/material.dart';

import '../screens/home/home_screen.dart';
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
        const FomraBreadcrumbItem.pop('Land Workspace'),
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
