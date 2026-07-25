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

/// The breadcrumb hierarchy.
///
/// Every page shows a flat two-level trail — `Home > page` — so the crumb only
/// ever names where you are, never a hardcoded section you may not have passed
/// through (e.g. a page opened from Home no longer shows "Land Workspace"
/// in-between). Tapping Home returns to the dashboard.
abstract final class FomraBreadcrumbs {
  static const home = FomraBreadcrumbItem.home();
  static const landWorkspace =
      FomraBreadcrumbItem.route('Land Workspace', '/land-lead');

  /// `Home > [label]` for a module page.
  static List<FomraBreadcrumbItem> forModule(String label) => [
        home,
        FomraBreadcrumbItem.current(label),
      ];

  /// `Home > Settings > [label]` for pages opened from Settings. Tapping
  /// Settings pops back to the Settings hub; Home resets to the dashboard.
  static List<FomraBreadcrumbItem> forSettingsChild(String label) => [
        home,
        const FomraBreadcrumbItem.pop('Settings'),
        FomraBreadcrumbItem.current(label),
      ];

  /// `Home > [label]` for a page whose title is dynamic (a lead, a filtered
  /// list). [ancestors] is accepted for call-site compatibility but no longer
  /// inserted — the trail stays flat.
  static List<FomraBreadcrumbItem> under(
    List<FomraBreadcrumbItem> ancestors,
    String label,
  ) =>
      [home, FomraBreadcrumbItem.current(label)];
}

/// The breadcrumb bar shown under a page header. Renders the fixed module
/// hierarchy for [label]; pass [ancestors] for a page with a dynamic title.
class FomraModuleBreadcrumbBar extends StatelessWidget
    implements PreferredSizeWidget {
  /// What this page is called (the last crumb).
  final String label;

  /// The crumbs between Home and this page. Null → looked up from [label]'s
  /// place in the module tree.
  final List<FomraBreadcrumbItem>? ancestors;

  const FomraModuleBreadcrumbBar({
    super.key,
    required this.label,
    this.ancestors,
  });

  /// Fixed: every page that shows this bar has at least `Home > itself`.
  @override
  Size get preferredSize => const Size.fromHeight(40);

  @override
  Widget build(BuildContext context) {
    final items = ancestors == null
        ? FomraBreadcrumbs.forModule(label)
        : FomraBreadcrumbs.under(ancestors!, label);
    return FomraBreadcrumbBar(items: items);
  }
}
