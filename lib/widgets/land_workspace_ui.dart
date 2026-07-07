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

/// Modern search bar with clear button and filter badge.
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
              const SizedBox(width: 8),
              Material(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: widget.onFilterTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(11),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.tune_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        if (widget.activeFilterCount > 0)
                          Positioned(
                            right: -6,
                            top: -6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${widget.activeFilterCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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

/// Visible filter chips for land workspace.
class LandWorkspaceFilterChips extends StatelessWidget {
  final Set<LandType> landTypes;
  final bool brokerOnly;
  final bool highPriority;
  final bool completedOnly;
  final ValueChanged<LandType> onToggleLandType;
  final VoidCallback onToggleBroker;
  final VoidCallback onToggleHighPriority;
  final VoidCallback onToggleCompleted;
  final VoidCallback onClearAll;

  const LandWorkspaceFilterChips({
    super.key,
    required this.landTypes,
    required this.brokerOnly,
    required this.highPriority,
    required this.completedOnly,
    required this.onToggleLandType,
    required this.onToggleBroker,
    required this.onToggleHighPriority,
    required this.onToggleCompleted,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _chip(
        context,
        label: 'Agricultural',
        selected: landTypes.contains(LandType.agricultural),
        onTap: () => onToggleLandType(LandType.agricultural),
      ),
      _chip(
        context,
        label: 'Residential',
        selected: landTypes.contains(LandType.residential),
        onTap: () => onToggleLandType(LandType.residential),
      ),
      _chip(
        context,
        label: 'Commercial',
        selected: landTypes.contains(LandType.commercial),
        onTap: () => onToggleLandType(LandType.commercial),
      ),
      _chip(
        context,
        label: 'Broker',
        selected: brokerOnly,
        onTap: onToggleBroker,
      ),
      _chip(
        context,
        label: 'High Priority',
        selected: highPriority,
        onTap: onToggleHighPriority,
      ),
      _chip(
        context,
        label: 'Completed',
        selected: completedOnly,
        onTap: onToggleCompleted,
      ),
    ];

    final hasActive =
        landTypes.isNotEmpty || brokerOnly || highPriority || completedOnly;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length + (hasActive ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (hasActive && i == chips.length) {
            return ActionChip(
              label: const Text('Clear all'),
              avatar: const Icon(Icons.clear_all, size: 16),
              onPressed: onClearAll,
            );
          }
          return chips[i];
        },
      ),
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? AppColors.primary : context.fomraTextSecondary,
      ),
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundColor: context.fomraSurface,
      side: BorderSide(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.35)
            : context.fomraBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => onTap(),
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
          child: FloatingActionButton(
            onPressed: hasMenu ? _toggle : widget.onAddLead,
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: AnimatedRotation(
              turns: hasMenu && _open ? 0.125 : 0,
              duration: AppMotion.normal,
              child: Icon(hasMenu && _open ? Icons.close : Icons.add,
                  color: Colors.white),
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
