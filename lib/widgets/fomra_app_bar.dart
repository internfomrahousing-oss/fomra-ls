import 'dart:ui';

import 'package:flutter/material.dart';

import '../screens/settings/change_password_screen.dart';
import '../services/auth_service.dart';
import '../services/notification_hub.dart';
import '../services/view_scope.dart';
import '../theme/fomra_layout.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'fomra_breadcrumb.dart';
import 'fomra_notification_bell.dart';
import 'fomra_theme_toggle.dart';
import 'fomra_view_scope_toggle.dart';
import 'fomra_universal_search.dart';
import 'portal_home_sections.dart';
import 'ui/app_components.dart';
import 'ui/profile_avatar.dart';

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

  /// Whether the viewport is phone-width. Computed WITHOUT a BuildContext (from
  /// the platform view) so [preferredSize] and [_buildBottom] agree — the app
  /// bar hides the breadcrumb bar on mobile, and preferredSize must match.
  bool get _isMobileViewport {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final width = view.physicalSize.width / view.devicePixelRatio;
    return width < FomraLayout.mobileBreakpoint;
  }

  /// The breadcrumb bar for this page, or null when there's nothing to show.
  ///
  /// An explicit [breadcrumbs] list wins, for pages whose title is dynamic.
  /// Otherwise the page's fixed module hierarchy is derived from [moduleName].
  PreferredSizeWidget? _breadcrumbBar() {
    // Mobile keeps the header compact — no breadcrumb row.
    if (_isMobileViewport) return null;
    if (breadcrumbs != null && breadcrumbs!.isNotEmpty) {
      return breadcrumbs!.length >= 2
          ? FomraBreadcrumbBar(items: breadcrumbs!)
          : null;
    }
    final label = moduleName?.trim() ?? '';
    if (label.isEmpty) return null;
    return FomraModuleBreadcrumbBar(label: label);
  }

  PreferredSizeWidget? _buildBottom() {
    final breadcrumbBar = _breadcrumbBar();

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
      builder: (ctx) => const Dialog(
        alignment: Alignment.topCenter,
        insetPadding: EdgeInsets.fromLTRB(12, 70, 12, 12),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SizedBox(
          height: 52,
          child: FomraUniversalSearchBar(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    // Mobile web: show the hamburger for the drawer and tighten the header.
    final isMobile = FomraLayout.isMobile(context);
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
      automaticallyImplyLeading: isMobile,
      titleSpacing: isMobile ? 8 : 16,
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
                    'Fomra LandIQ',
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
        const FomraViewScopeToggle(),
        const FomraNotificationBell(),
        const FomraThemeToggle(),
        const Padding(
          padding: EdgeInsets.only(left: 2, right: 6),
          child: FomraHeaderProfile(),
        ),
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

/// Profile avatar shown in the app header on every screen — tap opens the
/// same change-password / sign-out menu the sidebar used to host.
class FomraHeaderProfile extends StatelessWidget {
  const FomraHeaderProfile({super.key});

  String get _profileName {
    if (AuthService.instance.isManagement) return 'Management';
    try {
      return AuthService.instance.currentUser?.fullName ?? 'User';
    } catch (_) {
      // Supabase may not be initialized yet (e.g. widget tests) — the
      // avatar still needs to render something sensible.
      return 'User';
    }
  }

  String get _profileRole =>
      AuthService.instance.isManagement ? 'Administrator' : 'Employee';

  String? get _profileEmail {
    try {
      return AuthService.instance.currentUser?.email;
    } catch (_) {
      return null;
    }
  }

  Future<void> _open(BuildContext context, TapDownDetails details) async {
    final name = _profileName;
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U';
    final action = await showPortalProfileMenu(
      context: context,
      anchor: details.globalPosition,
      name: name,
      role: _profileRole,
      initial: initial,
      email: _profileEmail,
    );
    if (!context.mounted) return;
    if (action == 'upload_photo') {
      await uploadProfilePhotoFlow(context);
    } else if (action == 'change_password') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
      );
    } else if (action == 'sign_out') {
      final confirmed = await confirmSignOut(context);
      if (!confirmed || !context.mounted) return;
      // Drop the shared notification state so the next user to sign in never
      // sees the previous one's badge or panel contents, and send the team
      // scope back to its default.
      NotificationHub.instance.stop();
      ViewScope.instance.reset();
      AuthService.instance.logout();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final name = _profileName;

    return Tooltip(
      message: name,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (details) => _open(context, details),
          child: ProfileAvatar(
            email: _profileEmail,
            name: name,
            radius: 15,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.22),
            foregroundColor:
                isDark ? AppColors.darkTextPrimary : Colors.white,
          ),
        ),
      ),
    );
  }
}
