import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/add_lead_result.dart';
import '../../models/land_lead.dart';
import '../../models/employee_profile.dart';
import '../../services/app_store.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../services/land_lead_service.dart';
import '../../services/notifications_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
import '../../widgets/land_workspace_ui.dart';
import '../../widgets/portal_home_sections.dart';
import '../../widgets/portal_page_layout.dart';
import '../../widgets/ui/app_components.dart';
import 'add_lead_screen.dart';
import 'lead_detail_screen.dart';
import 'leads_map_screen.dart';

class LandLeadScreen extends StatefulWidget {
  final bool isTab;
  const LandLeadScreen({super.key, this.isTab = false});

  @override
  State<LandLeadScreen> createState() => _LandLeadScreenState();
}

class _LandLeadScreenState extends State<LandLeadScreen> {
  String _search = '';
  bool _loading = true;
  String? _loadError;

  final LandWorkspaceFilters _filters = LandWorkspaceFilters();

  bool _selectMode = false;
  final Set<String> _selectedLeadIds = {};

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_onStoreUpdate);
    _loadLeads();
    if (AuthService.instance.isManagement) _loadEmployees();
  }

  bool get _isManagement => AuthService.instance.isManagement;

  /// Employee names management can assign leads to.
  List<String> get _employeeNames => AppStore.instance.employees
      .where((e) => e.status == EmployeeStatus.active)
      .map((e) => e.fullName)
      .toList();

  /// Names to offer when assigning [leadIds]: drops anyone who is already the
  /// assignee of every selected lead (assigning to them would be a no-op).
  List<String> _assignableNamesFor(Set<String> leadIds) {
    final selected = AppStore.instance.leads
        .where((l) => leadIds.contains(l.leadId))
        .toList();
    if (selected.isEmpty) return _employeeNames;
    return _employeeNames.where((n) {
      final name = n.trim().toLowerCase();
      final ownsEvery = selected
          .every((l) => l.createdByName.trim().toLowerCase() == name);
      return !ownsEvery;
    }).toList();
  }

  Future<void> _loadEmployees() async {
    if (AppStore.instance.employees.isNotEmpty) return;
    try {
      final list = await EmployeeService.getAll();
      if (list.isNotEmpty) AppStore.instance.setEmployees(list);
    } catch (_) {/* assignment picker just stays empty */}
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selectedLeadIds.clear();
    });
  }

  void _toggleLeadSelected(LandLead lead) {
    setState(() {
      if (!_selectedLeadIds.remove(lead.leadId)) {
        _selectedLeadIds.add(lead.leadId);
      }
    });
  }

  /// Ask which employee to assign the selected leads to, confirm, then assign.
  Future<void> _assignSelected() async {
    if (_selectedLeadIds.isEmpty) return;
    final names = _assignableNamesFor(_selectedLeadIds);
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No other employees to assign these lead(s) to.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // 1) Pick employee.
    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.fomraSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Text('Assign ${_selectedLeadIds.length} lead(s) to',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.fomraTextPrimary)),
            ]),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: names
                  .map((n) => ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          child: Text(n.isNotEmpty ? n[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(n),
                        onTap: () => Navigator.pop(ctx, n),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (name == null || !mounted) return;

    // 2) Confirm.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign leads?'),
        content: Text(
            'Assign ${_selectedLeadIds.length} lead(s) to $name? '
            'They will move to $name\'s leads page and $name will be notified.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Assign')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _assignLeadsTo(_selectedLeadIds.toList(), name);
  }

  void _assignLeadsTo(List<String> leadIds, String name) {
    final all = AppStore.instance.leads;
    for (final id in leadIds) {
      final lead = all.where((l) => l.leadId == id).cast<LandLead?>().firstOrNull;
      if (lead == null || lead.createdByName == name) continue;
      final previousName = lead.createdByName;
      final previousRole = lead.createdByRole;
      AppStore.instance.replaceLead(
        lead.copyWith(createdByName: name, createdByRole: 'management'),
      );
      LandLeadService.assignTo(id, name).catchError((_) {
        AppStore.instance.replaceLead(
          lead.copyWith(createdByName: previousName, createdByRole: previousRole),
        );
      });
    }
    // One targeted notification for the assignee.
    NotificationsService.create(
      audience: 'employee',
      type: 'lead',
      title: 'Leads assigned to you',
      leadId: leadIds.length == 1 ? leadIds.first : null,
      message: '${leadIds.length} lead(s) — assigned to $name',
    ).catchError((_) {});

    setState(() {
      _selectMode = false;
      _selectedLeadIds.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${leadIds.length} lead(s) assigned to $name'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_onStoreUpdate);
    super.dispose();
  }

  void _onStoreUpdate() => setState(() {});

  /// Extracts a readable message from Supabase (PostgrestException/AuthException)
  /// or any other error so failures are diagnosable instead of generic.
  String _errMsg(Object e) {
    try {
      final m = (e as dynamic).message;
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {}
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _loadLeads() async {
    if (mounted) setState(() { _loading = true; _loadError = null; });
    try {
      final leads = await LandLeadService.getAll();
      AppStore.instance.setLeads(leads);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Failed to load leads: ${_errMsg(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Management sees every lead; an employee sees only the leads they added.
  List<LandLead> get _leads {
    final all = AppStore.instance.leads;
    if (AuthService.instance.isManagement) return all;
    final me =
        (AuthService.instance.currentUser?.fullName ?? '').trim().toLowerCase();
    if (me.isEmpty) return all;
    return all
        .where((l) => l.createdByName.trim().toLowerCase() == me)
        .toList();
  }

  List<LandLead> get _filtered => _leads.where((l) {
        final matchStatus =
            _filters.status == null || l.status == _filters.status;
        final q = _search.toLowerCase();
        final matchSearch = q.isEmpty ||
            l.ownerName.toLowerCase().contains(q) ||
            l.location.toLowerCase().contains(q) ||
            l.surveyNumber.toLowerCase().contains(q) ||
            l.leadId.toLowerCase().contains(q);
        final matchLandType = _filters.landTypes.isEmpty ||
            _filters.landTypes.contains(l.landType);
        final matchSource = _filters.sources.isEmpty ||
            _filters.sources.contains(l.inputSource);
        final matchPriority = !_filters.highPriority ||
            l.status == LeadStatus.new_ ||
            l.status == LeadStatus.negotiation;
        final emp = _filters.assignedEmployee?.trim().toLowerCase();
        final matchEmployee = emp == null ||
            emp.isEmpty ||
            l.createdByName.trim().toLowerCase() == emp;
        final added = l.addedOn.toLocal();
        final matchFrom = _filters.createdFrom == null ||
            !added.isBefore(_filters.createdFrom!);
        final matchTo = _filters.createdTo == null ||
            !added.isAfter(_filters.createdTo!);
        return matchStatus &&
            matchSearch &&
            matchLandType &&
            matchSource &&
            matchPriority &&
            matchEmployee &&
            matchFrom &&
            matchTo;
      }).toList();

  int get _activeFilterCount => _filters.activeCount;

  void _clearAllFilters() {
    setState(_filters.clear);
  }

  void _applyFilters(LandWorkspaceFilters next) {
    setState(() {
      _filters.status = next.status;
      _filters.landTypes
        ..clear()
        ..addAll(next.landTypes);
      _filters.sources
        ..clear()
        ..addAll(next.sources);
      _filters.highPriority = next.highPriority;
      _filters.assignedEmployee = next.assignedEmployee;
      _filters.createdFrom = next.createdFrom;
      _filters.createdTo = next.createdTo;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildScrollableBody();

    // The "+" button goes straight to Add Lead. Management's Select / Show all
    // projects live as always-visible pills next to the lead summary.
    final fab = LandWorkspaceSpeedDial(
      onAddLead: _openAddLead,
    );

    if (widget.isTab) {
      return Scaffold(
        backgroundColor: context.fomraPageBg,
        body: body,
        floatingActionButton: fab,
      );
    }
    return Scaffold(
      appBar: const FomraAppBar(
        moduleName: 'Land Lead',
      ),
      drawer: const AppDrawer(currentRoute: '/land-lead'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/land-lead'),
      body: body,
      floatingActionButton: fab,
    );
  }

  /// Always-visible management actions shown next to the lead summary:
  /// Select (enter assign mode) and Show all projects (open the leads map).
  Widget _buildIdleManagementActions() {
    // Both pills on one row, sized to content so they sit in the empty space
    // to the right of the KPI summary tiles.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionPill(
          onTap: _toggleSelectMode,
          icon: Icons.checklist_rtl,
          label: 'Select',
        ),
        const SizedBox(width: 8),
        _actionPill(
          onTap: _openLeadsMap,
          icon: Icons.map_outlined,
          label: 'Show all projects',
          foreground: const Color(0xFF0F766E),
          background: const Color(0xFF0F766E).withValues(alpha: 0.10),
        ),
      ],
    );
  }

  Widget _actionPill({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    Color? foreground,
    Color? background,
  }) {
    final fg = foreground ?? AppColors.primary;
    final bg = background ?? AppColors.primary.withValues(alpha: 0.10);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: fg.withValues(alpha: 0.25)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }

  Widget _buildSelectBar() {
    if (!_selectMode) return const SizedBox.shrink();
    final count = _selectedLeadIds.length;
    final canAssign = count > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.primary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.05),
          ]),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: Row(children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: AppColors.primary, shape: BoxShape.circle),
            child: Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Text(count == 1 ? 'lead selected' : 'leads selected',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: context.fomraTextPrimary)),
          const Spacer(),
          TextButton(
            onPressed: _toggleSelectMode,
            style: TextButton.styleFrom(
                foregroundColor: context.fomraTextSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 10)),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 4),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canAssign ? _assignSelected : null,
              borderRadius: BorderRadius.circular(999),
              child: Opacity(
                opacity: canAssign ? 1 : 0.45,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)]),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: canAssign
                        ? AppColors.coloredShadow(AppColors.primary)
                        : null,
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.person_add_alt_1,
                        size: 17, color: Colors.white),
                    SizedBox(width: 7),
                    Text('Assign',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildScrollableBody() {
    if (_loading) {
      return portalPageBody(context, const _LeadsLoadingSkeleton());
    }

    if (_loadError != null) {
      return portalPageBody(
        context,
        EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Couldn’t load leads',
          message: _loadError,
          action: PrimaryButton(
            label: 'Retry',
            icon: Icons.refresh,
            onPressed: _loadLeads,
          ),
        ),
      );
    }

    final pagePad = FomraLayout.pagePadding(context);

    final slivers = <Widget>[
      if (_isManagement && _selectMode && _leads.isNotEmpty)
        SliverToBoxAdapter(
          child: PortalFadeSection(index: 0, child: _buildSelectBar()),
        ),
      if (_leads.isNotEmpty)
        SliverToBoxAdapter(
          child: PortalFadeSection(
            index: 0,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _LeadSummary(leads: _leads)),
                  if (_isManagement && !_selectMode) ...[
                    const SizedBox(width: 12),
                    _buildIdleManagementActions(),
                  ],
                ],
              ),
            ),
          ),
        ),
      if (_leads.isNotEmpty)
        SliverToBoxAdapter(
          child: PortalFadeSection(
            index: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LandWorkspaceSearchBar(
                  onChanged: (q) => setState(() => _search = q),
                  activeFilterCount: _activeFilterCount,
                  onFilterTap: _openFilterPanel,
                ),
                if (_filters.hasActive) ...[
                  const SizedBox(height: 10),
                  LandWorkspaceActiveFilterChips(
                    filters: _filters,
                    onChanged: () => setState(() {}),
                    onClearAll: _clearAllFilters,
                  ),
                ],
              ],
            ),
          ),
        ),
    ];

    if (_filtered.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            hasLeads: _leads.isNotEmpty,
            onAddLead: _leads.isNotEmpty ? _clearAllFilters : _openAddLead,
          ),
        ),
      );
    } else {
      slivers.add(
        SliverPadding(
          padding: pagePad.copyWith(top: 8, bottom: 96),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final lead = _filtered[i];
                return Dismissible(
                  key: ValueKey(lead.leadId),
                  direction: _selectMode
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  confirmDismiss: (_) => _confirmAndDelete(lead),
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline,
                            color: Colors.white, size: 26),
                        SizedBox(height: 4),
                        Text('Delete',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  child: _LeadCard(
                    lead: lead,
                    selectionMode: _selectMode,
                    selected: _selectedLeadIds.contains(lead.leadId),
                    onTap: _selectMode
                        ? () => _toggleLeadSelected(lead)
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeadDetailScreen(lead: lead),
                              ),
                            ),
                    onStatusChange: (s) => _updateStatus(lead, s),
                    onEdit: () => _openEditLead(lead),
                    onMap: () => _openLeadMap(lead),
                    onCall: lead.contactDetails.isNotEmpty
                        ? () {
                            Clipboard.setData(
                                ClipboardData(text: lead.contactDetails));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Contact copied: ${lead.contactDetails}'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : null,
                    onAssignTask: () => Navigator.pushNamed(
                      context,
                      '/task-management',
                    ),
                    onDocuments: () => _openEditLead(lead),
                  ),
                );
              },
              childCount: _filtered.length,
            ),
          ),
        ),
      );
    }

    // Full-width scroll view so the scrollbar sits at the window's right edge;
    // content is centered via side padding (same ~94% width as home).
    return LayoutBuilder(
      builder: (context, constraints) {
        final side =
            FomraLayout.isDesktop(context) ? constraints.maxWidth * 0.03 : 0.0;
        final pp = pagePad.copyWith(bottom: 0);
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  pp.left + side, pp.top, pp.right + side, pp.bottom),
              sliver: SliverMainAxisGroup(slivers: slivers),
            ),
          ],
        );
      },
    );
  }

  Future<bool> _confirmAndDelete(LandLead lead) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete Lead?'),
            content: Text(
              'This will permanently remove lead ${lead.leadId} (${lead.ownerName}).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return false;

    try {
      await LandLeadService.delete(lead.leadId);
      AppStore.instance.removeLead(lead.leadId);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: ${_errMsg(e)}'),
          backgroundColor: AppColors.error,
        ));
      }
      return false;
    }
  }

  void _updateStatus(LandLead lead, LeadStatus s) {
    AppStore.instance.updateLeadStatus(lead.leadId, s);
    LandLeadService.updateStatus(lead.leadId, s).catchError((_) {
      // Revert optimistic update on failure
      AppStore.instance.updateLeadStatus(lead.leadId, lead.status);
    });
  }

  Future<void> _openEditLead(LandLead lead) async {
    final result = await Navigator.push<AddLeadResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AddLeadScreen(existingLead: lead),
      ),
    );
    if (result == null) return;
    try {
      final saved = await LandLeadService.update(
        result.lead,
        sitePhotoBytes: result.sitePhotoBytes,
      );
      AppStore.instance.replaceLead(saved);
    } catch (e) {
      AppStore.instance.replaceLead(result.lead);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved locally; sync failed: $e')),
        );
      }
    }
  }

  void _openLeadMap(LandLead lead) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadsMapScreen(leads: [lead]),
      ),
    );
  }

  Future<void> _openAddLead() async {
    final result = await Navigator.push<AddLeadResult>(
      context,
      MaterialPageRoute(builder: (_) => const AddLeadScreen()),
    );
    if (result == null) return;

    try {
      final saved = await LandLeadService.create(
        result.lead,
        sitePhotoBytes: result.sitePhotoBytes,
      );
      AppStore.instance.addLead(saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lead ${saved.leadId} saved.'),
          backgroundColor: AppColors.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save lead: ${_errMsg(e)}'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
        ));
      }
    }
  }

  void _openLeadsMap() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LeadsMapScreen(leads: _leads)),
    );
  }

  Future<void> _openFilterPanel() async {
    final applied = await showLandWorkspaceFilterPanel(
      context: context,
      initial: _filters,
      employeeNames: _isManagement ? _employeeNames : const [],
    );
    if (applied != null && mounted) _applyFilters(applied);
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasLeads;
  final VoidCallback? onAddLead;
  const _EmptyState({required this.hasLeads, this.onAddLead});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.add_location_alt_outlined,
        title: hasLeads ? 'No matching leads' : 'No leads yet',
        message: hasLeads
            ? 'Try adjusting filters or search terms.'
            : 'Start by adding your first land lead.',
        action: onAddLead == null
            ? null
            : PrimaryButton(
                label: hasLeads ? 'Clear filters' : 'Add Lead',
                icon: hasLeads ? Icons.filter_alt_off : Icons.add,
                onPressed: onAddLead,
              ),
      );
}

