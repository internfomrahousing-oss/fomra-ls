import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/fomra_layout.dart';
import '../theme/app_theme.dart';
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

  Widget _headerBackground(BuildContext context) {
    final isDark = context.isDarkMode;
    if (isDark) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              gradient: context.fomraHeroGradient,
              border: Border(
                bottom: BorderSide(
                  color: context.fomraBorder.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Container(decoration: BoxDecoration(gradient: context.fomraHeroGradient));
  }

  void _openMobileSearch(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (ctx) => Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.fromLTRB(12, 70, 12, 12),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const SizedBox(
          height: 52,
          child: FomraUniversalSearchBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final fg = isDark ? AppColors.darkTextPrimary : Colors.white;
    final fgMuted = isDark
        ? AppColors.darkTextSecondary
        : Colors.white.withValues(alpha: 0.9);
    final chipBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.14);
    final chipBorder = isDark
        ? context.fomraBorder.withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.22);

    return AppBar(
      flexibleSpace: _headerBackground(context),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: compact,
      titleSpacing: compact ? 10 : 16,
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
                      color: chipBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: chipBorder, width: 1),
                    ),
                    child: Icon(Icons.house_outlined, color: fg, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'FomraLS',
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: FomraLayout.responsiveClamp(
                        context,
                        min: 16,
                        max: 18,
                      ),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (moduleName != null && !compact) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: chipBorder),
              ),
              child: Text(
                moduleName!,
                style: TextStyle(
                  fontSize: FomraLayout.responsiveClamp(
                    context,
                    min: 11,
                    max: 12,
                  ),
                  fontWeight: FontWeight.w600,
                  color: fgMuted,
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (showUniversalSearch && !compact)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width >= 900 ? 280 : 220,
              child: const FomraUniversalSearchBar(),
            ),
          )
        else if (showUniversalSearch && compact)
          IconButton(
            tooltip: 'Search',
            icon: Icon(Icons.search_rounded, color: fg),
            onPressed: () => _openMobileSearch(context),
          ),
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
