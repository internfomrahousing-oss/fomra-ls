import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/audit_log_service.dart';
import '../../services/role_access.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/portal_page_layout.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/app_loader.dart';

/// Immutable audit trail — User, Timestamp, Old Value, New Value.
class AuditTrailScreen extends StatefulWidget {
  /// When opened from Settings, use sub-page chrome (back + Settings crumbs).
  final bool asSettingsChild;

  const AuditTrailScreen({super.key, this.asSettingsChild = false});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  bool _loading = true;
  String? _error;
  List<AuditLogEntry> _entries = const [];

  final _searchController = TextEditingController();
  String _query = '';
  DateTimeRange? _dateRange;
  String? _user;
  String? _module;
  String? _action;
  final GlobalKey _dateChipKey = GlobalKey();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!RoleAccess.canViewAudit) {
      setState(() {
        _loading = false;
        _error = RoleAccess.deniedMessage('view the audit trail');
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await AuditLogService.getAll(limit: 1000);
      if (!mounted) return;
      setState(() {
        _entries = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _dateRange != null ||
      _user != null ||
      _module != null ||
      _action != null;

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _dateRange = null;
      _user = null;
      _module = null;
      _action = null;
    });
  }

  List<String> _distinct(String Function(AuditLogEntry e) pick) {
    final values = _entries.map(pick).where((v) => v.trim().isNotEmpty).toSet().toList()
      ..sort();
    return values;
  }

  List<AuditLogEntry> get _filtered {
    final q = _query.trim().toLowerCase();
    return _entries.where((e) {
      if (_dateRange != null) {
        final t = e.timestamp.toLocal();
        final start = _dateRange!.start;
        final end = _dateRange!.end.add(const Duration(
            hours: 23, minutes: 59, seconds: 59));
        if (t.isBefore(start) || t.isAfter(end)) return false;
      }
      if (_user != null && e.userName != _user) return false;
      if (_module != null && e.module != _module) return false;
      if (_action != null && e.action != _action) return false;
      if (q.isNotEmpty) {
        final haystack = [
          e.userName,
          e.action,
          e.entityType,
          e.entityId,
          e.field,
          e.oldValue,
          e.newValue,
          e.module,
          e.leadId,
          e.ownerName,
          e.brokerName,
          e.executiveName,
        ].join(' ').toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickDateRange() async {
    final box = _dateChipKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    RelativeRect position;
    if (box != null && overlay != null) {
      final topLeft = box.localToGlobal(Offset(0, box.size.height + 4), ancestor: overlay);
      final bottomRight = box.localToGlobal(
          box.size.bottomRight(Offset.zero) + Offset(0, box.size.height + 4),
          ancestor: overlay);
      position = RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlay.size,
      );
    } else {
      position = const RelativeRect.fromLTRB(24, 100, 24, 0);
    }

    final result = await showMenu<_DateRangePickResult>(
      context: context,
      position: position,
      constraints: const BoxConstraints(maxWidth: 320),
      items: [
        PopupMenuItem<_DateRangePickResult>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: _CompactDateRangePopup(initialRange: _dateRange),
        ),
      ],
    );
    if (result == null) return;
    setState(() => _dateRange = result.cleared ? null : result.range);
  }

  @override
  Widget build(BuildContext context) {
    final pad = FomraLayout.pagePadding(context);
    final filtered = _filtered;
    final body = RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: pad,
        children: [
          Text(
            'Audit Trail',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Immutable change log: user, timestamp, old value, and new value. Entries cannot be edited or deleted from the app.',
            style: TextStyle(fontSize: 13, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search by keyword — user, field, value, lead…',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: context.fomraSurfaceVar,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _dateRangeChip(context),
              _filterDropdown(
                label: 'User',
                value: _user,
                options: _distinct((e) => e.userName),
                onChanged: (v) => setState(() => _user = v),
              ),
              _filterDropdown(
                label: 'Module',
                value: _module,
                options: _distinct((e) => e.module),
                onChanged: (v) => setState(() => _module = v),
              ),
              _filterDropdown(
                label: 'Action Type',
                value: _action,
                options: _distinct((e) => e.action),
                onChanged: (v) => setState(() => _action = v),
              ),
              if (_hasActiveFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                  label: const Text('Clear filters'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${filtered.length} of ${_entries.length} entries',
            style: TextStyle(fontSize: 12, color: context.fomraTextSecondary),
          ),
          const SizedBox(height: 12),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: AppLoader.center(message: 'Loading audit trail…'),
            )
          else if (_error != null)
            EmptyState(
              title: 'Could not load audit trail',
              message: _error,
              icon: Icons.error_outline_rounded,
            )
          else if (filtered.isEmpty)
            EmptyState(
              title: _hasActiveFilters
                  ? 'No entries match these filters'
                  : 'No audit entries yet',
              message: _hasActiveFilters
                  ? 'Try widening the date range or clearing a filter.'
                  : 'Changes to leads and documents will appear here.',
              icon: Icons.history_edu_outlined,
            )
          else
            ...filtered.map(_entryTile),
        ],
      ),
    );

    return FomraAppShell(
      currentRoute: widget.asSettingsChild ? '/settings' : '/audit-trail',
      appBar: widget.asSettingsChild
          ? FomraSubPageAppBar(
              title: 'Audit Trail',
              breadcrumbs: FomraBreadcrumbs.forSettingsChild('Audit Trail'),
            )
          : const FomraAppBar(moduleName: 'Audit'),
      body: body,
    );
  }

  Widget _dateRangeChip(BuildContext context) {
    final label = _dateRange == null
        ? 'Date Range'
        : '${DateFormat('d MMM').format(_dateRange!.start)} – ${DateFormat('d MMM yyyy').format(_dateRange!.end)}';
    return InputChip(
      key: _dateChipKey,
      avatar: const Icon(Icons.date_range_outlined, size: 16),
      label: Text(label),
      onPressed: _pickDateRange,
      onDeleted: _dateRange == null
          ? null
          : () => setState(() => _dateRange = null),
    );
  }

  Widget _filterDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 160,
      child: DropdownButtonFormField<String>(
        key: ValueKey('audit-filter-$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          filled: true,
          fillColor: context.fomraSurfaceVar,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        items: [
          DropdownMenuItem(value: null, child: Text('All $label')),
          for (final o in options)
            DropdownMenuItem(
              value: o,
              child: Text(o, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _entryTile(AuditLogEntry e) {
    final stamp =
        DateFormat('dd MMM yyyy, h:mm:ss a').format(e.timestamp.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    e.action.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${e.entityType} · ${e.entityId}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.fomraTextPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _metaText('User', e.userName),
                _metaText('Timestamp', stamp),
                if (e.module.isNotEmpty) _metaText('Module', e.module),
                if (e.leadId.isNotEmpty) _metaText('Lead', e.leadId),
                if (e.ownerName.isNotEmpty) _metaText('Owner', e.ownerName),
                if (e.brokerName.isNotEmpty) _metaText('Broker', e.brokerName),
                if (e.executiveName.isNotEmpty)
                  _metaText('Executive', e.executiveName),
              ],
            ),
            if (e.field.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Field: ${e.field}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.fomraTextPrimary,
                ),
              ),
            ],
            const SizedBox(height: 8),
            _valueRow('Old', e.oldValue.isEmpty ? '—' : e.oldValue),
            const SizedBox(height: 4),
            _valueRow('New', e.newValue.isEmpty ? '—' : e.newValue),
          ],
        ),
      ),
    );
  }

  Widget _metaText(String label, String value) => Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: context.fomraTextSecondary,
        ),
      );

  Widget _valueRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.fomraTextSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: context.fomraTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateRangePickResult {
  final DateTimeRange? range;
  final bool cleared;
  const _DateRangePickResult({this.range, this.cleared = false});
}

