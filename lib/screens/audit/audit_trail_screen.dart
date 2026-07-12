import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/audit_log_service.dart';
import '../../services/role_access.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/app_loader.dart';

/// Immutable audit trail — User, Timestamp, Old Value, New Value.
class AuditTrailScreen extends StatefulWidget {
  const AuditTrailScreen({super.key});

  @override
  State<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends State<AuditTrailScreen> {
  bool _loading = true;
  String? _error;
  String _query = '';
  List<AuditLogEntry> _entries = const [];

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
      final rows = await AuditLogService.getAll(limit: 400);
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

  List<AuditLogEntry> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _entries;
    return _entries.where((e) {
      return e.userName.toLowerCase().contains(q) ||
          e.action.toLowerCase().contains(q) ||
          e.entityType.toLowerCase().contains(q) ||
          e.entityId.toLowerCase().contains(q) ||
          e.field.toLowerCase().contains(q) ||
          e.oldValue.toLowerCase().contains(q) ||
          e.newValue.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pad = FomraLayout.pagePadding(context);
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
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Filter by user, field, or value',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: context.fomraSurfaceVar,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
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
          else if (_filtered.isEmpty)
            const EmptyState(
              title: 'No audit entries yet',
              message:
                  'Changes to leads and documents will appear here.',
              icon: Icons.history_edu_outlined,
            )
          else
            ..._filtered.map(_entryTile),
        ],
      ),
    );

    return FomraAppShell(
      currentRoute: '/audit-trail',
      appBar: const FomraAppBar(moduleName: 'Audit'),
      body: body,
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
            Text(
              'User: ${e.userName}',
              style: TextStyle(
                fontSize: 12,
                color: context.fomraTextSecondary,
              ),
            ),
            Text(
              'Timestamp: $stamp',
              style: TextStyle(
                fontSize: 12,
                color: context.fomraTextSecondary,
              ),
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
