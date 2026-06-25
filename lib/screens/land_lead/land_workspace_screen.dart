import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
import 'land_lead_screen.dart';
import '../market_intelligence/market_intelligence_screen.dart';
import '../legal_verification/legal_verification_screen.dart';
import '../task_management/task_management_screen.dart';

class LandWorkspaceScreen extends StatefulWidget {
  final int initialTab;
  const LandWorkspaceScreen({super.key, this.initialTab = 0});

  @override
  State<LandWorkspaceScreen> createState() => _LandWorkspaceScreenState();
}

class _LandWorkspaceScreenState extends State<LandWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  static const _tabs = [
    _TabDef('Land Lead',   Icons.add_location_alt_outlined),
    _TabDef('Market',      Icons.insights_outlined),
    _TabDef('Legal',       Icons.gavel_outlined),
    _TabDef('Tasks',       Icons.task_alt_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(
        length: _tabs.length, vsync: this, initialIndex: widget.initialTab);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: FomraAppBar(
        moduleName: _tabs[_tab.index].label,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          tabs: _tabs
              .map((t) => Tab(
                    icon: Icon(t.icon, size: 18),
                    text: t.label,
                    iconMargin: const EdgeInsets.only(bottom: 2),
                  ))
              .toList(),
        ),
      ),
      drawer: const AppDrawer(currentRoute: '/land-lead'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/land-lead'),
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          LandLeadScreen(isTab: true),
          MarketIntelligenceScreen(isTab: true),
          LegalVerificationScreen(isTab: true),
          TaskManagementScreen(isTab: true),
        ],
      ),
    );
  }
}

class _TabDef {
  final String label;
  final IconData icon;
  const _TabDef(this.label, this.icon);
}
