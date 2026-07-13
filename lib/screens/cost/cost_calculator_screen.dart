import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../analytics/business_module_metrics.dart';
import '../../services/app_store.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/ui/app_components.dart';
import '../land_lead/lead_detail_screen.dart';

/// Cost per acre and acquisition cost calculator.
class CostCalculatorScreen extends StatefulWidget {
  const CostCalculatorScreen({super.key});

  @override
  State<CostCalculatorScreen> createState() => _CostCalculatorScreenState();
}

class _CostCalculatorScreenState extends State<CostCalculatorScreen> {
  final _acresCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  AcquisitionCostResult? _manual;
  String _query = '';

  @override
  void initState() {
    super.initState();
    AppStore.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AppStore.instance.removeListener(_rebuild);
    _acresCtrl.dispose();
    _totalCtrl.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _calcManual() {
    final acres = double.tryParse(_acresCtrl.text.trim()) ?? 0;
    final total =
        AcquisitionCostCalculator.parseMoney(_totalCtrl.text) ?? 0;
    setState(() {
      _manual = AcquisitionCostCalculator.fromInputs(
        acres: acres,
        totalCost: total,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final acresFmt = NumberFormat('#,##0.##');
    final q = _query.trim().toLowerCase();
    final leadRows = AppStore.instance.visibleLeads
        .map((l) => (l, AcquisitionCostCalculator.fromLead(l)))
        .where((e) {
          if (e.$2.totalCost == null && e.$2.acres <= 0) return false;
          if (q.isEmpty) return true;
          final l = e.$1;
          return l.ownerName.toLowerCase().contains(q) ||
              l.leadId.toLowerCase().contains(q) ||
              l.village.toLowerCase().contains(q);
        })
        .toList()
      ..sort((a, b) =>
          (b.$2.totalCost ?? 0).compareTo(a.$2.totalCost ?? 0));

    return FomraAppShell(
      currentRoute: '/cost-calculator',
      appBar: FomraAppBar(
        moduleName: 'Cost Calculator',
        breadcrumbs: FomraBreadcrumbs.module('Cost Calculator'),
      ),
      body: ListView(
        padding: FomraLayout.pagePadding(context),
        children: [
          Text(
            'Cost Calculator',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Acquisition cost and cost per acre.',
            style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Manual calculation',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: context.fomraTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _acresCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Acres',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _totalCtrl,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    labelText: 'Total acquisition cost (₹)',
                    hintText: 'e.g. 2.5 Cr or 85 Lakh',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _calcManual,
                  child: const Text('Calculate'),
                ),
                if (_manual != null) ...[
                  const SizedBox(height: 14),
                  _resultBlock(_manual!, money, acresFmt),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'From leads (deal terms)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Filter leads…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: context.fomraSurfaceVar,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (leadRows.isEmpty)
            const AppCard(
              child: EmptyState(
                title: 'No cost data yet',
                message:
                    'Add Total Land Cost in deal terms, or use the manual calculator.',
              ),
            )
          else
            ...leadRows.take(40).map((e) {
              final lead = e.$1;
              final r = e.$2;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
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
                        lead.ownerName.trim().isEmpty
                            ? 'Lead #${lead.leadId}'
                            : lead.ownerName,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: context.fomraTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (lead.village.isNotEmpty) lead.village,
                          r.source,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _resultBlock(r, money, acresFmt),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _resultBlock(
    AcquisitionCostResult r,
    NumberFormat money,
    NumberFormat acresFmt,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _chip('Acres', acresFmt.format(r.acres)),
        _chip(
          'Acquisition',
          r.totalCost != null ? money.format(r.totalCost) : '—',
        ),
        _chip(
          'Per acre',
          r.costPerAcre != null ? money.format(r.costPerAcre) : '—',
          highlight: true,
        ),
      ],
    );
  }

  Widget _chip(String label, String value, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.12)
            : context.fomraSurfaceVar,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: context.fomraTextSecondary)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: highlight ? AppColors.primary : context.fomraTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
