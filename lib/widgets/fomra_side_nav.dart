import 'dart:async';

import 'package:flutter/material.dart';

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

  static const collapsedWidth = 72.0;
  static const expandedWidth = 228.0;

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

class _FomraSideNavState extends State<FomraSideNav> {
  bool _expanded = false;
  Timer? _expandTimer;
  Timer? _collapseTimer;

  static const _expandDelay = Duration(milliseconds: 420);
  static const _collapseDelay = Duration(milliseconds: 520);

  @override
  void dispose() {
    _expandTimer?.cancel();
    _collapseTimer?.cancel();
    super.dispose();
  }

  void _scheduleExpand() {
    _collapseTimer?.cancel();
    if (_expanded) return;
    _expandTimer?.cancel();
    _expandTimer = Timer(_expandDelay, () {
      if (mounted) setState(() => _expanded = true);
    });
  }

  void _scheduleCollapse() {
    _expandTimer?.cancel();
    if (!_expanded) return;
    _collapseTimer?.cancel();
    _collapseTimer = Timer(_collapseDelay, () {
      if (mounted) setState(() => _expanded = false);
    });
  }

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
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = context.fomraBorder;

    return MouseRegion(
      onEnter: (_) => _scheduleExpand(),
      onExit: (_) => _scheduleCollapse(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
        width: _expanded ? FomraSideNav.expandedWidth : FomraSideNav.collapsedWidth,
        decoration: BoxDecoration(
          color: surface,
          border: Border(right: BorderSide(color: border.withValues(alpha: 0.85))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
              blurRadius: 18,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              _BrandHeader(expanded: _expanded),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    for (final item in items)
                      _NavTile(
                        item: item,
                        expanded: _expanded,
                        active: _isActive(item),
                        onTap: () => _navigate(context, item),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
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
                    const SizedBox(height: 8),
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
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final bool expanded;

  const _BrandHeader({required this.expanded});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0),
      child: Row(
        mainAxisAlignment:
            expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.domain, color: Colors.white, size: 22),
          ),
          if (expanded) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FomraLS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  Text(
                    'Fomra Housing',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
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
  Timer? _hoverTimer;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  void _setHovered(bool value) {
    _hoverTimer?.cancel();
    if (value) {
      _hoverTimer = Timer(const Duration(milliseconds: 180), () {
        if (mounted) setState(() => _hovered = true);
      });
      return;
    }
    setState(() => _hovered = false);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final expanded = widget.expanded;
    final accent = active ? AppColors.primary : context.fomraTextSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: MouseRegion(
        onEnter: (_) => _setHovered(true),
        onExit: (_) => _setHovered(false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            height: 46,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 0),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary.withValues(alpha: 0.92)
                  : (_hovered
                      ? context.fomraSurfaceVar.withValues(alpha: 0.55)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(14),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: expanded
                ? Row(
                    children: [
                      Icon(
                        active ? widget.item.activeIcon : widget.item.icon,
                        color: active ? Colors.white : accent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w600,
                            color: active
                                ? Colors.white
                                : context.fomraTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Icon(
                      active ? widget.item.activeIcon : widget.item.icon,
                      color: active ? Colors.white : accent,
                      size: 22,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _FooterUser extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.primary.withValues(alpha: 0.14),
      child: Text(
        initial,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 10 : 8,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.fomraBorder.withValues(alpha: 0.7)),
      ),
      child: expanded
          ? Row(
              children: [
                avatar,
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: onSignOut,
                  icon: Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: context.fomraTextSecondary,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            )
          : Center(child: avatar),
    );
  }
}
