import 'package:flutter/material.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
import '../task_management/task_management_screen.dart';
import 'land_lead_screen.dart';

class LandWorkspaceScreen extends StatefulWidget {
  final int initialTab;
  const LandWorkspaceScreen({super.key, this.initialTab = 0});

  @override
  State<LandWorkspaceScreen> createState() => _LandWorkspaceScreenState();
}

class _LandWorkspaceScreenState extends State<LandWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final List<_TabDef> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabs();
    final tabIndex = widget.initialTab.clamp(0, _tabs.length - 1);
    _tab = TabController(length: _tabs.length, vsync: this, initialIndex: tabIndex);
    _tab.addListener(() => setState(() {}));
  }

  List<_TabDef> _buildTabs() {
    return const [
      _TabDef('Land Lead', Icons.add_location_alt_outlined),
      _TabDef('Tasks', Icons.task_alt_outlined),
    ];
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.fomraPageBg,
      appBar: FomraAppBar(
        moduleName: 'Land Workspace',
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tab,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                  ),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
                tabs: _tabs
                    .map((t) => Tab(
                          height: 42,
                          icon: Icon(t.icon, size: 18),
                          text: t.label,
                          iconMargin: const EdgeInsets.only(bottom: 2),
                        ))
                    .toList(),
              ),
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(currentRoute: '/land-lead'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/land-lead'),
      body: TabBarView(
        controller: _tab,
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          LandLeadScreen(isTab: true),
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