// ── Loading Skeleton ──────────────────────────────────────────────────────────

class _LeadsLoadingSkeleton extends StatelessWidget {
  const _LeadsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        // Summary strip placeholders.
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (_, __) => const LoadingSkeleton(
                width: 152, height: 122, radius: AppColors.radiusMd),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        const LoadingSkeleton(height: 52, radius: AppColors.radiusSm),
        const SizedBox(height: AppSpacing.md),
        // Card placeholders.
        ...List.generate(
          4,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: LoadingSkeleton(height: 148, radius: AppColors.radiusMd),
          ),
        ),
      ],
    );
  }
}

// ── Summary Bar ───────────────────────────────────────────────────────────────

class _LeadSummary extends StatelessWidget {
  final List<LandLead> leads;
  const _LeadSummary({required this.leads});

  @override
  Widget build(BuildContext context) {
    final kpis = [
      (LeadStatus.new_, Icons.fiber_new_rounded),
      (LeadStatus.contacted, Icons.call_outlined),
      (LeadStatus.negotiation, Icons.handshake_outlined),
      (LeadStatus.closed, Icons.verified_outlined),
      (LeadStatus.lost, Icons.cancel_outlined),
    ];

    return SizedBox(
      height: 118,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kpis.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final status = kpis[i].$1;
          final icon = kpis[i].$2;
          final count = leads.where((l) => l.status == status).length;
          return LandWorkspaceStatusCard(
            statusName: status.label,
            subtitle: 'Leads',
            value: count,
            icon: icon,
            accent: status.color,
          );
        },
      ),
    );
  }
}