/// Small popup calendar (opens beside the date field) supporting both a
/// single-date pick and a start/end date range pick, without the full-screen
/// date range dialog.
class _CompactDateRangePopup extends StatefulWidget {
  final DateTimeRange? initialRange;

  const _CompactDateRangePopup({this.initialRange});

  @override
  State<_CompactDateRangePopup> createState() =>
      _CompactDateRangePopupState();
}

class _CompactDateRangePopupState extends State<_CompactDateRangePopup> {
  late DateTime? _start = widget.initialRange?.start;
  late DateTime? _end = widget.initialRange?.end;
  bool _pickingEnd = false;

  String _fmt(DateTime? d) => d == null ? 'Any' : DateFormat('d MMM yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final target = _pickingEnd ? (_end ?? _start ?? now) : (_start ?? now);
    final isDark = context.isDarkMode;
    // Force the calendar's day/weekday/year text to the app's foreground colors
    // so the picker follows dark mode (showMenu can otherwise render it light).
    final calendarTheme = Theme.of(context).copyWith(
      colorScheme: Theme.of(context).colorScheme.copyWith(
            surface: context.fomraSurface,
            onSurface: context.fomraTextPrimary,
            brightness: isDark ? Brightness.dark : Brightness.light,
          ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: context.fomraSurface,
        dayForegroundColor:
            WidgetStatePropertyAll(context.fomraTextPrimary),
        yearForegroundColor:
            WidgetStatePropertyAll(context.fomraTextPrimary),
        weekdayStyle: TextStyle(color: context.fomraTextSecondary),
      ),
    );
    return Material(
      color: context.fomraSurface,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _rangeTargetChip(
                      context: context,
                      label: 'Start: ${_fmt(_start)}',
                      selected: !_pickingEnd,
                      onTap: () => setState(() => _pickingEnd = false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _rangeTargetChip(
                      context: context,
                      label: 'End: ${_fmt(_end)}',
                      selected: _pickingEnd,
                      onTap: () => setState(() => _pickingEnd = true),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 320,
              child: Theme(
                data: calendarTheme,
                child: CalendarDatePicker(
                initialDate: target,
                firstDate: DateTime(now.year - 3),
                lastDate: DateTime(now.year + 1),
                onDateChanged: (picked) {
                  setState(() {
                    if (_pickingEnd) {
                      _end = picked;
                      if (_start != null && _end!.isBefore(_start!)) {
                        _start = _end;
                      }
                    } else {
                      _start = picked;
                      if (_end != null && _end!.isBefore(_start!)) {
                        _end = _start;
                      }
                    }
                  });
                },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(
                        context, const _DateRangePickResult(cleared: true)),
                    child: const Text('Clear'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _start == null
                        ? null
                        : () => Navigator.pop(
                              context,
                              _DateRangePickResult(
                                range: DateTimeRange(
                                  start: _start!,
                                  end: _end ?? _start!,
                                ),
                              ),
                            ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeTargetChip({
    required BuildContext context,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.4)
                : context.fomraBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.primary : context.fomraTextSecondary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
