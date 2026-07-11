import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'add_lead_ui.dart';

// ── Configurable deal type definitions ─────────────────────────────────────────

class DealFieldConfig {
  final String id;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final int maxLines;

  const DealFieldConfig({
    required this.id,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });
}

class DealTypeConfig {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<String> subtypes;
  final List<DealFieldConfig> fields;

  const DealTypeConfig({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.subtypes,
    required this.fields,
  });
}

/// Static registry — extend here to add future deal types.
const kDealTypeConfigs = <DealTypeConfig>[
  DealTypeConfig(
    id: 'outright_purchase',
    title: 'Outright Purchase',
    description: 'Direct land acquisition with defined payment structure',
    icon: Icons.currency_rupee_rounded,
    subtypes: [
      'Full Cash Purchase',
      'Advance + Balance',
      'Installment Purchase',
      'Agreement to Sell',
      'Registered Sale Deed',
      'GPA Purchase',
    ],
    fields: [
      DealFieldConfig(
        id: 'total_land_cost',
        label: 'Total Land Cost',
        hint: 'e.g. ₹50,00,000',
        icon: Icons.payments_outlined,
        keyboardType: TextInputType.number,
      ),
      DealFieldConfig(
        id: 'advance_amount',
        label: 'Advance Amount',
        hint: 'e.g. ₹10,00,000',
        icon: Icons.account_balance_wallet_outlined,
        keyboardType: TextInputType.number,
      ),
      DealFieldConfig(
        id: 'balance_amount',
        label: 'Balance Amount',
        hint: 'e.g. ₹40,00,000',
        icon: Icons.balance_outlined,
        keyboardType: TextInputType.number,
      ),
      DealFieldConfig(
        id: 'registration_date',
        label: 'Registration Date',
        hint: 'e.g. 15 Aug 2026',
        icon: Icons.event_outlined,
      ),
      DealFieldConfig(
        id: 'payment_schedule',
        label: 'Payment Schedule',
        hint: 'Milestones or installment plan',
        icon: Icons.calendar_month_outlined,
        maxLines: 2,
      ),
    ],
  ),
  DealTypeConfig(
    id: 'joint_venture',
    title: 'Joint Venture',
    description: 'Partnership-based development with shared returns',
    icon: Icons.handshake_rounded,
    subtypes: [
      'Revenue Sharing',
      'Built-up Area Sharing',
      'Profit Sharing',
      'Hybrid JV',
      'Development Agreement',
      'Development Rights Agreement',
    ],
    fields: [
      DealFieldConfig(
        id: 'owner_share',
        label: 'Owner Share %',
        hint: 'e.g. 40',
        icon: Icons.pie_chart_outline_rounded,
        keyboardType: TextInputType.number,
      ),
      DealFieldConfig(
        id: 'developer_share',
        label: 'Developer Share %',
        hint: 'e.g. 60',
        icon: Icons.engineering_outlined,
        keyboardType: TextInputType.number,
      ),
      DealFieldConfig(
        id: 'revenue_sharing_ratio',
        label: 'Revenue Sharing Ratio',
        hint: 'e.g. 50:50 or 40:60',
        icon: Icons.trending_up_rounded,
      ),
      DealFieldConfig(
        id: 'project_duration',
        label: 'Project Duration',
        hint: 'e.g. 24 months',
        icon: Icons.timelapse_rounded,
      ),
    ],
  ),
  DealTypeConfig(
    id: 'marketing',
    title: 'Marketing',
    description: 'Sales and marketing engagement for the land parcel',
    icon: Icons.campaign_rounded,
    subtypes: [
      'Exclusive Marketing',
      'Non-Exclusive Marketing',
      'Sole Selling Agency',
      'Brokerage Agreement',
      'Channel Partner Agreement',
      'Sales Management',
    ],
    fields: [
      DealFieldConfig(
        id: 'commission_pct',
        label: 'Commission %',
        hint: 'e.g. 2.5',
        icon: Icons.percent_rounded,
        keyboardType: TextInputType.numberWithOptions(decimal: true),
      ),
      DealFieldConfig(
        id: 'exclusivity',
        label: 'Exclusivity',
        hint: 'Exclusive / Non-exclusive terms',
        icon: Icons.verified_user_outlined,
      ),
      DealFieldConfig(
        id: 'marketing_period',
        label: 'Marketing Period',
        hint: 'e.g. 6 months',
        icon: Icons.date_range_outlined,
      ),
    ],
  ),
  DealTypeConfig(
    id: 'deferred_payment',
    title: 'Deferred Payment',
    description: 'Structured payment plan over time',
    icon: Icons.schedule_rounded,
    subtypes: [
      'EMI Based',
      'Milestone Payment',
      'Construction Linked Payment',
      'Balloon Payment',
      'Revenue Linked Payment',
      'Post Registration Payment',
    ],
    fields: [
      DealFieldConfig(
        id: 'advance',
        label: 'Advance',
        hint: 'e.g. ₹5,00,000',
        icon: Icons.savings_outlined,
        keyboardType: TextInputType.number,
      ),
      DealFieldConfig(
        id: 'installments',
        label: 'Installments',
        hint: 'e.g. 12 monthly EMIs',
        icon: Icons.repeat_rounded,
      ),
      DealFieldConfig(
        id: 'interest_rate',
        label: 'Interest Rate',
        hint: 'e.g. 8.5% p.a.',
        icon: Icons.show_chart_rounded,
      ),
      DealFieldConfig(
        id: 'due_dates',
        label: 'Due Dates',
        hint: 'Payment due schedule',
        icon: Icons.event_note_outlined,
        maxLines: 2,
      ),
    ],
  ),
  DealTypeConfig(
    id: 'others',
    title: 'Others',
    description: 'Custom or specialized agreement types',
    icon: Icons.more_horiz_rounded,
    subtypes: [
      'Lease Agreement',
      'Land Exchange',
      'Development Rights Purchase',
      'Collaboration Agreement',
      'Power of Attorney',
      'Government Acquisition',
      'Land Pooling',
      'Custom Agreement',
    ],
    fields: [
      DealFieldConfig(
        id: 'agreement_name',
        label: 'Agreement Name',
        hint: 'Name of the agreement',
        icon: Icons.description_outlined,
      ),
      DealFieldConfig(
        id: 'description',
        label: 'Description',
        hint: 'Brief description of terms',
        icon: Icons.notes_outlined,
        maxLines: 2,
      ),
      DealFieldConfig(
        id: 'special_clauses',
        label: 'Special Clauses',
        hint: 'Notable clauses or conditions',
        icon: Icons.gavel_outlined,
        maxLines: 2,
      ),
      DealFieldConfig(
        id: 'remarks',
        label: 'Remarks',
        hint: 'Additional notes',
        icon: Icons.chat_bubble_outline_rounded,
        maxLines: 2,
      ),
    ],
  ),
];

