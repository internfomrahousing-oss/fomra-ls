import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../analytics/business_module_metrics.dart';
import '../../models/land_lead.dart';
import '../../models/land_lead_meeting.dart';
import '../../services/app_store.dart';
import '../../services/land_lead_meeting_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/contact_call_whatsapp.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/lead_portfolio_breakdown.dart';
import '../../widgets/ui/app_components.dart';
import '../land_lead/lead_detail_screen.dart';

/// Broker performance: leads, conversions, success rate.
class BrokerManagementScreen extends StatefulWidget {
  const BrokerManagementScreen({super.key});

  @override
  State<BrokerManagementScreen> createState() => _BrokerManagementScreenState();
}

class _BrokerManagementScreenState extends State<BrokerManagementScreen> {
  String _query = '';
  String? _expandedBroker;

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

  @override
  Widget build(BuildContext context) {
    final rows = BrokerPerformanceAnalytics.compute(AppStore.instance.visibleLeads)
        .where((r) =>
            _query.isEmpty ||
            r.name.toLowerCase().contains(_query.toLowerCase()) ||
            r.contact.contains(_query))
        .toList();
    final totalLeads = rows.fold<int>(0, (s, r) => s + r.leads);
    final totalConv = rows.fold<int>(0, (s, r) => s + r.conversions);
    final rate = totalLeads == 0 ? 0.0 : (totalConv / totalLeads) * 100;
    final pct = NumberFormat('0.0');

    final ranked = rows.where((r) => r.leads > 0).toList()
      ..sort((a, b) {
        final byRate = b.successRate.compareTo(a.successRate);
        return byRate != 0 ? byRate : b.conversions.compareTo(a.conversions);
      });
    final topBroker = ranked.isEmpty ? null : ranked.first;

    return FomraAppShell(
      currentRoute: '/broker-management',
      appBar: FomraAppBar(
        moduleName: 'Broker Management',
        breadcrumbs: FomraBreadcrumbs.module('Broker Management'),
      ),
      body: ListView(
        padding: FomraLayout.pagePadding(context),
        children: [
          Text(
            'Broker Management',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Performance, leads, conversions, and success rate by broker.',
            style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _kpi('Brokers', '${rows.length}', AppColors.primary),
              _kpi('Leads', '$totalLeads', AppColors.info),
              _kpi('Conversions', '$totalConv', AppColors.success),
              _kpi('Success rate', '${pct.format(rate)}%', AppColors.warning),
              if (topBroker != null) _topBrokerKpi(context, topBroker, pct),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search broker…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: context.fomraSurfaceVar,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            const AppCard(
              child: EmptyState(
                title: 'No broker leads yet',
                message: 'Brokers appear when leads include a broker name.',
              ),
            )
          else
            ...rows.map((r) {
              final expanded = _expandedBroker == r.name.toLowerCase();
              final brokerLeads = AppStore.instance.visibleLeads
                  .where((l) =>
                      l.brokerName.trim().toLowerCase() == r.name.toLowerCase())
                  .toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => setState(() {
                    _expandedBroker = expanded ? null : r.name.toLowerCase();
                  }),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: context.fomraTextPrimary,
                              ),
                            ),
                          ),
                          ContactCallWhatsApp(
                            contact: r.contact,
                            accent: AppColors.secondary,
                          ),
                          Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            color: context.fomraTextSecondary,
                          ),
                        ],
                      ),
                      if (r.contact.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(r.contact,
                            style: TextStyle(
                                color: context.fomraTextSecondary,
                                fontSize: 12)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _chip('Leads ${r.leads}'),
                          const SizedBox(width: 8),
                          _chip('Converted ${r.conversions}'),
                          const SizedBox(width: 8),
                          _chip('Active ${r.active}'),
                          const Spacer(),
                          Text(
                            '${pct.format(r.successRate)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (r.successRate / 100).clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: context.fomraBorder,
                          color: AppColors.success,
                        ),
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 14),
                        _BrokerPortfolioSection(leads: brokerLeads),
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

  Widget _kpi(String label, String value, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: context.fomraTextSecondary)),
        ],
      ),
    );
  }

  Widget _topBrokerKpi(
    BuildContext context,
    BrokerPerformanceRow broker,
    NumberFormat pct,
  ) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined,
                  size: 16, color: AppColors.secondary),
              const SizedBox(width: 6),
              Text(
                'Top Performing Broker',
                style: TextStyle(
                  fontSize: 11,
                  color: context.fomraTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            broker.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${pct.format(broker.successRate)}% success · ${broker.conversions} sites closed',
            style: TextStyle(fontSize: 11, color: context.fomraTextSecondary),
          ),
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

/// Loads the meetings-conducted count for a broker's leads, then renders the
/// shared portfolio breakdown with a Lead Age column instead of Status.
class _BrokerPortfolioSection extends StatefulWidget {
  final List<LandLead> leads;

  const _BrokerPortfolioSection({required this.leads});

  @override
  State<_BrokerPortfolioSection> createState() =>
      _BrokerPortfolioSectionState();
}

class _BrokerPortfolioSectionState extends State<_BrokerPortfolioSection> {
  bool _loading = true;
  int _meetingsConducted = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _BrokerPortfolioSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leads != widget.leads) _load();
  }

  Future<void> _load() async {
    try {
      final lists = await Future.wait<List<LandLeadMeeting>>(
        widget.leads.map((l) => LandLeadMeetingService.getForLead(l.leadId)),
      );
      final total = lists.fold<int>(0, (s, meetings) => s + meetings.length);
      if (!mounted) return;
      setState(() {
        _meetingsConducted = total;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LeadPortfolioBreakdown(
      leads: widget.leads,
      meetingsConducted: _loading ? null : _meetingsConducted,
      useLeadAgeColumn: true,
      onOpenLead: (lead) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
      ),
    );
  }
}
