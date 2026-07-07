import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
import '../../services/app_store.dart';
import '../../models/land_lead.dart';
import '../task_management/task_management_screen.dart';
import '../../widgets/land_workspace_ui.dart';
import '../../widgets/portal_page_layout.dart';
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

  int get _activeLeads => AppStore.instance.leads
      .where((l) => [
            LeadStatus.new_,
            LeadStatus.contacted,
            LeadStatus.siteVisit,
            LeadStatus.negotiation,
          ].contains(l.status))
      .length;

  int get _pendingTasks =>
      sharedTasks.where((t) => t.status != TaskStatus.done).length;

  int get _closedToday {
    final now = DateTime.now();
    return AppStore.instance.leads
        .where((l) =>
            l.status == LeadStatus.closed &&
            l.addedOn.year == now.year &&
            l.addedOn.month == now.month &&
            l.addedOn.day == now.day)
        .length;
  }

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_onStoreUpdate);
    _tabs = _buildTabs();
    final tabIndex = widget.initialTab.clamp(0, _tabs.length - 1);
    _tab = TabController(length: _tabs.length, vsync: this, initialIndex: tabIndex);
    _tab.addListener(() => setState(() {}));
  }

  void _onStoreUpdate() => setState(() {});

  List<_TabDef> _buildTabs() {
    return const [
      _TabDef('Land Lead', Icons.add_location_alt_outlined),
      _TabDef('Tasks', Icons.task_alt_outlined),
    ];
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_onStoreUpdate);
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
          preferredSize: const Size.fromHeight(96),
          child: Padding(
            padding: FomraLayout.pagePadding(context).copyWith(top: 0, bottom: 10),
            child: portalPageWidthConstraint(
              context,
              Column(
                children: [
                  Row(
                    children: [
                      LandWorkspaceStatPill(
                        label: 'Active Leads',
                        value: _activeLeads,
                        icon: Icons.bolt_outlined,
                        accent: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      LandWorkspaceStatPill(
                        label: 'Pending Tasks',
                        value: _pendingTasks,
                        icon: Icons.pending_actions_outlined,
                        accent: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      LandWorkspaceStatPill(
                        label: 'Closed Today',
                        value: _closedToday,
                        icon: Icons.verified_outlined,
                        accent: AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  PortalFrostedTabBar(
                    controller: _tab,
                    tabs: _tabs
                        .map((t) => Tab(
                              height: 38,
                              icon: Icon(t.icon, size: 17),
                              text: t.label,
                              iconMargin: const EdgeInsets.only(bottom: 2),
                            ))
                        .toList(),
                  ),
                ],
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
