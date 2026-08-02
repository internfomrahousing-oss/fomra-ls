import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/fomra_layout.dart';
import '../theme/fomra_theme_context.dart';
import 'portal_home_sections.dart';
import 'fomra_breadcrumb.dart';
import 'ui/app_components.dart';

/// Same ~94% centered width as the home page.
Widget portalPageWidthConstraint(BuildContext context, Widget child) =>
    portalHomeWidthConstraint(context, child);

/// Page padding + centered width — use for scroll views and tab bodies.
Widget portalPageBody(BuildContext context, Widget child) {
  return Padding(
    padding: FomraLayout.pagePadding(context),
    child: portalPageWidthConstraint(context, child),
  );
}

/// Home-style scrollable body: the scroll view spans the FULL width so its
/// scrollbar sits at the window's right edge (like the home page), while the
/// content stays padded and centered. Pass the inner content (e.g. a Column).
Widget portalScrollBody(
  BuildContext context,
  Widget child, {
  ScrollController? controller,
}) {
  return SingleChildScrollView(
    controller: controller,
    padding: FomraLayout.pagePadding(context),
    child: portalPageWidthConstraint(context, child),
  );
}

/// Sub-page app bar with back navigation and premium gradient.
class FomraSubPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final List<Widget>? actions;
  final List<FomraBreadcrumbItem>? breadcrumbs;

  const FomraSubPageAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.titleStyle,
    this.subtitleStyle,
    this.actions,
    this.breadcrumbs,
  });

  /// Phone-width check without a BuildContext, so [preferredSize] and the
  /// rendered [bottom] agree when the breadcrumb row is hidden on mobile.
  bool get _isMobileViewport {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final width = view.physicalSize.width / view.devicePixelRatio;
    return width < FomraLayout.mobileBreakpoint;
  }

  /// An explicit [breadcrumbs] list wins, for pages whose title is dynamic.
  /// Otherwise the page's fixed module hierarchy is derived from [title] — the
  /// same rule [FomraAppBar] follows.
  PreferredSizeWidget? _breadcrumbBottom() {
    // Mobile keeps the header compact — no breadcrumb row.
    if (_isMobileViewport) return null;
    if (breadcrumbs != null) {
      return breadcrumbs!.length >= 2 ? FomraBreadcrumbBar(items: breadcrumbs!) : null;
    }
    final label = title.trim();
    if (label.isEmpty) return null;
    return FomraModuleBreadcrumbBar(label: label);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return AppBar(
      flexibleSpace: isDark
          ? ClipRect(
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
            )
          : Container(decoration: BoxDecoration(gradient: context.fomraHeroGradient)),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      iconTheme: IconThemeData(
        color: isDark ? AppColors.darkTextPrimary : Colors.white,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.maybePop(context),
      ),
      title: subtitle == null
          ? Text(
              title,
              style: titleStyle ??
                  const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: titleStyle ??
                      const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                ),
                Text(
                  subtitle!,
                  style: subtitleStyle ??
                      TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                ),
              ],
            ),
      actions: actions,
      bottom: _breadcrumbBottom(),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (_breadcrumbBottom()?.preferredSize.height ?? 0),
      );
}

/// Numbered step header used on add/edit forms.
class PortalNumberedSectionHeader extends StatelessWidget {
  final String number;
  final String title;
  final String? subtitle;
  final IconData? icon;

  const PortalNumberedSectionHeader({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppColors.coloredShadow(AppColors.primary),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: context.fomraTextPrimary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.fomraTextSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (icon != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
      ],
    );
  }
}

/// Form section card — home-style elevated surface with numbered header.
class PortalFormSection extends StatelessWidget {
  final String number;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  const PortalFormSection({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: AppColors.radiusLg,
      interactive: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PortalNumberedSectionHeader(
            number: number,
            title: title,
            subtitle: subtitle,
            icon: icon,
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

/// Horizontal KPI strip matching the home summary tile style.
class PortalKpiStrip extends StatelessWidget {
  final List<PortalKpiItem> items;

  const PortalKpiStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final item = items[i];
          final tile = PortalSummaryTile(
            label: item.label,
            value: item.value,
            icon: item.icon,
            accent: item.accent,
          );
          return SizedBox(
            width: 148,
            child: item.onTap == null
                ? tile
                : InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.circular(16),
                    child: tile,
                  ),
          );
        },
      ),
    );
  }
}

class PortalKpiItem {
  final String label;
  final int value;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const PortalKpiItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.onTap,
  });
}

/// Frosted pill tab bar — matches Land Workspace chrome.
class PortalFrostedTabBar extends StatelessWidget {
  final TabController controller;
  final List<Tab> tabs;
  final bool onDarkBackground;

  const PortalFrostedTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.onDarkBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final shell = onDarkBackground
        ? Colors.white.withValues(alpha: 0.12)
        : context.fomraSurface;
    final border = onDarkBackground
        ? Colors.white.withValues(alpha: 0.18)
        : context.fomraBorder;
    final indicator = onDarkBackground
        ? (context.isDarkMode
            ? LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.85),
                  AppColors.primary,
                ],
              )
            : const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ))
        : null;
    final indicatorColor = onDarkBackground ? null : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: shell,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: onDarkBackground
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : context.fomraCardShadow,
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: indicator,
          color: indicatorColor,
        ),
        labelColor: onDarkBackground ? Colors.white : Colors.white,
        unselectedLabelColor: onDarkBackground
            ? Colors.white70
            : context.fomraTextSecondary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        isScrollable: tabs.length > 3,
        tabs: tabs,
      ),
    );
  }
}
