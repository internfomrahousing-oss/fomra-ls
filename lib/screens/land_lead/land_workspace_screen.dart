import 'package:flutter/material.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import 'land_lead_screen.dart';

class LandWorkspaceScreen extends StatelessWidget {
  final int initialTab;
  const LandWorkspaceScreen({super.key, this.initialTab = 0});

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/land-lead',
      backgroundColor: context.fomraPageBg,
      appBar: const FomraAppBar(moduleName: 'Land Workspace'),
      body: const LandLeadScreen(isTab: true),
    );
  }
}
