import 'package:flutter/material.dart';

import '../models/land_lead.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';
import 'ui/app_components.dart';

/// Compact stat pill for the workspace header.
class LandWorkspaceStatPill extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color accent;

  const LandWorkspaceStatPill({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedCounter(
                    value: value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Enhanced status KPI card with subtitle and hover.
class LandWorkspaceStatusCard extends StatefulWidget {
  final String statusName;
  final String subtitle;
  final int value;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  const LandWorkspaceStatusCard({
    super.key,
    required this.statusName,
    this.subtitle = 'Leads',
    required this.value,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  @override
  State<LandWorkspaceStatusCard> createState() =>
      _LandWorkspaceStatusCardState();
}

class _LandWorkspaceStatusCardState extends State<LandWorkspaceStatusCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        transform: _hovered
            ? Matrix4.translationValues(0, -2, 0)
            : Matrix4.identity(),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            splashColor: widget.accent.withValues(alpha: 0.08),
            child: Ink(
              width: 156,
              height: 118,
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.accent
                      .withValues(alpha: _hovered ? 0.28 : 0.14),
                ),
                boxShadow: _hovered ? context.fomraCardShadow : null,
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.fomraSurface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon, color: widget.accent, size: 18),
                  ),
                  const Spacer(),
                  AnimatedCounter(
                    value: widget.value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: widget.accent,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.statusName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                  Text(
                    widget.subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: context.fomraTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Snapshot of workspace list filters (client-side only).
class LandWorkspaceFilters {
  LeadStatus? status;
  final Set<LandType> landTypes;
  final Set<InputSource> sources;
  bool highPriority;
  String? assignedEmployee;
  DateTime? createdFrom;
  DateTime? createdTo;

  LandWorkspaceFilters({
    this.status,
    Set<LandType>? landTypes,
    Set<InputSource>? sources,
    this.highPriority = false,
    this.assignedEmployee,
    this.createdFrom,
    this.createdTo,
  })  : landTypes = landTypes ?? {},
        sources = sources ?? {};

  static const propertyTypeOptions = [
    LandType.agricultural,
    LandType.residential,
    LandType.commercial,
  ];

  static const sourceOptions = [
    InputSource.broker,
    InputSource.landowner,
    InputSource.referral,
    InputSource.internalTeam,
  ];

  static const statusOptions = [
    LeadStatus.new_,
    LeadStatus.contacted,
    LeadStatus.negotiation,
    LeadStatus.closed,
    LeadStatus.lost,
  ];

  LandWorkspaceFilters copy() => LandWorkspaceFilters(
        status: status,
        landTypes: {...landTypes},
        sources: {...sources},
        highPriority: highPriority,
        assignedEmployee: assignedEmployee,
        createdFrom: createdFrom,
        createdTo: createdTo,
      );

  void clear() {
    status = null;
    landTypes.clear();
    sources.clear();
    highPriority = false;
    assignedEmployee = null;
    createdFrom = null;
    createdTo = null;
  }

  int get activeCount {
    var n = 0;
    if (status != null) n++;
    n += landTypes.length;
    n += sources.length;
    if (highPriority) n++;
    if (assignedEmployee != null && assignedEmployee!.trim().isNotEmpty) n++;
    if (createdFrom != null || createdTo != null) n++;
    return n;
  }

  bool get hasActive => activeCount > 0;

  List<({String label, VoidCallback onRemove})> activeChips(
    VoidCallback notify,
  ) {
    final chips = <({String label, VoidCallback onRemove})>[];
    if (status != null) {
      final s = status!;
      chips.add((
        label: 'Status: ${s.label}',
        onRemove: () {
          status = null;
          notify();
        },
      ));
    }
    for (final t in [...landTypes]) {
      chips.add((
        label: 'Type: ${t.label}',
        onRemove: () {
          landTypes.remove(t);
          notify();
        },
      ));
    }
    for (final s in [...sources]) {
      chips.add((
        label: 'Source: ${s.label}',
        onRemove: () {
          sources.remove(s);
          notify();
        },
      ));
    }
    if (highPriority) {
      chips.add((
        label: 'Priority: High',
        onRemove: () {
          highPriority = false;
          notify();
        },
      ));
    }
    final emp = assignedEmployee?.trim();
    if (emp != null && emp.isNotEmpty) {
      chips.add((
        label: 'Assigned: $emp',
        onRemove: () {
          assignedEmployee = null;
          notify();
        },
      ));
    }
    if (createdFrom != null || createdTo != null) {
      String fmt(DateTime? d) =>
          d == null ? '…' : '${d.day}/${d.month}/${d.year}';
      chips.add((
        label: 'Date: ${fmt(createdFrom)} – ${fmt(createdTo)}',
        onRemove: () {
          createdFrom = null;
          createdTo = null;
          notify();
        },
      ));
    }
    return chips;
  }
}

/// Modern search bar with outlined Filter button on the far right.
class LandWorkspaceSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final int activeFilterCount;
  final VoidCallback? onFilterTap;

  const LandWorkspaceSearchBar({
    super.key,
    required this.onChanged,
    this.activeFilterCount = 0,
    this.onFilterTap,
  });

  @override
  State<LandWorkspaceSearchBar> createState() => _LandWorkspaceSearchBarState();
}

class _LandWorkspaceSearchBarState extends State<LandWorkspaceSearchBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.activeFilterCount;
    final filterLabel = count > 0 ? 'Filter ($count)' : 'Filter';

    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.curve,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: AppCard(
        padding: const EdgeInsets.all(8),
        radius: 14,
        interactive: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                style: TextStyle(color: context.fomraTextPrimary),
                decoration: InputDecoration(
                  hintText:
                      'Search by owner, survey number, location...',
                  hintStyle: TextStyle(
                    color: context.fomraTextSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 24,
                    color: _focused
                        ? AppColors.primary
                        : context.fomraTextSecondary,
                  ),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _ctrl.clear();
                            widget.onChanged('');
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: context.fomraSurfaceVar,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: _focused
                          ? AppColors.primary.withValues(alpha: 0.35)
                          : Colors.transparent,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onChanged: (v) {
                  widget.onChanged(v);
                  setState(() {});
                },
              ),
            ),
            if (widget.onFilterTap != null) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: widget.onFilterTap,
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(
                  filterLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: count > 0
                      ? AppColors.primary
                      : context.fomraTextPrimary,
                  side: BorderSide(
                    color: count > 0
                        ? AppColors.primary.withValues(alpha: 0.55)
                        : context.fomraBorder,
                    width: count > 0 ? 1.4 : 1,
                  ),
                  backgroundColor: count > 0
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : context.fomraSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact removable chips for currently applied filters only.
class LandWorkspaceActiveFilterChips extends StatelessWidget {
  final LandWorkspaceFilters filters;
  final VoidCallback onChanged;
  final VoidCallback onClearAll;

  const LandWorkspaceActiveFilterChips({
    super.key,
    required this.filters,
    required this.onChanged,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final chips = filters.activeChips(onChanged);
    if (chips.isEmpty) return const SizedBox.shrink();

    final showClearAll = chips.length > 1;

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length + (showClearAll ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (showClearAll && i == chips.length) {
            return ActionChip(
              label: const Text('Clear All'),
              avatar: const Icon(Icons.clear_all, size: 16),
              onPressed: onClearAll,
              visualDensity: VisualDensity.compact,
            );
          }
          final chip = chips[i];
          return InputChip(
            label: Text(chip.label),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.fomraTextPrimary,
            ),
            deleteIcon: const Icon(Icons.close, size: 14),
            onDeleted: chip.onRemove,
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.22),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}

/// Opens a right-side premium filter panel; returns applied filters or null.
Future<LandWorkspaceFilters?> showLandWorkspaceFilterPanel({
  required BuildContext context,
  required LandWorkspaceFilters initial,
  List<String> employeeNames = const [],
}) {
  return showGeneralDialog<LandWorkspaceFilters>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Filters',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: AppMotion.normal,
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return Align(
        alignment: Alignment.centerRight,
        child: _LandWorkspaceFilterPanel(
          initial: initial,
          employeeNames: employeeNames,
        ),
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _LandWorkspaceFilterPanel extends StatefulWidget {
  final LandWorkspaceFilters initial;
  final List<String> employeeNames;

  const _LandWorkspaceFilterPanel({
    required this.initial,
    required this.employeeNames,
  });

  @override
  State<_LandWorkspaceFilterPanel> createState() =>
      _LandWorkspaceFilterPanelState();
}

class _LandWorkspaceFilterPanelState extends State<_LandWorkspaceFilterPanel> {
  late LandWorkspaceFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial.copy();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initial = (isFrom ? _draft.createdFrom : _draft.createdTo) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _draft.createdFrom = DateTime(picked.year, picked.month, picked.day);
      } else {
        _draft.createdTo =
            DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      }
    });
  }

  String _dateLabel(DateTime? d) =>
      d == null ? 'Any' : '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final panelWidth = width < 480 ? width * 0.94 : 400.0;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Container(
            width: panelWidth,
            decoration: BoxDecoration(
              color: context.fomraSurface,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              boxShadow: AppColors.elevatedShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Sticky header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
                  decoration: BoxDecoration(
                    color: context.fomraSurface,
                    border: Border(
                      bottom: BorderSide(color: context.fomraBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.fomraTextPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(_draft.clear),
                        child: const Text('Clear All'),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      _sectionTitle('Lead Status'),
                      const SizedBox(height: 8),
                      _radioTile(
                        label: 'All Leads',
                        selected: _draft.status == null,
                        onTap: () => setState(() => _draft.status = null),
                      ),
                      ...LandWorkspaceFilters.statusOptions.map((s) {
                        return _radioTile(
                          label: s.label,
                          selected: _draft.status == s,
                          leading: CircleAvatar(
                            radius: 5,
                            backgroundColor: s.color,
                          ),
                          onTap: () => setState(() => _draft.status = s),
                        );
                      }),
                      const SizedBox(height: 8),
                      const Divider(height: 28),
                      _sectionTitle('Property Type'),
                      const SizedBox(height: 4),
                      ...LandWorkspaceFilters.propertyTypeOptions.map((t) {
                        final checked = _draft.landTypes.contains(t);
                        return _checkTile(
                          label: t.label,
                          checked: checked,
                          onChanged: (v) => setState(() {
                            if (v) {
                              _draft.landTypes.add(t);
                            } else {
                              _draft.landTypes.remove(t);
                            }
                          }),
                        );
                      }),
                      const Divider(height: 28),
                      _sectionTitle('Lead Source'),
                      const SizedBox(height: 4),
                      ...LandWorkspaceFilters.sourceOptions.map((s) {
                        final checked = _draft.sources.contains(s);
                        return _checkTile(
                          label: s.label,
                          checked: checked,
                          onChanged: (v) => setState(() {
                            if (v) {
                              _draft.sources.add(s);
                            } else {
                              _draft.sources.remove(s);
                            }
                          }),
                        );
                      }),
                      const Divider(height: 28),
                      _sectionTitle('Priority'),
                      const SizedBox(height: 4),
                      _checkTile(
                        label: 'High',
                        checked: _draft.highPriority,
                        onChanged: (v) =>
                            setState(() => _draft.highPriority = v),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, bottom: 4),
                        child: Text(
                          'New and Negotiation leads',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                      ),
                      if (widget.employeeNames.isNotEmpty) ...[
                        const Divider(height: 28),
                        _sectionTitle('Assigned Employee'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String?>(
                          key: ValueKey(_draft.assignedEmployee ?? 'all'),
                          initialValue: _draft.assignedEmployee,
                          isExpanded: true,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: context.fomraSurfaceVar,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All employees'),
                            ),
                            ...widget.employeeNames.map(
                              (n) => DropdownMenuItem<String?>(
                                value: n,
                                child: Text(n),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _draft.assignedEmployee = v),
                        ),
                      ],
                      const Divider(height: 28),
                      _sectionTitle('Created Date Range'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _dateButton(
                              label: 'From',
                              value: _dateLabel(_draft.createdFrom),
                              onTap: () => _pickDate(isFrom: true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _dateButton(
                              label: 'To',
                              value: _dateLabel(_draft.createdTo),
                              onTap: () => _pickDate(isFrom: false),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Sticky footer
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  decoration: BoxDecoration(
                    color: context.fomraSurface,
                    border: Border(
                      top: BorderSide(color: context.fomraBorder),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(_draft.clear),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Reset',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.pop(context, _draft.copy()),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        color: context.fomraTextSecondary,
      ),
    );
  }

  Widget _radioTile({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Widget? leading,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.primary : context.fomraBorder,
                  width: selected ? 6 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            if (leading != null) ...[
              leading,
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: context.fomraTextPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkTile({
    required String label,
    required bool checked,
    required ValueChanged<bool> onChanged,
  }) {
    return CheckboxListTile(
      value: checked,
      onChanged: (v) => onChanged(v ?? false),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: context.fomraTextPrimary,
        ),
      ),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _dateButton({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: context.fomraSurfaceVar,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.fomraTextSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: context.fomraTextSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Speed-dial FAB for workspace actions.
class LandWorkspaceSpeedDial extends StatefulWidget {
  final VoidCallback onAddLead;
  final VoidCallback? onImportLead;
  final VoidCallback? onScanDocument;
  final VoidCallback? onGpsCapture;

  const LandWorkspaceSpeedDial({
    super.key,
    required this.onAddLead,
    this.onImportLead,
    this.onScanDocument,
    this.onGpsCapture,
  });

  @override
  State<LandWorkspaceSpeedDial> createState() => _LandWorkspaceSpeedDialState();
}

class _LandWorkspaceSpeedDialState extends State<LandWorkspaceSpeedDial>
    with SingleTickerProviderStateMixin {
  bool _open = false;
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  );
  late final Animation<double> _scale =
      CurvedAnimation(parent: _c, curve: AppMotion.curve);

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, VoidCallback)>[
      if (widget.onImportLead != null)
        (Icons.upload_file_outlined, 'Import Lead', widget.onImportLead!),
      if (widget.onScanDocument != null)
        (Icons.document_scanner_outlined, 'Scan Document', widget.onScanDocument!),
      if (widget.onGpsCapture != null)
        (Icons.my_location_outlined, 'GPS Capture', widget.onGpsCapture!),
    ];

    // No secondary actions → the "+" goes straight to Add Lead (no menu).
    final hasMenu = actions.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < actions.length; i++)
          ScaleTransition(
            scale: _scale,
            child: FadeTransition(
              opacity: _scale,
              child: _open
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _DialAction(
                        icon: actions[i].$1,
                        label: actions[i].$2,
                        onTap: () {
                          _toggle();
                          actions[i].$3();
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppColors.coloredShadow(AppColors.primary),
          ),
          child: hasMenu
              ? FloatingActionButton(
                  onPressed: _toggle,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: AnimatedRotation(
                    turns: _open ? 0.125 : 0,
                    duration: AppMotion.normal,
                    child: Icon(_open ? Icons.close : Icons.add,
                        color: Colors.white),
                  ),
                )
              : FloatingActionButton.extended(
                  onPressed: widget.onAddLead,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add Lead',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _DialAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DialAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.fomraSurface,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.fomraTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quick action row on lead cards.
class LandWorkspaceLeadActions extends StatelessWidget {
  final LandLead lead;
  final VoidCallback? onCall;
  final VoidCallback? onMap;
  final VoidCallback? onEdit;
  final VoidCallback? onAssignTask;
  final VoidCallback? onDocuments;

  const LandWorkspaceLeadActions({
    super.key,
    required this.lead,
    this.onCall,
    this.onMap,
    this.onEdit,
    this.onAssignTask,
    this.onDocuments,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (lead.contactDetails.isNotEmpty)
          _action(context, Icons.call_outlined, 'Call', onCall),
        _action(context, Icons.map_outlined, 'View Map', onMap),
        _action(context, Icons.edit_outlined, 'Edit', onEdit),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback? onTap,
  ) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: AppColors.primary),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.primary.withValues(alpha: 0.06),
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: onTap,
    );
  }
}

/// Step progress for add-lead wizard.
class LandWorkspaceStepProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> labels;

  const LandWorkspaceStepProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: List.generate(totalSteps, (i) {
            final active = i <= currentStep;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
                child: AnimatedContainer(
                  duration: AppMotion.normal,
                  height: 4,
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : context.fomraBorder,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Step ${currentStep + 1} of $totalSteps · ${labels[currentStep]}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.fomraTextSecondary,
          ),
        ),
      ],
    );
  }
}

/// Sticky form action bar.
class LandWorkspaceFormActions extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback? onSaveDraft;
  final VoidCallback onSave;
  final bool saving;

  const LandWorkspaceFormActions({
    super.key,
    required this.onCancel,
    this.onSaveDraft,
    required this.onSave,
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: context.fomraSurface,
        border: Border(top: BorderSide(color: context.fomraBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            TextButton(onPressed: saving ? null : onCancel, child: const Text('Cancel')),
            const Spacer(),
            if (onSaveDraft != null)
              OutlinedButton(
                onPressed: saving ? null : onSaveDraft,
                child: const Text('Save Draft'),
              ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Lead'),
            ),
          ],
        ),
      ),
    );
  }
}
