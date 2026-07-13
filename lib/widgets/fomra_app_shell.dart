import 'package:flutter/material.dart';

import '../theme/fomra_layout.dart';
import '../theme/fomra_theme_context.dart';
import 'app_drawer.dart';
import 'fomra_side_nav.dart';

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
    final isDesktop = FomraLayout.isDesktop(context);
    final pageGradient = context.fomraPageGradient;
    final bg = backgroundColor ?? context.fomraPageBg;

    Widget shellBody(Widget child) {
      if (pageGradient != null) {
        return DecoratedBox(
          decoration: BoxDecoration(gradient: pageGradient),
          child: child,
        );
      }
      return ColoredBox(color: bg, child: child);
    }

    return shellBody(
      Scaffold(
        backgroundColor: Colors.transparent,
        drawer: isDesktop ? null : AppDrawer(currentRoute: currentRoute),
        body: isDesktop
            ? Row(
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
                      body: body,
                      floatingActionButton: floatingActionButton,
                      floatingActionButtonLocation:
                          floatingActionButtonLocation,
                      bottomNavigationBar: bottomNavigationBar,
                    ),
                  ),
                ],
              )
            : Scaffold(
                backgroundColor: Colors.transparent,
                appBar: appBar,
                primary: true,
                body: body,
                floatingActionButton: floatingActionButton,
                floatingActionButtonLocation: floatingActionButtonLocation,
                bottomNavigationBar: bottomNavigationBar,
              ),
      ),
    );
  }
}
