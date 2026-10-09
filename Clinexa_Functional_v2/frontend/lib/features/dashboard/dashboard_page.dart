import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';

class DashboardPage extends StatefulWidget {
  final ValueChanged<String>? onNavigate;
  const DashboardPage({super.key, this.onNavigate});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic> summary = {};
  List<dynamic> queue = [];
  List<dynamic> notifications = [];
  List<dynamic> appointments = [];
  List<dynamic> patients = [];
  List<dynamic> tasks = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    // Independent panels retain their data if another panel is unavailable.
    final errors = <String>[];
    Future<void> fetch(String path, void Function(dynamic) apply) async {
      try { final r = await Api.dio.get('/api/v1/$path'); if (mounted) apply(r.data); }
      catch (e) { errors.add(Api.errorMessage(e)); }
    }
    await Future.wait([
      fetch('admin/dashboard', (d) => summary = Map<String, dynamic>.from(d)),
      fetch('appointments/queue/active', (d) => queue = List<dynamic>.from(d)),
      fetch('notifications', (d) => notifications = List<dynamic>.from(d)),
      fetch('appointments', (d) => appointments = List<dynamic>.from(d)),
      fetch('patients', (d) => patients = List<dynamic>.from(d)),
      fetch('care-tasks', (d) => tasks = List<dynamic>.from(d)),
    ]);
    if (mounted) setState(() { loading = false; error = errors.isEmpty ? null : errors.toSet().join('\n'); });
  }
  String patientName(dynamic id) {
    for (final p in patients) { if (p['id'] == id) return '${p['full_name']}'; }
    return 'Patient visit';
  }
  bool sameDay(dynamic a, DateTime date) {
    final d = DateTime.tryParse('${a['start_at']}');
    return d != null && d.year == date.year && d.month == date.month && d.day == date.day;
  }
  String time(dynamic a) {
    final d = DateTime.tryParse('${a['start_at']}');
    return d == null ? '—' : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
  Widget link(String text, String key) => TextButton(onPressed: widget.onNavigate == null ? null : () => widget.onNavigate!(key), child: Text(text));

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = appointments.where((a) => sameDay(a, now)).toList()..sort((a, b) => '${a['start_at']}'.compareTo('${b['start_at']}'));
    final activeTasks = tasks.where((t) => !['completed', 'cancelled'].contains(t['status'])).length;
    final unread = notifications.where((n) => n['is_read'] != true).length;
    final greeting = now.hour < 12 ? 'Good morning' : now.hour < 17 ? 'Good afternoon' : 'Good evening';
    final name = '${Api.currentUser?['full_name'] ?? ''}'.split(' ').first;
    final pad = MediaQuery.sizeOf(context).width < 600 ? 18.0 : 30.0;
    final flow = CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CxSectionHeader(title: 'Waiting room', subtitle: '${queue.length} active visits', action: link('Manage queue', 'appointments')),
      SizedBox(height: 16),
      if (loading) ...List.generate(3, (_) => Padding(padding: EdgeInsets.only(bottom: 12), child: CxSkeleton(height: 68))),
      if (!loading && queue.isEmpty) CxEmptyState(icon: Icons.groups_outlined, title: 'A clear waiting room', message: 'Patients appear here after check-in.'),
      if (!loading) ...queue.take(6).map((a) => Padding(padding: EdgeInsets.only(bottom: 14), child: Row(children: [
        Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: Text(patientName(a['patient_id'])[0].toUpperCase(), style: TextStyle(color: ClinexaTheme.primary, fontWeight: FontWeight.w700))),
        SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(patientName(a['patient_id']), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), SizedBox(height: 4), Text('${a['queue_token'] ?? time(a)} • ${a['reason'] ?? 'Consultation'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))])),
        SizedBox(width: 8), CxStatusChip(label: '${a['status']}'.replaceAll('_', ' '), color: a['status'] == 'in_consultation' ? ClinexaTheme.primary : ClinexaTheme.warning),
      ]))),
    ]));
    final schedule = CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CxSectionHeader(title: 'Today’s schedule', subtitle: '${today.length} scheduled visits', action: link('View all', 'appointments')),
      SizedBox(height: 16),
      if (loading) CxSkeleton(height: 160),
      if (!loading && today.isEmpty) CxEmptyState(icon: Icons.event_available_outlined, title: 'No visits today', message: 'Book an appointment from the scheduling workspace.'),
      if (!loading) ...today.take(5).map((a) => Padding(padding: EdgeInsets.only(bottom: 14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 54, child: Text(time(a), style: TextStyle(fontWeight: FontWeight.w700, color: ClinexaTheme.primary, fontSize: 13))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(patientName(a['patient_id']), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), SizedBox(height: 4), Text('${a['appointment_type']}'.replaceAll('_', ' '), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))])),
        CxStatusChip(label: '${a['status']}'.replaceAll('_', ' ')),
      ]))),
    ]));
    return RefreshIndicator(onRefresh: load, child: ListView(padding: EdgeInsets.fromLTRB(pad, 28, pad, 36), children: [
      CxSpotlightHero(
        eyebrow: 'Hospital overview • ${now.day}/${now.month}/${now.year}',
        title: '$greeting${name.isEmpty ? '' : ', $name'}.',
        subtitle: 'Your patients, care team and daily operations — together in one calm workspace.',
        icon: Icons.monitor_heart_rounded,
        stats: [
          CxHeroStat(value: loading ? '—' : '${today.length}', label: 'visits today', icon: Icons.calendar_today_outlined),
          CxHeroStat(value: loading ? '—' : '${queue.length}', label: 'waiting now', icon: Icons.groups_2_outlined),
          CxHeroStat(value: loading ? '—' : '$unread', label: 'unread', icon: Icons.notifications_none_rounded),
        ],
        actions: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: Colors.white.withValues(alpha: .22))),
            onPressed: loading ? null : load,
            icon: Icon(Icons.refresh_rounded, size: 17),
            label: Text('Refresh'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: ClinexaTheme.navy),
            onPressed: widget.onNavigate == null ? null : () => widget.onNavigate!('appointments'),
            icon: Icon(Icons.add_rounded, size: 18),
            label: Text('Schedule visit'),
          ),
        ],
      ),
      SizedBox(height: 20),
      if (error != null) ...[CxErrorBanner(message: error!, onRetry: load), SizedBox(height: 16)],
      CxAdaptiveGrid(minItemWidth: 185, children: [
        CxMetricCard(label: 'Registered patients', value: loading ? '—' : '${summary['patients'] ?? '—'}', caption: 'Across your hospital', icon: Icons.people_outline_rounded),
        CxMetricCard(label: 'Today’s visits', value: loading ? '—' : '${today.length}', caption: 'Scheduled for today', icon: Icons.calendar_today_outlined, tone: ClinexaTheme.accent),
        CxMetricCard(label: 'Active care tasks', value: loading ? '—' : '$activeTasks', caption: 'Open and in progress', icon: Icons.checklist_rounded, tone: ClinexaTheme.warning),
        CxMetricCard(label: 'Waiting room', value: loading ? '—' : '${queue.length}', caption: 'Checked in or consulting', icon: Icons.meeting_room_outlined, tone: ClinexaTheme.primary),
      ]),
      SizedBox(height: 24),
      CxAdaptiveGrid(minItemWidth: 220, children: [
        CxQuickAction(label: 'Patient directory', caption: 'Register and find patients', icon: Icons.person_add_alt_rounded, onTap: widget.onNavigate == null ? null : () => widget.onNavigate!('patients')),
        CxQuickAction(label: 'Prescription scanner', caption: 'Upload, extract and review', icon: Icons.document_scanner_outlined, onTap: widget.onNavigate == null ? null : () => widget.onNavigate!('documents')),
        CxQuickAction(label: 'Care task board', caption: 'Track the next step in care', icon: Icons.checklist_rounded, onTap: widget.onNavigate == null ? null : () => widget.onNavigate!('care_tasks')),
      ]),
      SizedBox(height: 24),
      LayoutBuilder(builder: (_, c) => c.maxWidth < 900 ? Column(children: [flow, SizedBox(height: 16), schedule]) : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 6, child: flow), SizedBox(width: 18), Expanded(flex: 5, child: schedule)])),
      SizedBox(height: 24),
      CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CxSectionHeader(title: 'Appointment activity', subtitle: 'Daily visit counts over the last seven days in the current appointment list.'),
        SizedBox(height: 20),
        if (loading) CxSkeleton(height: 110) else _ActivityStrip(appointments: appointments),
      ])),
      SizedBox(height: 18),
      CxSurface(color: Theme.of(context).colorScheme.primaryContainer, child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 14, runSpacing: 10, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your attention inbox', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), SizedBox(height: 5), Text(loading ? 'Loading notifications…' : '$unread unread notifications', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13))]),
        link('Open inbox', 'notifications'),
      ])),
    ]));
  }
}

class _ActivityStrip extends StatelessWidget {
  final List<dynamic> appointments;
  const _ActivityStrip({required this.appointments});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
    final counts = days.map((d) => appointments.where((a) { final at = DateTime.tryParse('${a['start_at']}'); return at != null && at.year == d.year && at.month == d.month && at.day == d.day; }).length).toList();
    final max = counts.fold<int>(1, (a, b) => a > b ? a : b);
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: List.generate(7, (i) => Expanded(child: Semantics(label: '${days[i].day}/${days[i].month}: ${counts[i]} appointments', child: Padding(padding: EdgeInsets.symmetric(horizontal: 5), child: Column(children: [
      Text('${counts[i]}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)), SizedBox(height: 7),
      SizedBox(height: 76, child: Align(alignment: Alignment.bottomCenter, child: Container(height: counts[i] == 0 ? 2 : 76 * counts[i] / max, decoration: BoxDecoration(color: i == 6 ? ClinexaTheme.primary : Color(0xFFC5DCC9), borderRadius: BorderRadius.circular(6))))),
      SizedBox(height: 9), Text('${days[i].day}/${days[i].month}', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
    ]))))));
  }
}
