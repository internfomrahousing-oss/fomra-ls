import 'package:flutter/material.dart';
import '../../models/add_lead_result.dart';
import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../services/land_lead_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_bottom_nav.dart';
import 'add_lead_screen.dart';
import 'lead_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_onStoreUpdate);
    _loadLeads();
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

  List<LandLead> get _leads => AppStore.instance.leads;

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
    final body = Column(
      children: [
        if (_leads.isNotEmpty) _LeadSummary(leads: _leads),
        if (_leads.isNotEmpty)
          _SearchBar(
            onChanged: (q) => setState(() => _search = q),
            filterStatus: _filterStatus,
            onClearFilter: () => setState(() => _filterStatus = null),
            onFilter: widget.isTab && _leads.isNotEmpty && !_loading
                ? _showFilter
                : null,
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined,
                                size: 48, color: AppColors.textSecondary),
                            const SizedBox(height: 12),
                            Text(_loadError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: AppColors.textSecondary)),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadLeads,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _filtered.isEmpty
                      ? _EmptyState(hasLeads: _leads.isNotEmpty)
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) {
                            final lead = _filtered[i];
                            return Dismissible(
                              key: ValueKey(lead.leadId),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) => _confirmAndDelete(lead),
                              background: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(16),
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
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        LeadDetailScreen(lead: lead),
                                  ),
                                ),
                                onStatusChange: (s) => _updateStatus(lead, s),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );

    final fab = FloatingActionButton.extended(
      onPressed: _openAddLead,
      icon: const Icon(Icons.add_location_alt_outlined),
      label: const Text('Add Lead'),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    );

    if (widget.isTab) {
      return Scaffold(body: body, floatingActionButton: fab);
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
                    radius: 8, backgroundColor: _statusColor(s)),
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
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add_location_alt_outlined,
                size: 44,
                color: AppColors.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          Text(
            hasLeads
                ? 'No leads match the current filter.'
                : 'No land leads yet.\nTap Add Lead to capture your first lead.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
                fontWeight: FontWeight.w500),
          ),
        ]),
      );
}

// ── Summary Bar ───────────────────────────────────────────────────────────────

class _LeadSummary extends StatelessWidget {
  final List<LandLead> leads;
  const _LeadSummary({required this.leads});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: LeadStatus.values.where((s) => s != LeadStatus.siteVisit).map((s) {
          final count = leads.where((l) => l.status == s).length;
          return Column(children: [
            Text('$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(s.label,
                style: const TextStyle(
                    color: Color(0xFFB0BEC5), fontSize: 10)),
          ]);
        }).toList(),
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
        color: AppColors.primary,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by owner, location, survey no…',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.15),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          if (onFilter != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.white70),
              onPressed: onFilter,
              tooltip: 'Filter',
            ),
          ],
        ]),
      ),
      if (filterStatus != null)
        Container(
          color: AppColors.primary.withValues(alpha: 0.08),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

  const _LeadCard({
    required this.lead,
    required this.onStatusChange,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(lead.status);
    final sourceColor = _sourceColor(lead.inputSource);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(lead.leadId,
                        style: const TextStyle(
                            fontSize: 17,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3)),
                    const Spacer(),
                    _StatusBadge(status: lead.status),
                  ]),
                  const SizedBox(height: 4),
                  Text(lead.ownerName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        [lead.location, lead.village, lead.district]
                            .where((s) => s.isNotEmpty)
                            .join(', '),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Wrap(spacing: 12, children: [
                    if (lead.surveyNumber.isNotEmpty)
                      _Chip(Icons.tag, 'Survey: ${lead.surveyNumber}'),
                    if (lead.landExtent.isNotEmpty)
                      _Chip(Icons.straighten, lead.landExtent),
                    _Chip(Icons.terrain_outlined, lead.landType.label),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: sourceColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_sourceIcon(lead.inputSource),
                                size: 11, color: sourceColor),
                            const SizedBox(width: 4),
                            Text(lead.inputSource.label,
                                style: TextStyle(
                                    fontSize: 10,
                                    color: sourceColor,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                    const Spacer(),
                    const Icon(Icons.calendar_today,
                        size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                        '${lead.addedOn.day}/${lead.addedOn.month}/${lead.addedOn.year}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                  ]),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: LeadStatus.values
                          .where((s) => s != lead.status && s != LeadStatus.siteVisit)
                          .map((s) => Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: OutlinedButton(
                                  onPressed: () => onStatusChange(s),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    side: BorderSide(
                                        color: _statusColor(s)
                                            .withValues(alpha: 0.5)),
                                  ),
                                  child: Text('→ ${s.label}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: _statusColor(s))),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ]),
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
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
      ]);
}

class _StatusBadge extends StatelessWidget {
  final LeadStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final c = _statusColor(status);
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

Color _statusColor(LeadStatus s) => switch (s) {
      LeadStatus.new_ => AppColors.info,
      LeadStatus.contacted => const Color(0xFF8B5CF6),
      LeadStatus.siteVisit => AppColors.warning,
      LeadStatus.negotiation => AppColors.accent,
      LeadStatus.closed => AppColors.success,
      LeadStatus.lost => AppColors.error,
    };

Color _sourceColor(InputSource s) => switch (s) {
      InputSource.broker => AppColors.info,
      InputSource.landowner => AppColors.primary,
      InputSource.referral => const Color(0xFF8B5CF6),
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
