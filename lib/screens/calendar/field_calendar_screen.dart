import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../services/field_calendar_service.dart';
import '../../services/notification_center_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_layout.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/ui/app_feedback.dart';
import '../../widgets/fomra_app_bar.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/ui/app_components.dart';
import '../../widgets/ui/app_loader.dart';
import '../land_lead/lead_detail_screen.dart';

/// Schedule site visits, meetings, survey dates with reminders.
class FieldCalendarScreen extends StatefulWidget {
  const FieldCalendarScreen({super.key});

  @override
  State<FieldCalendarScreen> createState() => _FieldCalendarScreenState();
}

class _FieldCalendarScreenState extends State<FieldCalendarScreen> {
  List<FieldCalendarEvent> _events = [];
  List<FieldCalendarEvent> _due = [];
  bool _loading = true;
  FieldCalendarKind? _kindFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await FieldCalendarService.getAll();
    final due = await FieldCalendarService.dueReminders();
    if (!mounted) return;
    setState(() {
      _events = all;
      _due = due;
      _loading = false;
    });
  }

  LandLead? _leadOf(String id) {
    if (id.isEmpty) return null;
    try {
      return AppStore.instance.leads.firstWhere((l) => l.leadId == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _addEvent() async {
    FieldCalendarKind kind = FieldCalendarKind.siteVisit;
    LandLead? selectedLead;
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    var reminder = true;
    var remindMins = 60;
    DateTime? when;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Schedule event'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<FieldCalendarKind>(
                        initialValue: kind,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: [
                          for (final k in FieldCalendarKind.values)
                            if (k != FieldCalendarKind.survey)
                              DropdownMenuItem(
                                value: k,
                                child: Text(k.label),
                              ),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setLocal(() => kind = v);
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<LandLead?>(
                        initialValue: selectedLead,
                        decoration: const InputDecoration(labelText: 'Lead'),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('No linked lead'),
                          ),
                          ...AppStore.instance.leads.take(80).map(
                                (l) => DropdownMenuItem(
                                  value: l,
                                  child: Text(
                                    '#${l.leadId} ${l.ownerName}'.trim(),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                        ],
                        onChanged: (v) {
                          setLocal(() {
                            selectedLead = v;
                            if (titleCtrl.text.trim().isEmpty && v != null) {
                              titleCtrl.text =
                                  '${kind.label} · ${v.ownerName.isEmpty ? v.leadId : v.ownerName}';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          when == null
                              ? 'Pick date & time'
                              : DateFormat('dd MMM yyyy · hh:mm a')
                                  .format(when!),
                        ),
                        trailing: const Icon(Icons.event),
                        onTap: () async {
                          final d = await showDatePicker(
                            context: ctx,
                            initialDate:
                                DateTime.now().add(const Duration(days: 1)),
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (d == null || !ctx.mounted) return;
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: const TimeOfDay(hour: 10, minute: 0),
                          );
                          if (t == null) return;
                          setLocal(() {
                            when = DateTime(
                              d.year,
                              d.month,
                              d.day,
                              t.hour,
                              t.minute,
                            );
                          });
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Reminder'),
                        value: reminder,
                        onChanged: (v) => setLocal(() => reminder = v),
                      ),
                      if (reminder)
                        DropdownButtonFormField<int>(
                          initialValue: remindMins,
                          decoration: const InputDecoration(
                            labelText: 'Remind before',
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 15, child: Text('15 minutes')),
                            DropdownMenuItem(
                                value: 30, child: Text('30 minutes')),
                            DropdownMenuItem(
                                value: 60, child: Text('1 hour')),
                            DropdownMenuItem(
                                value: 1440, child: Text('1 day')),
                          ],
                          onChanged: (v) {
                            if (v != null) setLocal(() => remindMins = v);
                          },
                        ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Notes'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || when == null) return;
    final title = titleCtrl.text.trim().isEmpty
        ? kind.label
        : titleCtrl.text.trim();
    await FieldCalendarService.add(
      kind: kind,
      leadId: selectedLead?.leadId ?? '',
      title: title,
      scheduledAt: when!,
      notes: notesCtrl.text.trim(),
      reminderEnabled: reminder,
      remindMinutesBefore: remindMins,
    );
    await _load();
    unawaited(NotificationCenterService.syncAlerts(force: true));
    if (mounted) {
      AppFeedback.success(
        context,
        reminder
            ? 'Scheduled with reminder ($remindMins min before)'
            : 'Scheduled',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('EEE, dd MMM · hh:mm a');
    final filtered = _kindFilter == null
        ? _events
        : _events.where((e) => e.kind == _kindFilter).toList();

    return FomraAppShell(
      currentRoute: '/field-calendar',
      appBar: FomraAppBar(
        moduleName: 'Field Calendar',
        breadcrumbs: FomraBreadcrumbs.module('Field Calendar'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: FomraLayout.pagePadding(context),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Field Calendar',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: context.fomraTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Site visits · Meetings · Survey dates',
                        style: TextStyle(
                          fontSize: 13,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: _addEvent,
                  icon: const Icon(Icons.add),
                  label: const Text('Schedule'),
                ),
              ],
            ),
            if (_due.isNotEmpty) ...[
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.notifications_active,
                            color: AppColors.warning, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Reminders due',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final e in _due)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${e.kind.label}: ${e.title} · ${df.format(e.scheduledAt)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('All'),
                      selected: _kindFilter == null,
                      onSelected: (_) => setState(() => _kindFilter = null),
                    ),
                  ),
                  for (final k in FieldCalendarKind.values)
                    if (k != FieldCalendarKind.survey)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(k.label),
                          selected: _kindFilter == k,
                          onSelected: (_) => setState(() => _kindFilter = k),
                        ),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_loading)
              Padding(
                padding: const EdgeInsets.all(32),
                child: AppLoader.center(message: 'Loading calendar…'),
              )
            else if (filtered.isEmpty)
              const AppCard(
                child: EmptyState(
                  title: 'No events scheduled',
                  message:
                      'Schedule site visits, meetings, or surveys with optional reminders.',
                ),
              )
            else
              ...filtered.map((e) {
                final lead = _leadOf(e.leadId);
                final color = switch (e.kind) {
                  FieldCalendarKind.siteVisit => AppColors.info,
                  FieldCalendarKind.meeting => AppColors.primary,
                  FieldCalendarKind.survey => AppColors.warning,
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                e.kind.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (e.reminderEnabled)
                              Icon(
                                Icons.alarm,
                                size: 16,
                                color: e.isDueSoon
                                    ? AppColors.warning
                                    : context.fomraTextSecondary,
                              ),
                            if (e.completed)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.check_circle,
                                    size: 16, color: AppColors.success),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: context.fomraTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          df.format(e.scheduledAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.fomraTextSecondary,
                          ),
                        ),
                        if (e.notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(e.notes, style: const TextStyle(fontSize: 12)),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (lead != null)
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        LeadDetailScreen(lead: lead),
                                  ),
                                ),
                                child: const Text('Open lead'),
                              ),
                            if (!e.completed)
                              TextButton(
                                onPressed: () async {
                                  await FieldCalendarService.markCompleted(
                                      e.id);
                                  await _load();
                                },
                                child: const Text('Complete'),
                              ),
                            TextButton(
                              onPressed: () async {
                                await FieldCalendarService.remove(e.id);
                                await _load();
                              },
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
