import 'dart:ui';

import 'package:flutter/material.dart';

import 'fomra_brand_logo.dart';

import '../screens/home/home_screen.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'ui/app_components.dart';

class FomraSideNavItem {
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const FomraSideNavItem(
    this.route,
    this.icon,
    this.activeIcon,
    this.label,
  );
}

class FomraSideNav extends StatefulWidget {
  final String currentRoute;

  const FomraSideNav({super.key, required this.currentRoute});

  static const collapsedWidth = 88.0;
  static const expandedWidth = 248.0;

  static List<FomraSideNavItem> itemsForUser() {
    final items = <FomraSideNavItem>[
      const FomraSideNavItem(
        '/home',
        Icons.home_outlined,
        Icons.home_rounded,
        'Home',
      ),
      const FomraSideNavItem(
        '/land-lead',
        Icons.space_dashboard_outlined,
        Icons.space_dashboard,
        'Workspace',
      ),
    ];
    if (AuthService.instance.isManagement) {
      items.add(const FomraSideNavItem(
        '/dashboard',
        Icons.bar_chart_outlined,
        Icons.bar_chart_rounded,
        'Dashboard',
      ));
      items.add(const FomraSideNavItem(
        '/reports',
        Icons.summarize_outlined,
        Icons.summarize_rounded,
        'Reports',
      ));
    }
    return items;
  }

  @override
  State<FomraSideNav> createState() => _FomraSideNavState();
}

class _SideNavTokens {
  static const navButtonSize = 54.0;
  static const navButtonRadius = 15.0;
  static const navIconSize = 24.0;
  static const navItemGap = 14.0;
  static const horizontalPad = 14.0;
  static const collapsedHorizontalPad = 10.0;
  static const verticalPad = 20.0;
  static const animDuration = Duration(milliseconds: 250);
  static const animCurve = Curves.easeOutCubic;

  static const sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
  );
}

class _FomraSideNavState extends State<FomraSideNav> {
  bool _expanded = false;

  bool _isActive(FomraSideNavItem item) {
    if (widget.currentRoute == item.route) return true;
    if (item.route == '/land-lead' &&
        widget.currentRoute == '/task-management') {
      return true;
    }
    return false;
  }

