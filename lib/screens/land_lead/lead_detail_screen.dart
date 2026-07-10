import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/add_lead_result.dart';
import '../../models/land_lead.dart';
import '../../services/app_store.dart';
import '../../services/land_lead_service.dart';
import '../../models/lead_list_filter.dart';
import '../../theme/app_theme.dart';
import '../../theme/fomra_theme_context.dart';
import '../../widgets/fomra_app_shell.dart';
import '../../widgets/fomra_breadcrumb.dart';
import '../../widgets/ui/app_components.dart';
import 'add_lead_screen.dart';
import 'filtered_leads_screen.dart';

int _leadAgeDaysFromReceived(DateTime receivedOn) {
  final received = receivedOn.toLocal();
  final now = DateTime.now();
  final receivedDay = DateTime(received.year, received.month, received.day);
  final today = DateTime(now.year, now.month, now.day);
  return today.difference(receivedDay).inDays;
}

String _formatReceivedOn(DateTime receivedOn) {
  final local = receivedOn.toLocal();
  return '${local.day}/${local.month}/${local.year} '
      '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
}

class LeadDetailScreen extends StatefulWidget {
  final LandLead lead;

  const LeadDetailScreen({super.key, required this.lead});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen>
    with SingleTickerProviderStateMixin {
  late LandLead lead = widget.lead;
  late final TabController _tabController;
  final _noteCtrl = TextEditingController();
  bool _savingNote = false;

  static const _tabs = [
    'Activity',
    'Notes',
    'Details',
    'Site Photos',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String get _displayName => lead.ownerName.trim().isEmpty
      ? 'Lead #${lead.leadId}'
      : lead.ownerName.trim();

  String get _initials {
    final parts = _displayName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final list = parts.take(2).toList();
    if (list.isEmpty) return '#';
    return list.map((p) => p[0]).join().toUpperCase();
  }

  int get _leadAgeDays => _leadAgeDaysFromReceived(lead.addedOn);

  int get _statusScore => switch (lead.status) {
        LeadStatus.prospectMeetingPending => 16,
        LeadStatus.prospectMeetingCompleted => 32,
        LeadStatus.negotiation => 48,
        LeadStatus.legal => 64,
        LeadStatus.signed => 100,
        LeadStatus.dropped => 12,
      };

  int get _siteVisitCount => lead.status ==
          LeadStatus.prospectMeetingCompleted ||
      lead.status == LeadStatus.negotiation ||
      lead.status == LeadStatus.legal ||
      lead.status == LeadStatus.signed
      ? 1
      : 0;

  int get _contactAttempts =>
      lead.status == LeadStatus.prospectMeetingPending ? 0 : 1;

  Future<void> _openEdit() async {
    final result = await Navigator.push<AddLeadResult>(
      context,
      MaterialPageRoute(builder: (_) => AddLeadScreen(existingLead: lead)),
    );
    if (result == null || !mounted) return;

    try {
      final saved = await LandLeadService.update(
        result.lead,
        sitePhotoBytes: result.sitePhotoBytes,
      );
      AppStore.instance.replaceLead(saved);
      setState(() => lead = saved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lead updated')),
        );
      }
    } catch (e) {
      AppStore.instance.replaceLead(result.lead);
      setState(() => lead = result.lead);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved locally; sync failed: $e')),
        );
      }
    }
  }

  Future<void> _changeStatus(LeadStatus? status) async {
    if (status == null || status == lead.status) return;
    final previous = lead.status;
    setState(() => lead.status = status);
    AppStore.instance.replaceLead(lead);
    try {
      await LandLeadService.updateStatus(lead.leadId, status);
    } catch (_) {
      setState(() => lead.status = previous);
      AppStore.instance.replaceLead(lead);
    }
  }

  Future<void> _saveNote() async {
    final text = _noteCtrl.text.trim();
    if (text.isEmpty || _savingNote) return;
    setState(() => _savingNote = true);
    final stamp = DateTime.now().toLocal();
    final entry =
        '[${stamp.day}/${stamp.month}/${stamp.year} ${stamp.hour}:${stamp.minute.toString().padLeft(2, '0')}] $text';
    final merged = lead.notes.trim().isEmpty
        ? entry
        : '${lead.notes.trim()}\n$entry';
    final updated = lead.copyWith(notes: merged);
    try {
      final saved = await LandLeadService.update(updated);
      AppStore.instance.replaceLead(saved);
      if (mounted) {
        setState(() {
          lead = saved;
          _noteCtrl.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved')),
        );
      }
    } catch (_) {
      AppStore.instance.replaceLead(updated);
      if (mounted) {
        setState(() {
          lead = updated;
          _noteCtrl.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  Future<void> _launchContact(String scheme) async {
    final raw = lead.contactDetails.replaceAll(RegExp(r'[^\d+]'), '');
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contact number on this lead')),
      );
      return;
    }
    final Uri uri;
    if (scheme.startsWith('https://wa.me')) {
      uri = Uri.parse('https://wa.me/$raw');
    } else {
      uri = Uri.parse('$scheme:$raw');
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open contact action')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FomraAppShell(
      currentRoute: '/land-lead',
      backgroundColor: const Color(0xFFF3F4F8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(
                  leadId: lead.leadId,
                  onBack: () => Navigator.pop(context),
                  onEdit: _openEdit,
                ),
                FomraBreadcrumbStrip(
                  items: FomraBreadcrumbs.fromWorkspace('Lead ${lead.leadId}'),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 1,
                                child: _ProfilePanel(
                                  lead: lead,
                                  displayName: _displayName,
                                  initials: _initials,
                                  leadAgeDays: _leadAgeDays,
                                  statusScore: _statusScore,
                                  onStatusChanged: _changeStatus,
                                  onLaunchContact: _launchContact,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: _WorkspacePanel(
                                  lead: lead,
                                  tabController: _tabController,
                                  tabs: _tabs,
                                  noteCtrl: _noteCtrl,
                                  savingNote: _savingNote,
                                  siteVisitCount: _siteVisitCount,
                                  contactAttempts: _contactAttempts,
                                  onSaveNote: _saveNote,
                                  onLaunchContact: _launchContact,
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            children: [
                              _ProfilePanel(
                                lead: lead,
                                displayName: _displayName,
                                initials: _initials,
                                leadAgeDays: _leadAgeDays,
                                statusScore: _statusScore,
                                onStatusChanged: _changeStatus,
                                onLaunchContact: _launchContact,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: constraints.maxHeight * 0.72,
                                child: _WorkspacePanel(
                                  lead: lead,
                                  tabController: _tabController,
                                  tabs: _tabs,
                                  noteCtrl: _noteCtrl,
                                  savingNote: _savingNote,
                                  siteVisitCount: _siteVisitCount,
                                  contactAttempts: _contactAttempts,
                                  onSaveNote: _saveNote,
                                  onLaunchContact: _launchContact,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String leadId;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  const _TopBar({
    required this.leadId,
    required this.onBack,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: context.fomraSurface,
        border: Border(bottom: BorderSide(color: context.fomraBorder)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Text(
            'Lead #$leadId',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.fomraTextPrimary,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Edit lead'),
          ),
        ],
      ),
    );
  }
}

class _ProfilePanel extends StatelessWidget {
  final LandLead lead;
  final String displayName;
  final String initials;
  final int leadAgeDays;
  final int statusScore;
  final ValueChanged<LeadStatus?> onStatusChanged;
  final Future<void> Function(String scheme) onLaunchContact;

  const _ProfilePanel({
    required this.lead,
    required this.displayName,
    required this.initials,
    required this.leadAgeDays,
    required this.statusScore,
    required this.onStatusChanged,
    required this.onLaunchContact,
  });

  @override
  Widget build(BuildContext context) {
    final locationLabel = [
      if (lead.village.isNotEmpty) lead.village,
      if (lead.district.isNotEmpty) lead.district,
    ].join(', ');

    return AppCard(
      interactive: false,
      padding: const EdgeInsets.all(18),
      radius: 16,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#${lead.leadId}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: context.fomraTextPrimary,
                              ),
                            ),
                          ),
                          Icon(Icons.edit_outlined,
                              size: 16, color: context.fomraTextSecondary),
                        ],
                      ),
                      if (locationLabel.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text('🇮🇳', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                locationLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.fomraTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (lead.contactDetails.isNotEmpty)
                  IconButton(
                    tooltip: 'WhatsApp',
                    onPressed: () => onLaunchContact('https://wa.me'),
                    icon: const Icon(Icons.chat_rounded,
                        color: Color(0xFF25D366)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricPill(
                  label: lead.landExtent.isEmpty ? '—' : lead.landExtent,
                  caption: 'Area',
                ),
                _MetricPill(
                  label: lead.surveyNumber.isEmpty ? '—' : lead.surveyNumber,
                  caption: 'Survey',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AvatarRing(initials: initials, score: statusScore),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stage & Status',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: lead.status.color.withValues(alpha: 0.45),
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<LeadStatus>(
                            value: lead.status,
                            isExpanded: true,
                            items: leadStatusPipelineOrder
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 5,
                                          backgroundColor: s.color,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(s.label),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: onStatusChanged,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _InfoLine(
                        label: 'Input Source',
                        value: lead.inputSource.label,
                      ),
                      _InfoLine(
                        label: 'Land Type',
                        value: lead.landType.label,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              'Last Note',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.fomraTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              lead.notes.trim().isEmpty
                  ? 'No notes yet'
                  : lead.notes.trim().split('\n').last,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.fomraTextPrimary,
              ),
            ),
            const SizedBox(height: 14),
            _MetaGrid(lead: lead, leadAgeDays: leadAgeDays),
            if (lead.contactDetails.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => onLaunchContact('tel'),
                child: const Text('View contact details'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkspacePanel extends StatelessWidget {
  final LandLead lead;
  final TabController tabController;
  final List<String> tabs;
  final TextEditingController noteCtrl;
  final bool savingNote;
  final int siteVisitCount;
  final int contactAttempts;
  final VoidCallback onSaveNote;
  final Future<void> Function(String scheme) onLaunchContact;

  const _WorkspacePanel({
    required this.lead,
    required this.tabController,
    required this.tabs,
    required this.noteCtrl,
    required this.savingNote,
    required this.siteVisitCount,
    required this.contactAttempts,
    required this.onSaveNote,
    required this.onLaunchContact,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      interactive: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActionToolbar(
            onActionTap: (filter) => FilteredLeadsScreen.open(context, filter),
          ),
          const SizedBox(height: 12),
          _NoteComposer(
            controller: noteCtrl,
            saving: savingNote,
            onSave: onSaveNote,
          ),
          const SizedBox(height: 14),
          _ActivitySummaryRow(
            siteVisitCount: siteVisitCount,
            contactAttempts: contactAttempts,
            status: lead.status,
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: AppColors.purple,
            unselectedLabelColor: context.fomraTextSecondary,
            indicatorColor: AppColors.purple,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
            tabs: [for (final t in tabs) Tab(text: t)],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                _ActivityTimeline(lead: lead),
                _NotesTab(lead: lead),
                _DetailsTab(lead: lead),
                _SitePhotosTab(lead: lead),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionToolbar extends StatelessWidget {
  final ValueChanged<LeadListFilter> onActionTap;

  const _ActionToolbar({required this.onActionTap});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.sticky_note_2_outlined, 'Notes'),
      (Icons.call_outlined, 'Calls'),
      (Icons.location_on_outlined, 'Site visit'),
      (Icons.apartment_outlined, 'Management site visit'),
      (Icons.groups_outlined, 'Meeting'),
      (Icons.gavel_outlined, 'Legal'),
      (Icons.draw_outlined, 'Signed'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final action in actions)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: InkWell(
                onTap: () {
                  final filter = LeadListFilterX.forActionLabel(action.$2);
                  if (filter != null) {
                    onActionTap(filter);
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: Column(
                    children: [
                      Icon(action.$1, size: 20, color: AppColors.purple),
                      const SizedBox(height: 4),
                      Text(
                        action.$2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.fomraTextSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoteComposer extends StatelessWidget {
  final TextEditingController controller;
  final bool saving;
  final VoidCallback onSave;

  const _NoteComposer({
    required this.controller,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.fomraSurfaceVar.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.fomraBorder),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'Add a note about this lead…',
              border: InputBorder.none,
              counterText: '',
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                'Maximum 2000 characters are allowed',
                style: TextStyle(
                  fontSize: 11,
                  color: context.fomraTextSecondary,
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Note'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivitySummaryRow extends StatelessWidget {
  final int siteVisitCount;
  final int contactAttempts;
  final LeadStatus status;

  const _ActivitySummaryRow({
    required this.siteVisitCount,
    required this.contactAttempts,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final cells = [
      ('Conducted\nSite Visits', '$siteVisitCount'),
      ('Outgoing\nNot Answered',
          '${status == LeadStatus.prospectMeetingPending ? 1 : 0}'),
      ('Outgoing\nAnswered', '$contactAttempts'),
      ('Incoming\nNot Answered', '0'),
      ('Incoming\nAnswered', '0'),
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.fomraBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 54, color: context.fomraBorder),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                child: Column(
                  children: [
                    Text(
                      cells[i].$1,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.2,
                        color: context.fomraTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cells[i].$2,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.fomraTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityTimeline extends StatelessWidget {
  final LandLead lead;
  const _ActivityTimeline({required this.lead});

  @override
  Widget build(BuildContext context) {
    final events = <({String title, String subtitle, IconData icon})>[
      (
        title: 'Lead created',
        subtitle: _formatReceivedOn(lead.addedOn),
        icon: Icons.add_circle_outline,
      ),
      (
        title: 'Current stage',
        subtitle: lead.status.label,
        icon: Icons.flag_outlined,
      ),
      if (lead.createdByName.isNotEmpty)
        (
          title: lead.ownershipLabel,
          subtitle: lead.createdByName,
          icon: Icons.person_outline,
        ),
      if (lead.notes.trim().isNotEmpty)
        (
          title: 'Latest note',
          subtitle: lead.notes.trim().split('\n').last,
          icon: Icons.sticky_note_2_outlined,
        ),
    ];

    return ListView(
      children: [
        Text(
          'History',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: context.fomraTextPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(e.icon, size: 18, color: AppColors.purple),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        e.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.fomraTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NotesTab extends StatelessWidget {
  final LandLead lead;
  const _NotesTab({required this.lead});

  @override
  Widget build(BuildContext context) {
    if (lead.notes.trim().isEmpty) {
      return Center(
        child: Text(
          'No notes yet',
          style: TextStyle(color: context.fomraTextSecondary),
        ),
      );
    }
    final lines = lead.notes.trim().split('\n').reversed.toList();
    return ListView.separated(
      itemCount: lines.length,
      separatorBuilder: (_, __) => const Divider(height: 16),
      itemBuilder: (_, i) => Text(lines[i]),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final LandLead lead;
  const _DetailsTab({required this.lead});

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Owner', lead.ownerName),
      if (lead.contactDetails.isNotEmpty) ('Contact', lead.contactDetails),
      ('Input Source', lead.inputSource.label),
      ('Land Type', lead.landType.label),
      ('Status', lead.status.label),
      ('Location', lead.location),
      if (lead.village.isNotEmpty) ('Village', lead.village),
      if (lead.taluk.isNotEmpty) ('Taluk', lead.taluk),
      if (lead.district.isNotEmpty) ('District', lead.district),
      if (lead.pincode.isNotEmpty) ('Pincode', lead.pincode),
      if (lead.gpsCoordinates.isNotEmpty) ('GPS', lead.gpsCoordinates),
      if (lead.surveyNumber.isNotEmpty) ('Survey No.', lead.surveyNumber),
      if (lead.subDivision.isNotEmpty) ('Sub Division', lead.subDivision),
      if (lead.landExtent.isNotEmpty) ('Land Extent', lead.landExtent),
      if (lead.roadWidth.isNotEmpty) ('Road Width', lead.roadWidth),
      if (lead.accessDetails.isNotEmpty) ('Terms', lead.accessDetails),
      if (lead.createdByName.isNotEmpty)
        (lead.ownershipLabel, lead.createdByName),
    ];

    return ListView(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    row.$1,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.fomraTextSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.$2,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.fomraTextPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SitePhotosTab extends StatelessWidget {
  final LandLead lead;
  const _SitePhotosTab({required this.lead});

  @override
  Widget build(BuildContext context) {
    final urls = _sitePhotoUrls(lead);
    if (urls.isEmpty) {
      return Center(
        child: Text(
          'No site photos uploaded',
          style: TextStyle(color: context.fomraTextSecondary),
        ),
      );
    }
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: urls.length,
      itemBuilder: (_, i) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(urls[i], fit: BoxFit.cover),
      ),
    );
  }
}

class _MetaGrid extends StatelessWidget {
  final LandLead lead;
  final int leadAgeDays;

  const _MetaGrid({required this.lead, required this.leadAgeDays});

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      (
        'Received On',
        _formatReceivedOn(lead.addedOn),
      ),
      ('Lead Age', '$leadAgeDays days'),
      ('Tags', '${lead.landType.label}, ${lead.inputSource.label}'),
      ('Lead Owner', lead.createdByName.isEmpty ? '—' : lead.createdByName),
      (
        'Project Interest',
        lead.village.isEmpty ? lead.location : lead.village,
      ),
      ('Contact Details', lead.contactDetails.isEmpty ? '—' : 'Available'),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _MetaCell(label: items[i].$1, value: items[i].$2)),
                const SizedBox(width: 12),
                if (i + 1 < items.length)
                  Expanded(
                    child: _MetaCell(
                      label: items[i + 1].$1,
                      value: items[i + 1].$2,
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetaCell extends StatelessWidget {
  final String label;
  final String value;

  const _MetaCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: context.fomraTextSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: context.fomraTextPrimary,
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String caption;

  const _MetricPill({required this.label, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: context.fomraBorder),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          Text(caption,
              style: TextStyle(fontSize: 10, color: context.fomraTextSecondary)),
        ],
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  final String initials;
  final int score;

  const _AvatarRing({required this.initials, required this.score});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: score / 100,
            strokeWidth: 4,
            color: AppColors.purple,
            backgroundColor: AppColors.purple.withValues(alpha: 0.12),
          ),
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.purple.withValues(alpha: 0.12),
            child: Text(
              initials,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.purple,
              ),
            ),
          ),
          Positioned(
            right: 2,
            bottom: 2,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.purple,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$score',
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
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, color: context.fomraTextSecondary),
      ),
    );
  }
}

List<String> _sitePhotoUrls(LandLead lead) {
  if (lead.sitePhotoUrls.isNotEmpty) return lead.sitePhotoUrls;
  if (lead.sitePhotoUrl.isNotEmpty) return [lead.sitePhotoUrl];
  return const [];
}
