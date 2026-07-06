import 'package:flutter/material.dart';

import '../theme/fomra_theme_context.dart';

/// Gives portal screen bodies a bounded, paintable area on Flutter web.
class FomraPortalBody extends StatelessWidget {
  final Widget child;

  const FomraPortalBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.fomraPageBg,
      child: SizedBox.expand(child: child),
    );
  }
}