const _kAccordionMotion = Duration(milliseconds: 280);
const _kFieldMotion = Duration(milliseconds: 260);
const _kCardRadius = 18.0;

/// Maps legacy single-value terms to current primary deal titles.
const _kLegacyPrimaryMap = <String, String>{
  'Outrate': 'Outright Purchase',
  'Outright Purchase': 'Outright Purchase',
  'Joint Venture': 'Joint Venture',
  'Marketing': 'Marketing',
  'Deferred Payment': 'Deferred Payment',
  'Others': 'Others',
};

DealTypeConfig? dealConfigByTitle(String title) {
  for (final c in kDealTypeConfigs) {
    if (c.title == title) return c;
  }
  return null;
}

// ── Serialization (maps to LandLead.accessDetails) ─────────────────────────────

String serializeTermsDeal({
  required String? primaryTitle,
  required String? subtype,
  required Map<String, Map<String, String>> fieldValuesByDeal,
}) {
  if (primaryTitle == null || primaryTitle.isEmpty) return '';

  final buf = StringBuffer();
  if (subtype != null && subtype.isNotEmpty) {
    buf.writeln('$primaryTitle | $subtype');
  } else {
    buf.writeln(primaryTitle);
  }

  final config = dealConfigByTitle(primaryTitle);
  if (config != null) {
    final values = fieldValuesByDeal[config.id] ?? {};
    for (final field in config.fields) {
      final v = (values[field.id] ?? '').trim();
      if (v.isNotEmpty) {
        buf.writeln('${field.label}: $v');
      }
    }
  }

  return buf.toString().trim();
}

