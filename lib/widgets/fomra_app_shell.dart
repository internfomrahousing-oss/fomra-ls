import 'package:flutter/material.dart';

import '../theme/fomra_layout.dart';
import '../theme/fomra_theme_context.dart';
import 'app_drawer.dart';
import 'fomra_side_nav.dart';
import 'impersonation_banner.dart';

/// App layout with a persistent left navigation rail and main content area.
class FomraAppShell extends StatelessWidget {
  final String currentRoute;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;

  const FomraAppShell({
    super.key,
    required this.currentRoute,
    this.appBar,
    required this.body,
    this.backgroundColor,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    // The persistent side rail stays for tablet + desktop; mobile (< 768) gets
    // a hamburger + slide-out drawer instead.
    final isDesktop = !FomraLayout.isMobile(context);
    final pageGradient = context.fomraPageGradient;
    final bg = backgroundColor ?? context.fomraPageBg;

    // While accessing the app as another user, a persistent banner sits above
    // the page content on every screen (the banner hides itself otherwise).
    final bodyWithBanner = Column(
      children: [
        const ImpersonationBanner(),
        Expanded(child: body),
      ],
    );

    Widget shellBody(Widget child) {
      if (pageGradient != null) {
        return DecoratedBox(
          decoration: BoxDecoration(gradient: pageGradient),
          child: child,
        );
      }
      return ColoredBox(color: bg, child: child);
    }

    // Desktop/tablet: a persistent side rail beside a content Scaffold.
    if (isDesktop) {
      return shellBody(
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: double.infinity,
                child: FomraSideNav(currentRoute: currentRoute),
              ),
              Expanded(
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: appBar,
                  primary: true,
                  body: bodyWithBanner,
                  floatingActionButton: floatingActionButton,
                  floatingActionButtonLocation: floatingActionButtonLocation,
                  bottomNavigationBar: bottomNavigationBar,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile: ONE Scaffold owns both the drawer and the app bar, so the app
    // bar's automatic hamburger can find the drawer and open it. (Previously the
    // drawer sat on an outer Scaffold while the app bar was on an inner one, so
    // no hamburger showed.)
    return shellBody(
      Scaffold(
        backgroundColor: Colors.transparent,
        drawer: AppDrawer(currentRoute: currentRoute),
        appBar: appBar,
        primary: true,
        body: bodyWithBanner,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}
