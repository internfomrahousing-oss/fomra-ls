import 'package:flutter/material.dart';

import '../theme/fomra_theme_context.dart';
import 'fomra_side_nav.dart';
import 'fomra_universal_search.dart';

/// App layout with a persistent left navigation rail and main content area.
class FomraAppShell extends StatelessWidget {
  final String currentRoute;
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool showUniversalSearch;

  const FomraAppShell({
    super.key,
    required this.currentRoute,
    this.appBar,
    required this.body,
    this.backgroundColor,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.showUniversalSearch = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? context.fomraPageBg;

    return Scaffold(
      backgroundColor: bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FomraSideNav(currentRoute: currentRoute),
          Expanded(
            child: Scaffold(
              backgroundColor: bg,
              appBar: appBar,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showUniversalSearch) const FomraUniversalSearchBar(),
                  Expanded(child: body),
                ],
              ),
              floatingActionButton: floatingActionButton,
              floatingActionButtonLocation: floatingActionButtonLocation,
              bottomNavigationBar: bottomNavigationBar,
            ),
          ),
        ],
      ),
    );
  }
}
