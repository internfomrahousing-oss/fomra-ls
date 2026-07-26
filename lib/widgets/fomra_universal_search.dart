import 'dart:async';

import 'package:flutter/material.dart';

import '../models/land_lead.dart';
import '../screens/home/contact_directory_screen.dart';
import '../screens/land_lead/lead_detail_screen.dart';
import '../services/app_store.dart';
import '../services/universal_search_service.dart';
import '../theme/app_theme.dart';
import '../theme/fomra_theme_context.dart';

/// App-wide search field — embedded in the blue header bar.
class FomraUniversalSearchBar extends StatefulWidget {
  /// When true the field is styled for a light card (the mobile search dialog):
  /// solid surface fill and dark text. Default false = white-on-blue header.
  final bool onSurface;

  const FomraUniversalSearchBar({super.key, this.onSurface = false});

  @override
  State<FomraUniversalSearchBar> createState() => _FomraUniversalSearchBarState();
}

class _FomraUniversalSearchBarState extends State<FomraUniversalSearchBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _layerLink = LayerLink();
  final _fieldKey = GlobalKey();
  Timer? _debounce;
  OverlayEntry? _overlayEntry;

  List<UniversalSearchHit> _results = [];
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    AppStore.instance.addListener(_refreshResults);
    UniversalSearchService.warmDocumentIndex().then((_) {
      if (mounted) _refreshResults();
    });
  }

  @override
  void dispose() {
    _hideOverlay();
    _debounce?.cancel();
    AppStore.instance.removeListener(_refreshResults);
    _focus.removeListener(_onFocusChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _focused = _focus.hasFocus);
    if (!_focus.hasFocus) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted || _focus.hasFocus) return;
        setState(() => _results = []);
        _hideOverlay();
      });
    } else {
      _runSearch(_ctrl.text);
      _showOverlay();
    }
  }

  void _refreshResults() {
    if (_ctrl.text.trim().isNotEmpty && _focused) {
      _runSearch(_ctrl.text);
      _overlayEntry?.markNeedsBuild();
    }
  }

  void _onChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _results = []);
      _hideOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _runSearch(query);
      if (_focused) _showOverlay();
    });
  }

  void _runSearch(String query) {
    if (!mounted) return;
    setState(() => _results = UniversalSearchService.search(query));
    _overlayEntry?.markNeedsBuild();
  }

  void _clear() {
    _debounce?.cancel();
    _ctrl.clear();
    setState(() => _results = []);
    _hideOverlay();
  }

  double? _fieldWidth() {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.size.width;
  }

  void _showOverlay() {
    if (!_focused || _ctrl.text.trim().isEmpty) {
      _hideOverlay();
      return;
    }
    _hideOverlay();
    _overlayEntry = OverlayEntry(builder: (ctx) => _buildOverlay(ctx));
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final width = _fieldWidth();
    if (width == null) return const SizedBox.shrink();

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              _focus.unfocus();
              _hideOverlay();
            },
            behavior: HitTestBehavior.translucent,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 40),
          child: Material(
            elevation: 8,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(12),
            color: overlayContext.fomraSurface,
            child: Container(
              width: width,
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: overlayContext.fomraBorder),
              ),
              child: _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No matches for "${_ctrl.text.trim()}".',
                        style: TextStyle(
                          fontSize: 13,
                          color: overlayContext.fomraTextSecondary,
                        ),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                      children: _buildGroupedResults(overlayContext),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openHit(UniversalSearchHit hit) async {
    _hideOverlay();
    _focus.unfocus();
    _clear();

    if (!mounted) return;

    switch (hit.kind) {
      case UniversalSearchKind.lead:
        final lead = hit.lead;
        if (lead == null) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
        );
      case UniversalSearchKind.task:
        final task = hit.task;
        if (task == null) return;
        final leadId = task.module.trim();
        if (leadId.isNotEmpty) {
          LandLead? lead;
          for (final l in AppStore.instance.leads) {
            if (l.leadId == leadId) {
              lead = l;
              break;
            }
          }
          if (lead != null) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead!)),
            );
            return;
          }
        }
        Navigator.pushNamed(context, '/task-management');
      case UniversalSearchKind.employee:
        Navigator.pushNamed(context, '/employee-management');
      case UniversalSearchKind.page:
        final route = hit.route;
        if (route != null && route.isNotEmpty) {
          Navigator.pushNamed(context, route);
        }
      case UniversalSearchKind.document:
        final doc = hit.document;
        if (doc == null) return;
        LandLead? lead;
        for (final l in AppStore.instance.leads) {
          if (l.leadId == doc.leadId) {
            lead = l;
            break;
          }
        }
        if (lead != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead!)),
          );
        }
      case UniversalSearchKind.contact:
        final kind = hit.contactKind;
        if (kind != null) {
          ContactDirectoryScreen.open(context, kind: kind);
        }
    }
  }

  IconData _iconFor(UniversalSearchKind kind) => switch (kind) {
        UniversalSearchKind.lead => Icons.person_pin_circle_outlined,
        UniversalSearchKind.task => Icons.task_alt_outlined,
        UniversalSearchKind.employee => Icons.badge_outlined,
        UniversalSearchKind.page => Icons.open_in_new_rounded,
        UniversalSearchKind.contact => Icons.contacts_outlined,
        UniversalSearchKind.document => Icons.description_outlined,
      };

  Color _accentFor(UniversalSearchKind kind) => switch (kind) {
        UniversalSearchKind.lead => AppColors.primary,
        UniversalSearchKind.task => AppColors.warning,
        UniversalSearchKind.employee => AppColors.secondary,
        UniversalSearchKind.page => AppColors.info,
        UniversalSearchKind.contact => AppColors.success,
        UniversalSearchKind.document => AppColors.primary,
      };

  String _sectionLabel(UniversalSearchKind kind) => switch (kind) {
        UniversalSearchKind.lead => 'Leads',
        UniversalSearchKind.task => 'Tasks',
        UniversalSearchKind.employee => 'Team',
        UniversalSearchKind.page => 'Pages',
        UniversalSearchKind.contact => 'Directories',
        UniversalSearchKind.document => 'Documents',
      };

  InputDecoration _headerDecoration(BuildContext context) {
    final isDark = context.isDarkMode;
    // The header field sits on the blue app bar (white-on-blue). In the mobile
    // search dialog it sits on a light card, so it needs solid-surface, dark-
    // text styling to stay readable; dark mode is already surface-styled.
    final onSurface = widget.onSurface || isDark;

    final fillColor = onSurface
        ? (isDark
            ? AppColors.darkSurfaceVar.withValues(alpha: _focused ? 0.95 : 0.75)
            : const Color(0xFFF1F5F9))
        : Colors.white.withValues(alpha: _focused ? 0.22 : 0.14);
    final hintColor = onSurface
        ? context.fomraTextSecondary
        : Colors.white.withValues(alpha: 0.65);
    final iconColor = onSurface
        ? (_focused ? AppColors.primary : context.fomraTextSecondary)
        : (_focused ? Colors.white : Colors.white.withValues(alpha: 0.75));
    final borderColor =
        onSurface ? context.fomraBorder : Colors.white.withValues(alpha: 0.28);
    final focusedColor = onSurface
        ? AppColors.primary.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.55);

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: borderColor),
    );
    return InputDecoration(
      hintText: 'Lead ID, owner, mobile, village, broker, survey, doc…',
      hintStyle: TextStyle(fontSize: 12, color: hintColor),
      prefixIcon: Icon(Icons.search_rounded, size: 18, color: iconColor),
      suffixIcon: _ctrl.text.isNotEmpty
          ? IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: iconColor),
              onPressed: _clear,
              tooltip: 'Clear',
            )
          : null,
      isDense: true,
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: focusedColor, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = widget.onSurface || context.isDarkMode;
    return CompositedTransformTarget(
      link: _layerLink,
      child: KeyedSubtree(
        key: _fieldKey,
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          style: TextStyle(
            fontSize: 12,
            color: onSurface ? context.fomraTextPrimary : Colors.white,
            fontWeight: FontWeight.w500,
          ),
          cursorColor: onSurface ? AppColors.primary : Colors.white,
          decoration: _headerDecoration(context),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedResults(BuildContext context) {
    final grouped = <UniversalSearchKind, List<UniversalSearchHit>>{};
    for (final hit in _results) {
      grouped.putIfAbsent(hit.kind, () => []).add(hit);
    }

    final widgets = <Widget>[];
    for (final kind in UniversalSearchKind.values) {
      final items = grouped[kind];
      if (items == null || items.isEmpty) continue;
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Text(
            _sectionLabel(kind),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: context.fomraTextSecondary,
            ),
          ),
        ),
      );
      for (final hit in items) {
        widgets.add(
          ListTile(
            dense: true,
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _accentFor(kind).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                _iconFor(kind),
                size: 18,
                color: _accentFor(kind),
              ),
            ),
            title: Text(
              hit.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.fomraTextPrimary,
              ),
            ),
            subtitle: hit.subtitle.isEmpty
                ? null
                : Text(
                    hit.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.fomraTextSecondary,
                    ),
                  ),
            onTap: () => _openHit(hit),
          ),
        );
      }
    }
    return widgets;
  }
}
