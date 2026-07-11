import 'package:flutter/material.dart';
import '../theme/fomra_theme_context.dart';
import 'fomra_breadcrumb.dart';
import 'fomra_theme_toggle.dart';
import 'fomra_universal_search.dart';

class FomraAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? moduleName;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final List<FomraBreadcrumbItem>? breadcrumbs;
  final bool showUniversalSearch;

  const FomraAppBar({
    super.key,
    this.moduleName,
    this.actions,
    this.bottom,
    this.breadcrumbs,
    this.showUniversalSearch = true,
  });

  List<FomraBreadcrumbItem> _effectiveBreadcrumbs() {
    if (breadcrumbs != null && breadcrumbs!.isNotEmpty) return breadcrumbs!;
    if (moduleName != null && moduleName!.trim().isNotEmpty) {
      return FomraBreadcrumbs.module(moduleName!);
    }
    return const [];
  }

  PreferredSizeWidget? _buildBottom() {
    final trail = _effectiveBreadcrumbs();
    final breadcrumbBar =
        trail.length >= 2 ? FomraBreadcrumbBar(items: trail) : null;

    if (breadcrumbBar == null) return bottom;
    if (bottom == null) return breadcrumbBar;

    final h = breadcrumbBar.preferredSize.height + bottom!.preferredSize.height;
    return PreferredSize(
      preferredSize: Size.fromHeight(h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          breadcrumbBar,
          bottom!,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: context.fomraHeroGradient),
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 12,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _goHome(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2), width: 1),
                    ),
                    child: const Icon(Icons.house_outlined,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text('FomraLS',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: 0.1)),
                ],
              ),
            ),
          ),
          if (moduleName != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Text(moduleName!,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9))),
            ),
          ],
          if (showUniversalSearch) ...[
            const SizedBox(width: 16),
            const Expanded(child: FomraUniversalSearchBar()),
          ],
        ],
      ),
      actions: [
        ...?actions,
        const FomraThemeToggle(),
      ],
      bottom: _buildBottom(),
    );
  }

  static void goHome(BuildContext context) => fomraNavigateHome(context);

  static void _goHome(BuildContext context) => goHome(context);

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (_buildBottom()?.preferredSize.height ?? 0),
      );
}
