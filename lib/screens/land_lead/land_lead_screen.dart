import 'package:flutter/material.dart';
import '../../models/add_lead_result.dart';
import '../../models/land_lead.dart';
import '../../models/employee_profile.dart';
import '../../services/app_store.dart';
import '../../services/auth_service.dart';
import '../../services/employee_service.dart';
import '../../services/land_lead_service.dart';
import '../../services/notifications_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
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
  LeadStatus? _filterStatus;
  String _search = '';
  bool _loading = true;
  String? _loadError;

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
    final names = _employeeNames;
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No employees available to assign.'),
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
      AppStore.instance.replaceLead(lead.copyWith(createdByName: name));
      LandLeadService.assignTo(id, name).catchError((_) {
        AppStore.instance
            .replaceLead(lead.copyWith(createdByName: previousName));
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
        final matchStatus = _filterStatus == null || l.status == _filterStatus;
        final q = _search.toLowerCase();
        final matchSearch = q.isEmpty ||
            l.ownerName.toLowerCase().contains(q) ||
            l.location.toLowerCase().contains(q) ||
            l.surveyNumber.toLowerCase().contains(q) ||
            l.leadId.toLowerCase().contains(q);
        return matchStatus && matchSearch;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final body = _buildScrollableBody();

    final fab = Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AppColors.coloredShadow(AppColors.primary),
      ),
      child: FloatingActionButton.extended(
        onPressed: _openAddLead,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add Lead'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
    );

    if (widget.isTab) {
      return Scaffold(
        backgroundColor: context.fomraPageBg,
        body: body,
        floatingActionButton: fab,
      );
    }
    return Scaffold(
      appBar: FomraAppBar(
        moduleName: 'Land Lead',
        actions: [
          if (_leads.isNotEmpty && !_loading)
            IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: _showFilter),
        ],
      ),
      drawer: const AppDrawer(currentRoute: '/land-lead'),
      bottomNavigationBar: const FomraBottomNav(currentRoute: '/land-lead'),
      body: body,
      floatingActionButton: fab,
    );
  }

  void _openLeadsMap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LeadsMapScreen(leads: _leads),
      ),
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

  Widget _buildIdleManagementActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _actionPill(
          onTap: _toggleSelectMode,
          icon: Icons.checklist_rtl,
          label: 'Select',
        ),
        const SizedBox(height: 8),
        _actionPill(
          onTap: _openLeadsMap,
          icon: Icons.map_outlined,
          label: 'Show all projects',
          foreground: AppColors.primaryDark,
          background: AppColors.primary.withValues(alpha: 0.10),
        ),
      ],
    );
  }

  Widget _buildSelectBar() {
    if (!_selectMode) return const SizedBox.shrink();
    final count = _selectedLeadIds.length;
    final canAssign = count > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
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
      return const _LeadsLoadingSkeleton();
    }

    if (_loadError != null) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Couldn’t load leads',
        message: _loadError,
        action: PrimaryButton(
          label: 'Retry',
          icon: Icons.refresh,
          onPressed: _loadLeads,
        ),
      );
    }

    final slivers = <Widget>[
      if (_isManagement && _selectMode && _leads.isNotEmpty)
        SliverToBoxAdapter(child: _buildSelectBar()),
      if (_leads.isNotEmpty)
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isManagement && !_selectMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildIdleManagementActions(),
                  ),
                ),
              _LeadSummary(leads: _leads),
            ],
          ),
        ),
      if (_leads.isNotEmpty)
        SliverToBoxAdapter(
          child: _SearchBar(
            onChanged: (q) => setState(() => _search = q),
            filterStatus: _filterStatus,
            onClearFilter: () => setState(() => _filterStatus = null),
            onFilter: widget.isTab && _leads.isNotEmpty && !_loading
                ? _showFilter
                : null,
          ),
        ),
    ];

    if (_filtered.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(hasLeads: _leads.isNotEmpty),
        ),
      );
    } else {
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
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
                  ),
                );
              },
              childCount: _filtered.length,
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
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

  void _showFilter() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Filter by Status',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ListTile(
              title: const Text('All Leads'),
              leading: const Icon(Icons.list),
              onTap: () {
                setState(() => _filterStatus = null);
                Navigator.pop(context);
              }),
          ...LeadStatus.values.where((s) => s != LeadStatus.siteVisit).map((s) => ListTile(
                leading: CircleAvatar(
                    radius: 8, backgroundColor: s.color),
                title: Text(s.label),
                onTap: () {
                  setState(() => _filterStatus = s);
                  Navigator.pop(context);
                },
              )),
        ],
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasLeads;
  const _EmptyState({required this.hasLeads});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.add_location_alt_outlined,
        title: hasLeads ? 'No matching leads' : 'No land leads yet',
        message: hasLeads
            ? 'No leads match the current filter. Try clearing it.'
            : 'Tap Add Lead to capture your first land lead.',
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

    return Container(
      color: context.fomraPageBg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SizedBox(
        height: 122,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: kpis.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final status = kpis[i].$1;
            final icon = kpis[i].$2;
            final count = leads.where((l) => l.status == status).length;
            final color = status.color;
            return Container(
              width: 152,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.fomraSurface,
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                border: Border.all(color: context.fomraBorder),
                boxShadow: context.fomraCardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const Spacer(),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status.label,
                    style: TextStyle(
                      color: context.fomraTextPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: leads.isEmpty
                          ? 0
                          : (count / leads.length).clamp(0, 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Search + Filter Bar ───────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  final LeadStatus? filterStatus;
  final VoidCallback onClearFilter;
  final VoidCallback? onFilter;

  const _SearchBar({
    required this.onChanged,
    required this.filterStatus,
    required this.onClearFilter,
    this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.fomraSurface,
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          border: Border.all(color: context.fomraBorder.withValues(alpha: 0.7)),
          boxShadow: context.fomraCardShadow,
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(color: context.fomraTextPrimary),
              decoration: InputDecoration(
                hintText: 'Search by owner, location, survey no…',
                hintStyle: TextStyle(color: context.fomraTextSecondary),
                prefixIcon: Icon(Icons.search, color: context.fomraTextSecondary),
                filled: true,
                fillColor: context.fomraSurfaceVar,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          if (onFilter != null) ...[
            const SizedBox(width: 10),
            Material(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: onFilter,
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(11),
                  child: Icon(Icons.tune_rounded,
                      color: AppColors.primary, size: 19),
                ),
              ),
            ),
          ],
        ]),
      ),
      if (filterStatus != null)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Text('Filtered: ${filterStatus!.label}',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            GestureDetector(
              onTap: onClearFilter,
              child: const Icon(Icons.close,
                  size: 16, color: AppColors.primary),
            ),
          ]),
        ),
    ]);
  }
}