({String? primary, String? subtype, Map<String, Map<String, String>> fields})
    parseTermsDeal(String? raw) {
  final fieldValues = <String, Map<String, String>>{};
  for (final c in kDealTypeConfigs) {
    fieldValues[c.id] = {};
  }

  if (raw == null || raw.trim().isEmpty) {
    return (primary: null, subtype: null, fields: fieldValues);
  }

  final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
  final lineList = lines.toList();
  if (lineList.isEmpty) {
    return (primary: null, subtype: null, fields: fieldValues);
  }

  String? primary;
  String? subtype;

  final first = lineList.first;
  if (first.contains('|')) {
    final parts = first.split('|').map((s) => s.trim()).toList();
    primary = _kLegacyPrimaryMap[parts[0]] ?? parts[0];
    if (parts.length > 1) subtype = parts[1];
  } else if (first.contains(' > ')) {
    final parts = first.split(' > ').map((s) => s.trim()).toList();
    primary = _kLegacyPrimaryMap[parts[0]] ?? parts[0];
    if (parts.length > 1) subtype = parts[1];
  } else {
    primary = _kLegacyPrimaryMap[first] ?? first;
  }

  final config = dealConfigByTitle(primary);
  if (config != null) {
    final labelToId = {for (final f in config.fields) f.label: f.id};
    for (var i = 1; i < lineList.length; i++) {
      final line = lineList[i];
      final colon = line.indexOf(':');
      if (colon <= 0) continue;
      final label = line.substring(0, colon).trim();
      final value = line.substring(colon + 1).trim();
      final id = labelToId[label];
      if (id != null) {
        fieldValues[config.id]![id] = value;
      }
    }
  }

  return (primary: primary, subtype: subtype, fields: fieldValues);
}

// ── Widget ────────────────────────────────────────────────────────────────────

class TermsDealSelector extends StatefulWidget {
  /// Serialized value stored in [LandLead.accessDetails].
  final String? value;
  final ValueChanged<String?> onChanged;

  const TermsDealSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<TermsDealSelector> createState() => _TermsDealSelectorState();
}

