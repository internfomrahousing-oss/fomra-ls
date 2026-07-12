import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../analytics/business_module_metrics.dart';
import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/ui/app_components.dart';
import '../land_lead/lead_detail_screen.dart';

class _OwnerHistoryGroup {
  final String ownerKey;
  final String ownerName;
  final String contact;
  final List<LandLead> leads;

  const _OwnerHistoryGroup({
    required this.ownerKey,
    required this.ownerName,
    required this.contact,
    required this.leads,
  });

  int get negotiations =>
      leads.where((l) => l.status == LeadStatus.negotiation).length;
}

/// Historical negotiations grouped by landowner.
class OwnerHistoryScreen extends StatefulWidget {
  const OwnerHistoryScreen({super.key});

  @override
  State<OwnerHistoryScreen> createState() => _OwnerHistoryScreenState();
}

class _OwnerHistoryScreenState extends State<OwnerHistoryScreen> {
  String _query = '';
  String? _expandedKey;

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  List<_OwnerHistoryGroup> get _groups {
    final map = <String, List<LandLead>>{};
    for (final lead in AppStore.instance.leads) {
      final name = lead.ownerName.trim();
      if (name.isEmpty) continue;
      final contact = lead.contactDetails.replaceAll(RegExp(r'[^\d+]'), '');
      final key = '${name.toLowerCase()}|$contact';
      (map[key] ??= []).add(lead);
    }
    final q = _query.trim().toLowerCase();
    final groups = map.entries.map((e) {
      final leads = e.value
        ..sort((a, b) => b.addedOn.compareTo(a.addedOn));
      return _OwnerHistoryGroup(
        ownerKey: e.key,
        ownerName: leads.first.ownerName.trim(),
        contact: leads
            .map((l) => l.contactDetails.trim())
            .firstWhere((c) => c.isNotEmpty, orElse: () => ''),
        leads: leads,
      );
    }).where((g) {
      if (q.isEmpty) return true;
      return g.ownerName.toLowerCase().contains(q) ||
          g.contact.contains(q) ||
          g.leads.any((l) =>
              l.village.toLowerCase().contains(q) ||
              l.leadId.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => b.leads.length.compareTo(a.leads.length));
    return groups;
  }

  List<String> _noteLines(LandLead lead) {
    if (lead.notes.trim().isEmpty) return const [];
    return lead.notes
        .trim()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList()
        .reversed
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final df = DateFormat('dd MMM yyyy');
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return FomraAppShell(
      currentRoute: '/owner-history',
      body: ListView(
        padding: FomraLayout.pagePadding(context),
        children: [
          Text(
            'Owner History',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Historical negotiations by landowner.',
            style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search owner, contact, village…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: context.fomraSurfaceVar,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (groups.isEmpty)
            const AppCard(
              child: EmptyState(
                title: 'No owner history',
                message: 'Owners appear when leads include an owner name.',
              ),
            )
          else
            ...groups.map((g) {
              final expanded = _expandedKey == g.ownerKey;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => setState(() {
                    _expandedKey = expanded ? null : g.ownerKey;
                  }),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              g.ownerName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: context.fomraTextPrimary,
                              ),
                            ),
                          ),
                          Icon(
                            expanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: context.fomraTextSecondary,
                          ),
                        ],
                      ),
                      if (g.contact.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          g.contact,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          _chip('${g.leads.length} lead(s)'),
                          _chip('${g.negotiations} negotiation'),
                        ],
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 14),
                        for (final lead in g.leads) ...[
                          const Divider(height: 20),
                          InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LeadDetailScreen(lead: lead),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lead #${lead.leadId} · ${lead.status.label}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    if (lead.village.isNotEmpty) lead.village,
                                    df.format(lead.addedOn),
                                    if (lead.landExtent.isNotEmpty)
                                      lead.landExtent,
                                  ].join(' · '),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.fomraTextSecondary,
                                  ),
                                ),
                                Builder(builder: (_) {
                                  final cost =
                                      AcquisitionCostCalculator.fromLead(lead);
                                  if (cost.totalCost == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      'Deal: ${money.format(cost.totalCost)}'
                                      '${cost.costPerAcre != null ? ' · ${money.format(cost.costPerAcre)}/acre' : ''}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  );
                                }),
                                if (lead.accessDetails.trim().isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    lead.accessDetails.trim(),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.fomraTextSecondary,
                                    ),
                                  ),
                                ],
                                for (final note in _noteLines(lead))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ',
                                            style: TextStyle(fontSize: 12)),
                                        Expanded(
                                          child: Text(
                                            note,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.fomraSurfaceVar,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      );
}
