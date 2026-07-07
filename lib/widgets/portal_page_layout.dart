import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/fomra_layout.dart';
import '../theme/fomra_theme_context.dart';
import 'portal_home_sections.dart';
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
  final List<Widget>? actions;

  const FomraSubPageAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      flexibleSpace: Container(
        decoration: BoxDecoration(gradient: context.fomraHeroGradient),
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: subtitle == null
          ? Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
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
          return SizedBox(
            width: 148,
            child: PortalSummaryTile(
              label: item.label,
              value: item.value,
              icon: item.icon,
              accent: item.accent,
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

  const PortalKpiItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
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
        ? const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
          )
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