class _TermsDealSelectorState extends State<TermsDealSelector> {
  String? _primaryTitle;
  final Map<String, String?> _subtypesByDeal = {};
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _hydrateFromValue(widget.value);
  }

  @override
  void didUpdateWidget(TermsDealSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && widget.value != _serialize()) {
      _hydrateFromValue(widget.value);
    }
  }

  void _initControllers() {
    for (final config in kDealTypeConfigs) {
      _controllers[config.id] = {
        for (final field in config.fields)
          field.id: TextEditingController(),
      };
      _subtypesByDeal[config.id] = null;
    }
  }

  void _hydrateFromValue(String? raw) {
    final parsed = parseTermsDeal(raw);
    _primaryTitle = parsed.primary;

    for (final config in kDealTypeConfigs) {
      final values = parsed.fields[config.id] ?? {};
      for (final field in config.fields) {
        _controllers[config.id]![field.id]!.text = values[field.id] ?? '';
      }
      _subtypesByDeal[config.id] = config.title == parsed.primary
          ? parsed.subtype
          : _subtypesByDeal[config.id];
    }

    if (_primaryTitle != null) {
      final idx = kDealTypeConfigs.indexWhere((c) => c.title == _primaryTitle);
      _expandedIndex = idx >= 0 ? idx : null;
    }
  }

  @override
  void dispose() {
    for (final dealCtrls in _controllers.values) {
      for (final c in dealCtrls.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  String _serialize() => serializeTermsDeal(
        primaryTitle: _primaryTitle,
        subtype: _activeSubtype,
        fieldValuesByDeal: {
          for (final config in kDealTypeConfigs)
            config.id: {
              for (final field in config.fields)
                field.id: _controllers[config.id]![field.id]!.text,
            },
        },
      );

  void _emitChange() => widget.onChanged(_serialize().isEmpty ? null : _serialize());

  DealTypeConfig? get _activeConfig =>
      _primaryTitle == null ? null : dealConfigByTitle(_primaryTitle!);

  String? get _activeSubtype {
    final config = _activeConfig;
    if (config == null) return null;
    return _subtypesByDeal[config.id];
  }

  void _toggleAccordion(DealTypeConfig config, int index) {
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null;
      } else {
        _expandedIndex = index;
        _primaryTitle = config.title;
      }
    });
    _emitChange();
  }

  void _selectSubtype(DealTypeConfig config, String subtype) {
    setState(() {
      _primaryTitle = config.title;
      _subtypesByDeal[config.id] = subtype;
      _expandedIndex = kDealTypeConfigs.indexOf(config);
    });
    _emitChange();
  }

  @override
  Widget build(BuildContext context) {
    final activeConfig = _activeConfig;
    final showFields =
        activeConfig != null && (_activeSubtype ?? '').isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Deal Type',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.fomraTextSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(kDealTypeConfigs.length, (index) {
          final config = kDealTypeConfigs[index];
          final isSelected = _primaryTitle == config.title;
          final isExpanded = _expandedIndex == index;
          final subtype = _subtypesByDeal[config.id];

          return Padding(
            padding: EdgeInsets.only(
              bottom: index < kDealTypeConfigs.length - 1 ? 10 : 0,
            ),
            child: _DealAccordionCard(
              config: config,
              isSelected: isSelected,
              isExpanded: isExpanded,
              selectedSubtype: isSelected ? subtype : null,
              onHeaderTap: () => _toggleAccordion(config, index),
              onSubtypeSelected: (s) => _selectSubtype(config, s),
            ),
          );
        }),
        AnimatedSwitcher(
          duration: _kFieldMotion,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: showFields
              ? _DealFieldsPanel(
                  key: ValueKey('${activeConfig.id}_$_activeSubtype'),
                  config: activeConfig,
                  controllers: _controllers[activeConfig.id]!,
                  onFieldChanged: _emitChange,
                )
              : const SizedBox.shrink(key: ValueKey('no_fields')),
        ),
      ],
    );
  }
}

// ── Accordion card ────────────────────────────────────────────────────────────

class _DealAccordionCard extends StatefulWidget {
  final DealTypeConfig config;
  final bool isSelected;
  final bool isExpanded;
  final String? selectedSubtype;
  final VoidCallback onHeaderTap;
  final ValueChanged<String> onSubtypeSelected;

  const _DealAccordionCard({
    required this.config,
    required this.isSelected,
    required this.isExpanded,
    required this.selectedSubtype,
    required this.onHeaderTap,
    required this.onSubtypeSelected,
  });

  @override
  State<_DealAccordionCard> createState() => _DealAccordionCardState();
}