// ── Lead Card ─────────────────────────────────────────────────────────────────

class _LeadCard extends StatelessWidget {
  final LandLead lead;
  final ValueChanged<LeadStatus> onStatusChange;
  final VoidCallback? onTap;
  final bool selectionMode;
  final bool selected;

  const _LeadCard({
    required this.lead,
    required this.onStatusChange,
    this.onTap,
    this.selectionMode = false,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = lead.status.color;
    final sourceColor = _sourceColor(lead.inputSource);
    final locationText = [lead.location, lead.village, lead.district]
        .where((s) => s.isNotEmpty)
        .join(', ');
    final title = lead.ownerName.trim().isNotEmpty
        ? lead.ownerName.trim()
        : 'Lead #${lead.leadId}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.fomraSurface,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(
            color: selected ? AppColors.primary : context.fomraBorder,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: context.fomraCardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header: [checkbox] avatar · name/ID · status pill ──
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
                                fontSize: 16,
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
                                fontSize: 12,
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
                  _LeadFieldRow(
                    icon: Icons.place_outlined,
                    text: locationText.isEmpty
                        ? 'Location not provided'
                        : locationText,
                  ),
                  if (lead.surveyNumber.isNotEmpty ||
                      lead.subDivision.isNotEmpty ||
                      lead.landExtent.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (lead.surveyNumber.isNotEmpty)
                          _Chip(Icons.tag, 'Survey ${lead.surveyNumber}'),
                        if (lead.subDivision.isNotEmpty)
                          _Chip(Icons.call_split_outlined,
                              'Sub ${lead.subDivision}'),
                        if (lead.landExtent.isNotEmpty)
                          _Chip(Icons.straighten, lead.landExtent),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Divider(height: 1, color: context.fomraBorder),
                  const SizedBox(height: 12),
                  // ── Footer: source · creator · date ──
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: sourceColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(_sourceIcon(lead.inputSource),
                            size: 12, color: sourceColor),
                        const SizedBox(width: 5),
                        Text(lead.inputSource.label,
                            style: TextStyle(
                                fontSize: 10,
                                color: sourceColor,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    if (lead.createdByName.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.person_outline,
                          size: 12, color: context.fomraTextTertiary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          lead.createdByName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: context.fomraTextSecondary,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: context.fomraTextTertiary),
                    const SizedBox(width: 5),
                    Text(
                        '${lead.addedOn.day}/${lead.addedOn.month}/${lead.addedOn.year}',
                        style: TextStyle(
                            fontSize: 11, color: context.fomraTextSecondary)),
                  ]),
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
                                          horizontal: 12, vertical: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      side: BorderSide(
                                          color:
                                              s.color.withValues(alpha: 0.5)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                    child: Text('→ ${s.label}',
                                        style: TextStyle(
                                            fontSize: 11, color: s.color)),
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
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.fomraSurfaceVar,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        ]),
      );
}

class _LeadFieldRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _LeadFieldRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.fomraTextSecondary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final LeadStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = status.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20)),
      child: Text(status.label,
          style: TextStyle(
              fontSize: 10, color: c, fontWeight: FontWeight.w700)),
    );
  }
}

Color _sourceColor(InputSource s) => switch (s) {
      InputSource.broker => AppColors.info,
      InputSource.landowner => AppColors.primary,
      InputSource.referral => AppColors.primaryLight,
      InputSource.internalTeam => AppColors.secondary,
      InputSource.existingDatabase => AppColors.success,
    };

IconData _sourceIcon(InputSource s) => switch (s) {
      InputSource.broker => Icons.handshake_outlined,
      InputSource.landowner => Icons.person_pin_outlined,
      InputSource.referral => Icons.group_outlined,
      InputSource.internalTeam => Icons.business_center_outlined,
      InputSource.existingDatabase => Icons.storage_outlined,
    };