  void _navigate(BuildContext context, FomraSideNavItem item) {
    if (_isActive(item)) return;
    if (item.route == '/home') {
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
      return;
    }
    Navigator.pushNamed(context, item.route);
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await confirmSignOut(context);
    if (!confirmed || !context.mounted) return;
    AuthService.instance.logout();
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final items = FomraSideNav.itemsForUser();
    final user = AuthService.instance.currentUser;
    final name = user?.fullName ?? 'User';
    final initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';

    final isDark = context.isDarkMode;

    return MouseRegion(
      onEnter: (_) => setState(() => _expanded = true),
      onExit: (_) => setState(() => _expanded = false),
      child: AnimatedContainer(
        duration: _SideNavTokens.animDuration,
        curve: _SideNavTokens.animCurve,
        width: _expanded
            ? FomraSideNav.expandedWidth
            : FomraSideNav.collapsedWidth,
        decoration: BoxDecoration(
          color: isDark ? context.fomraSidebarBg : null,
          gradient: isDark ? null : _SideNavTokens.sidebarGradient,
          border: isDark
              ? const Border(
                  right: BorderSide(color: AppColors.darkBorder, width: 1),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.25),
              blurRadius: isDark ? 16 : 24,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BrandHeader(expanded: _expanded),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _expanded
                      ? _SideNavTokens.horizontalPad
                      : _SideNavTokens.collapsedHorizontalPad,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      _NavTile(
                        item: items[i],
                        expanded: _expanded,
                        active: _isActive(items[i]),
                        onTap: () => _navigate(context, items[i]),
                      ),
                      if (i < items.length - 1)
                        const SizedBox(height: _SideNavTokens.navItemGap),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                _expanded
                    ? _SideNavTokens.horizontalPad
                    : _SideNavTokens.collapsedHorizontalPad,
                0,
                _expanded
                    ? _SideNavTokens.horizontalPad
                    : _SideNavTokens.collapsedHorizontalPad,
                _SideNavTokens.verticalPad,
              ),
              child: Column(
                children: [
                  _NavTile(
                    item: const FomraSideNavItem(
                      '/settings',
                      Icons.settings_outlined,
                      Icons.settings_rounded,
                      'Settings',
                    ),
                    expanded: _expanded,
                    active: widget.currentRoute == '/settings',
                    onTap: () {
                      if (widget.currentRoute != '/settings') {
                        Navigator.pushNamed(context, '/settings');
                      }
                    },
                  ),
                  const SizedBox(height: _SideNavTokens.navItemGap),
                  _FooterUser(
                    expanded: _expanded,
                    initial: initial,
                    name: name,
                    onSignOut: () => _signOut(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final bool expanded;

  const _BrandHeader({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kToolbarHeight,
      child: AnimatedPadding(
        duration: _SideNavTokens.animDuration,
        curve: _SideNavTokens.animCurve,
        padding: EdgeInsets.fromLTRB(
          expanded ? 10 : 6,
          3,
          expanded ? 10 : 6,
          3,
        ),
        child: Align(
          alignment: expanded ? Alignment.centerLeft : Alignment.center,
          child: FomraBrandLogo(
            compact: !expanded,
            showBackground: true,
            height: kToolbarHeight - 6,
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  final FomraSideNavItem item;
  final bool expanded;
  final bool active;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.expanded,
    required this.active,
    required this.onTap,
  });

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final expanded = widget.expanded;
    final hovered = _hovered && !active;
    final isDark = context.isDarkMode;

    final button = _NavIconButton(
      active: active,
      hovered: hovered,
      isDark: isDark,
      icon: active ? widget.item.activeIcon : widget.item.icon,
    );

    Widget content = AnimatedContainer(
      duration: _SideNavTokens.animDuration,
      curve: _SideNavTokens.animCurve,
      height: _SideNavTokens.navButtonSize,
      alignment: expanded ? Alignment.centerLeft : Alignment.center,
      child: expanded
          ? Row(
              children: [
                button,
                const SizedBox(width: 14),
                Expanded(
                  child: AnimatedDefaultTextStyle(
                    duration: _SideNavTokens.animDuration,
                    curve: _SideNavTokens.animCurve,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: isDark
                          ? (active
                              ? AppColors.darkTextPrimary
                              : AppColors.darkTextSecondary.withValues(
                                  alpha: hovered ? 1.0 : 0.92,
                                ))
                          : (active
                              ? Colors.white
                              : Colors.white.withValues(
                                  alpha: hovered ? 1.0 : 0.88,
                                )),
                    ),
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            )
          : button,
    );

    Widget tile = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (active)
              Positioned(
                left: expanded
                    ? -_SideNavTokens.horizontalPad + 2
                    : -_SideNavTokens.collapsedHorizontalPad + 2,
                top: 16,
                bottom: 16,
                child: AnimatedContainer(
                  duration: _SideNavTokens.animDuration,
                  curve: _SideNavTokens.animCurve,
                  width: 3,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: isDark
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.45),
                              blurRadius: 6,
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.45),
                              blurRadius: 6,
                            ),
                          ],
                  ),
                ),
              ),
            content,
          ],
        ),
      ),
    );

    if (!expanded) {
      tile = Tooltip(
        message: widget.item.label,
        waitDuration: const Duration(milliseconds: 400),
        child: tile,
      );
    }

    return tile;
  }
}

class _NavIconButton extends StatelessWidget {
  final bool active;
  final bool hovered;
  final bool isDark;
  final IconData icon;

  const _NavIconButton({
    required this.active,
    required this.hovered,
    required this.isDark,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color iconColor;
    List<BoxShadow>? shadow;

    if (isDark) {
      bg = active
          ? AppColors.primary.withValues(alpha: 0.18)
          : (hovered
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.transparent);
      iconColor = active
          ? AppColors.primaryLight
          : AppColors.darkTextSecondary.withValues(alpha: hovered ? 1.0 : 0.85);
      shadow = active
          ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ]
          : null;
    } else {
      bg = active
          ? Colors.white
          : (hovered
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.transparent);
      iconColor = active
          ? AppColors.primary
          : Colors.white.withValues(alpha: hovered ? 1.0 : 0.78);
      shadow = active
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ]
          : null;
    }

    final button = AnimatedContainer(
      duration: _SideNavTokens.animDuration,
      curve: _SideNavTokens.animCurve,
      width: _SideNavTokens.navButtonSize,
      height: _SideNavTokens.navButtonSize,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_SideNavTokens.navButtonRadius),
        border: isDark && active
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.35))
            : null,
        boxShadow: shadow,
      ),
      child: Center(
        child: Icon(icon, size: _SideNavTokens.navIconSize, color: iconColor),
      ),
    );

    if (!isDark || !hovered || active) return button;

    return ClipRRect(
      borderRadius: BorderRadius.circular(_SideNavTokens.navButtonRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: button,
      ),
    );
  }
}

class _FooterUser extends StatefulWidget {
  final bool expanded;
  final String initial;
  final String name;
  final VoidCallback onSignOut;

  const _FooterUser({
    required this.expanded,
    required this.initial,
    required this.name,
    required this.onSignOut,
  });

  @override
  State<_FooterUser> createState() => _FooterUserState();
}

class _FooterUserState extends State<_FooterUser> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final avatar = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.18),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.32),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        widget.initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );

    final profileCard = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: _SideNavTokens.animDuration,
          curve: _SideNavTokens.animCurve,
          padding: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 12 : 8,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: _hovered ? 0.08 : 0.05)
                : Colors.white.withValues(alpha: _hovered ? 0.2 : 0.14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.darkBorder.withValues(alpha: _hovered ? 0.9 : 0.6)
                  : Colors.white.withValues(alpha: _hovered ? 0.36 : 0.24),
            ),
          ),
          child: widget.expanded
              ? Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Sign out',
                      onPressed: widget.onSignOut,
                      icon: Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                )
              : Center(child: avatar),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.expanded
          ? profileCard
          : Tooltip(
              message: widget.name,
              waitDuration: const Duration(milliseconds: 400),
              child: profileCard,
            ),
    );
  }
}