class _DealAccordionCardState extends State<_DealAccordionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = widget.isSelected;
    final expanded = widget.isExpanded;

    final borderColor = selected
        ? AppColors.primary
        : _hovered
            ? AppColors.primary.withValues(alpha: 0.35)
            : AddLeadUi.cardBorder;

    final bg = selected
        ? AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.06)
        : _hovered
            ? (isDark ? context.fomraSurfaceVar : const Color(0xFFF8FAFC))
            : (isDark ? context.fomraSurface : Colors.white);

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onHeaderTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: _kAccordionMotion,
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(_kCardRadius),
            border: Border.all(
              color: borderColor,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: AddLeadUi.cardShadow(_hovered || selected),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onHeaderTap,
                  borderRadius: BorderRadius.vertical(
                    top: const Radius.circular(_kCardRadius),
                    bottom: Radius.circular(expanded ? 0 : _kCardRadius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: (selected
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.85))
                                .withValues(alpha: selected ? 0.15 : 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            widget.config.icon,
                            size: 22,
                            color: selected
                                ? AppColors.primary
                                : context.fomraTextSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.config.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: selected
                                      ? AppColors.primary
                                      : context.fomraTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.config.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: context.fomraTextSecondary,
                                ),
                              ),
                              if (selected &&
                                  (widget.selectedSubtype ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    widget.selectedSubtype!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: expanded ? 0.5 : 0,
                          duration: _kAccordionMotion,
                          curve: Curves.easeInOut,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: selected
                                ? AppColors.primary
                                : context.fomraTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: _kAccordionMotion,
                sizeCurve: Curves.easeInOut,
                firstCurve: Curves.easeInOut,
                secondCurve: Curves.easeInOut,
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(
                        height: 1,
                        color: AddLeadUi.cardBorder.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Select subtype',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final subtype in widget.config.subtypes)
                            _SubtypeChip(
                              label: subtype,
                              selected: selected &&
                                  widget.selectedSubtype == subtype,
                              onTap: () => widget.onSubtypeSelected(subtype),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtypeChip extends StatefulWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SubtypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SubtypeChip> createState() => _SubtypeChipState();
}

class _SubtypeChipState extends State<_SubtypeChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final bg = selected
        ? AppColors.primary.withValues(alpha: 0.12)
        : _hovered
            ? const Color(0xFFF1F5F9)
            : Colors.transparent;

    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: _kAccordionMotion,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AddLeadUi.cardBorder.withValues(
                        alpha: _hovered ? 0.9 : 0.7,
                      ),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.primary : context.fomraTextPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Dynamic fields panel ──────────────────────────────────────────────────────

class _DealFieldsPanel extends StatelessWidget {
  final DealTypeConfig config;
  final Map<String, TextEditingController> controllers;
  final VoidCallback onFieldChanged;

  const _DealFieldsPanel({
    super.key,
    required this.config,
    required this.controllers,
    required this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final fields = config.fields;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: context.fomraTextSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Deal Details',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.fomraTextSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (wide && fields.length > 1)
            ..._pairFields(context, fields)
          else
            ...fields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: AddLeadUi.fieldGap),
                child: _DealField(
                  field: field,
                  controller: controllers[field.id]!,
                  onChanged: onFieldChanged,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _pairFields(BuildContext context, List<DealFieldConfig> fields) {
    final rows = <Widget>[];
    for (var i = 0; i < fields.length; i += 2) {
      final left = fields[i];
      final right = i + 1 < fields.length ? fields[i + 1] : null;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: AddLeadUi.fieldGap),
          child: addLeadFormRow(
            context,
            _DealField(
              field: left,
              controller: controllers[left.id]!,
              onChanged: onFieldChanged,
            ),
            right != null
                ? _DealField(
                    field: right,
                    controller: controllers[right.id]!,
                    onChanged: onFieldChanged,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
    }
    return rows;
  }
}

class _DealField extends StatelessWidget {
  final DealFieldConfig field;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _DealField({
    required this.field,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: field.maxLines,
      keyboardType: field.keyboardType,
      onChanged: (_) => onChanged(),
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: context.fomraTextPrimary,
      ),
      decoration: addLeadInputDecoration(
        context,
        label: field.label,
        hint: field.hint,
        icon: field.icon,
        maxLines: field.maxLines,
      ),
    );
  }
}