// ── Lead Card ─────────────────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  final LandLead lead;
  final ValueChanged<LeadStatus> onStatusChange;
  final VoidCallback? onTap;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onEdit;
  final VoidCallback? onMap;
  final VoidCallback? onCall;
  final VoidCallback? onAssignTask;
  final VoidCallback? onDocuments;

  const _LeadCard({
    required this.lead,
    required this.onStatusChange,
    this.onTap,
    this.selectionMode = false,
    this.selected = false,
    this.onEdit,
    this.onMap,
    this.onCall,
    this.onAssignTask,
    this.onDocuments,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = lead.status.color;
    final title = lead.ownerName.trim().isNotEmpty
        ? lead.ownerName.trim()
        : 'Lead #${lead.leadId}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: selected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
                border: Border.all(color: AppColors.primary, width: 1.5),
              )
            : const BoxDecoration(),
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.all(16),
          radius: AppColors.radiusLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (selectionMode) ...[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color:
                            selected ? AppColors.primary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : context.fomraBorder,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              size: 15, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.location_on_rounded,
                        color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Lead #${lead.leadId} · ${lead.landType.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status: lead.status),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _infoChip(context, Icons.tag, 'ID', lead.leadId),
                  _infoChip(context, Icons.landscape_outlined, 'Type', lead.landType.label),
                  if (lead.surveyNumber.isNotEmpty)
                    _infoChip(context, Icons.numbers, 'Survey', lead.surveyNumber),
                  if (lead.landExtent.isNotEmpty)
                    _infoChip(context, Icons.straighten, 'Area', lead.landExtent),
                  if (lead.village.isNotEmpty)
                    _infoChip(context, Icons.home_work_outlined, 'Village', lead.village),
                  if (lead.inputSource == InputSource.broker)
                    _infoChip(context, Icons.handshake_outlined, 'Broker', 'Yes'),
                  if (lead.createdByName.isNotEmpty)
                    _infoChip(
                      context,
                      Icons.person_outline,
                      lead.ownershipLabel,
                      lead.createdByName,
                    ),
                  _infoChip(
                    context,
                    Icons.calendar_today_outlined,
                    'Created',
                    '${lead.addedOn.day}/${lead.addedOn.month}/${lead.addedOn.year}',
                  ),
                ],
              ),
              if (!selectionMode) ...[
                const SizedBox(height: 12),
                LandWorkspaceLeadActions(
                  lead: lead,
                  onCall: onCall,
                  onMap: onMap,
                  onEdit: onEdit,
                  onAssignTask: onAssignTask,
                  onDocuments: onDocuments,
                ),
              ],
              if (!selectionMode) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: LeadStatus.values
                        .where((s) =>
                            s != lead.status && s != LeadStatus.siteVisit)
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: OutlinedButton(
                                onPressed: () => onStatusChange(s),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  side: BorderSide(
                                      color: s.color.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: Text('→ ${s.label}',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: s.color)),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: context.fomraTextSecondary),
          const SizedBox(width: 5),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.fomraTextSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.fomraTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final LeadStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 12, color: c, fontWeight: FontWeight.w700)),
    );
  }
}
