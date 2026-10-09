import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';

class AppointmentsPage extends StatefulWidget {
  AppointmentsPage({super.key});
  @override
  State<AppointmentsPage> createState() => _AppointmentsPageState();
}

class _AppointmentsPageState extends State<AppointmentsPage> {
  List<dynamic> appointments = [];
  List<dynamic> patients = [];
  List<dynamic> doctors = [];
  String? error;
  bool loading = true;
  String filter = 'all';
  String query = '';
  String dateFilter = 'all';
  bool booking = false;
  final Set<String> updating = {};

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final r = await Future.wait([
        Api.dio.get('/api/v1/appointments'),
        Api.dio.get('/api/v1/patients'),
        Api.dio.get('/api/v1/doctors'),
      ]);
      if (mounted) setState(() {
        appointments = List<dynamic>.from(r[0].data as List);
        patients = List<dynamic>.from(r[1].data as List);
        doctors = List<dynamic>.from(r[2].data as List);
      });
    } catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<DateTime?> pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(DateTime.now()) ? DateTime.now() : initial,
      firstDate: DateTime.now().subtract(Duration(days: 1)),
      lastDate: DateTime.now().add(Duration(days: 730)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> book() async {
    if (patients.isEmpty || doctors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add at least one patient and doctor first.')));
      return;
    }
    String patientId = patients.first['id'].toString();
    String doctorId = doctors.first['id'].toString();
    String type = 'in_person';
    DateTime start = DateTime.now().add(Duration(days: 1));
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(children: [Icon(Icons.calendar_month_rounded, color: ClinexaTheme.primary), SizedBox(width: 9), Text('Book appointment')]),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(isExpanded: true, initialValue: patientId, decoration: InputDecoration(labelText: 'Patient', prefixIcon: Icon(Icons.person_outline_rounded)), items: patients.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text(x['full_name'].toString()))).toList(), onChanged: (v) => setLocal(() => patientId = v ?? patientId)),
                SizedBox(height: 11),
                DropdownButtonFormField<String>(isExpanded: true, initialValue: doctorId, decoration: InputDecoration(labelText: 'Doctor', prefixIcon: Icon(Icons.medical_services_outlined)), items: doctors.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text('${x['full_name']} • ${x['specialty']}'))).toList(), onChanged: (v) => setLocal(() => doctorId = v ?? doctorId)),
                SizedBox(height: 11),
                DropdownButtonFormField<String>(isExpanded: true, initialValue: type, decoration: InputDecoration(labelText: 'Appointment type', prefixIcon: Icon(Icons.meeting_room_outlined)), items: [
                  DropdownMenuItem(value: 'in_person', child: Text('In-person')),
                  DropdownMenuItem(value: 'teleconsultation', child: Text('Teleconsultation')),
                  DropdownMenuItem(value: 'follow_up', child: Text('Follow-up')),
                ], onChanged: (v) => setLocal(() => type = v ?? type)),
                SizedBox(height: 11),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async { final x = await pickDateTime(start); if (x != null) setLocal(() => start = x); },
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
                    child: Row(children: [Icon(Icons.schedule_rounded, color: ClinexaTheme.primary), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Date & time', style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700)), Text(_formatDate(start), style: TextStyle(fontWeight: FontWeight.w800))])), Icon(Icons.edit_calendar_outlined, size: 18)]),
                  ),
                ),
                SizedBox(height: 11),
                TextField(controller: reason, maxLines: 3, decoration: InputDecoration(labelText: 'Reason / context')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
            FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: Icon(Icons.check_rounded), label: Text('Create appointment')),
          ],
        ),
      ),
    );
    final reasonText = reason.text.trim();
    reason.dispose();
    if (ok != true || !mounted) return;
    setState(() => booking = true);
    try {
      await Api.dio.post('/api/v1/appointments', data: {
        'patient_id': patientId,
        'doctor_id': doctorId,
        'start_at': start.toIso8601String(),
        'appointment_type': type,
        'reason': reasonText.isEmpty ? null : reasonText,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Appointment booked.')));
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    } finally {
      if (mounted) setState(() => booking = false);
    }
  }

  Future<void> setStatus(Map<String, dynamic> a, String status) async {
    final id = a['id'].toString();
    if (updating.contains(id)) return;
    setState(() => updating.add(id));
    try {
      await Api.dio.patch('/api/v1/appointments/${a['id']}/status', data: {'status': status});
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    } finally {
      if (mounted) setState(() => updating.remove(id));
    }
  }

  Future<void> reschedule(Map<String, dynamic> a) async {
    final old = DateTime.tryParse(a['start_at']?.toString() ?? '') ?? DateTime.now().add(Duration(days: 1));
    final start = await pickDateTime(old);
    if (start == null) return;
    try {
      await Api.dio.patch('/api/v1/appointments/${a['id']}/reschedule', data: {'start_at': start.toIso8601String()});
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  Map<String, dynamic>? _byId(List<dynamic> source, dynamic id) {
    for (final row in source) {
      if (row['id']?.toString() == id?.toString()) return Map<String, dynamic>.from(row as Map);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 700 ? 16.0 : 28.0;
    final today = DateTime.now();
    bool sameDay(DateTime? d) => d != null && d.year == today.year && d.month == today.month && d.day == today.day;
    final todayCount = appointments.where((x) => sameDay(DateTime.tryParse(x['start_at']?.toString() ?? ''))).length;
    final waiting = appointments.where((x) => ['checked_in', 'waiting'].contains(x['status'])).length;
    final completed = appointments.where((x) => x['status'] == 'completed').length;
    final visible = appointments.where((x) {
      final at = DateTime.tryParse(x['start_at']?.toString() ?? '');
      final p = _byId(patients, x['patient_id']);
      final d = _byId(doctors, x['doctor_id']);
      final matches = '${p?['full_name']} ${d?['full_name']} ${x['reason'] ?? ''}'.toLowerCase().contains(query.toLowerCase());
      return matches && (filter == 'all' || x['status'] == filter) &&
          (dateFilter == 'all' || (dateFilter == 'today' && sameDay(at)) ||
           (dateFilter == 'upcoming' && at != null && at.isAfter(today)));
    }).toList()..sort((a, b) => '${a['start_at']}'.compareTo('${b['start_at']}'));

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 26, pad, 38),
        children: [
          CxPageHeader(
            icon: Icons.calendar_month_rounded,
            eyebrow: 'Scheduling engine',
            title: 'Appointments',
            subtitle: 'Coordinate requests, check-in, waiting room status and consultation hand-off from a single operational view.',
            actions: [
              OutlinedButton.icon(onPressed: load, icon: Icon(Icons.refresh_rounded), label: Text('Refresh')),
              FilledButton.icon(onPressed: loading || booking || !Api.can('appointments.create') ? null : book, icon: Icon(Icons.add_rounded), label: Text('Book appointment')),
            ],
          ),
          SizedBox(height: 18),
          CxAdaptiveGrid(
            minItemWidth: 210,
            children: [
              CxMetricCard(label: 'Today', value: '$todayCount', caption: 'Appointments scheduled today', icon: Icons.today_outlined),
              CxMetricCard(label: 'Waiting', value: '$waiting', caption: 'Checked-in or waiting', icon: Icons.hourglass_top_rounded, tone: ClinexaTheme.warning),
              CxMetricCard(label: 'Completed', value: '$completed', caption: 'Visits completed in this list', icon: Icons.task_alt_rounded, tone: ClinexaTheme.success),
              CxMetricCard(label: 'Total', value: '${appointments.length}', caption: 'Appointments in workspace', icon: Icons.calendar_month_outlined, tone: ClinexaTheme.accent),
            ],
          ),
          if (error != null) ...[SizedBox(height: 12), CxErrorBanner(message: error!, onRetry: load)],
          SizedBox(height: 16),
          CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CxSectionHeader(
              title: 'Visit flow',
              subtitle: 'Move appointments through their real operational status.',
              action: PopupMenuButton<String>(
                initialValue: filter,
                onSelected: (v) => setState(() => filter = v),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'all', child: Text('All statuses')),
                  PopupMenuItem(value: 'requested', child: Text('Requested')),
                  PopupMenuItem(value: 'confirmed', child: Text('Confirmed')),
                  PopupMenuItem(value: 'waiting', child: Text('Waiting')),
                  PopupMenuItem(value: 'in_consultation', child: Text('In consultation')),
                  PopupMenuItem(value: 'completed', child: Text('Completed')),
                  PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                child: CxStatusChip(label: filter == 'all' ? 'All status' : _label(filter), icon: Icons.filter_list_rounded),
              ),
            ),
            SizedBox(height: 13),
            TextField(onChanged: (v) => setState(() => query = v), decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Find a patient, doctor or visit…')),
            SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: {'all': 'All dates', 'today': 'Today', 'upcoming': 'Upcoming'}.entries.map((e) => ChoiceChip(label: Text(e.value), selected: dateFilter == e.key, onSelected: (_) => setState(() => dateFilter = e.key))).toList()),
            SizedBox(height: 16),
            if (loading) ...List.generate(5, (_) => Padding(padding: EdgeInsets.only(bottom: 9), child: CxSkeleton(height: 82))),
            if (!loading && visible.isEmpty) CxEmptyState(icon: Icons.calendar_month_outlined, title: 'No appointments in this view', message: 'Book a visit or change the status filter.'),
            if (!loading) ...visible.map((raw) {
              final a = Map<String, dynamic>.from(raw as Map);
              final patient = _byId(patients, a['patient_id']);
              final doctor = _byId(doctors, a['doctor_id']);
              return _AppointmentRow(
                appointment: a,
                patientName: patient?['full_name']?.toString() ?? 'Patient',
                doctorName: doctor?['full_name']?.toString() ?? 'Doctor',
                specialty: doctor?['specialty']?.toString() ?? '',
                onStatus: setStatus,
                onReschedule: reschedule,
              );
            }),
          ])),
        ],
      ),
    );
  }
}

class _AppointmentRow extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final String patientName;
  final String doctorName;
  final String specialty;
  final Future<void> Function(Map<String, dynamic>, String) onStatus;
  final Future<void> Function(Map<String, dynamic>) onReschedule;
  _AppointmentRow({required this.appointment, required this.patientName, required this.doctorName, required this.specialty, required this.onStatus, required this.onReschedule});

  @override
  Widget build(BuildContext context) {
    final status = appointment['status']?.toString() ?? 'requested';
    final tone = _statusColor(status);
    final at = DateTime.tryParse(appointment['start_at']?.toString() ?? '');
    return Container(
      margin: EdgeInsets.only(bottom: 9),
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(17), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: LayoutBuilder(builder: (_, c) {
        final compact = c.maxWidth < 650;
        final body = Row(children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(color: tone.withAlpha(18), borderRadius: BorderRadius.circular(15)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(at == null ? '—' : '${at.day}', style: TextStyle(color: tone, fontSize: 18, fontWeight: FontWeight.w900)), Text(at == null ? '' : _month(at.month), style: TextStyle(color: tone, fontSize: 9, fontWeight: FontWeight.w800))])),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(appointment['reason']?.toString().trim().isNotEmpty == true ? appointment['reason'].toString() : 'Clinical appointment', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            SizedBox(height: 3),
            Text('$patientName  •  $doctorName${specialty.isEmpty ? '' : '  •  $specialty'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.3)),
            SizedBox(height: 5),
            Wrap(spacing: 6, runSpacing: 5, children: [
              CxStatusChip(label: _label(status), color: tone),
              CxStatusChip(label: _label(appointment['appointment_type']?.toString() ?? 'in_person'), color: Color(0xFF4567C6), icon: appointment['appointment_type'] == 'teleconsultation' ? Icons.videocam_outlined : Icons.location_on_outlined),
              if (appointment['queue_token'] != null) CxStatusChip(label: appointment['queue_token'].toString(), color: ClinexaTheme.warning, icon: Icons.confirmation_number_outlined),
            ]),
          ])),
        ]);
        final allowed = <String, List<String>>{
          'requested': ['confirmed', 'cancelled'],
          'confirmed': ['checked_in', 'no_show', 'cancelled'],
          'rescheduled': ['checked_in', 'no_show', 'cancelled'],
          'checked_in': ['waiting', 'in_consultation', 'cancelled'],
          'waiting': ['in_consultation', 'no_show', 'cancelled'],
          'in_consultation': ['completed', 'cancelled'],
        }[status] ?? [];
        final menu = !Api.can('appointments.modify') || allowed.isEmpty ? SizedBox.shrink() : PopupMenuButton<String>(
          onSelected: (v) { if (v == 'reschedule') { onReschedule(appointment); } else { onStatus(appointment, v); } },
          tooltip: 'Visit actions',
          itemBuilder: (_) => [
            ...allowed.map((s) => PopupMenuItem(value: s, child: Text(_label(s)))),
            if (status != 'in_consultation') PopupMenuItem(value: 'reschedule', child: Text('Reschedule')),
          ],
        );
        if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [body, SizedBox(height: 8), Row(mainAxisAlignment: MainAxisAlignment.end, children: [if (at != null) Text(_formatTime(at), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 10.5)), menu])]);
        return Row(children: [Expanded(child: body), if (at != null) Text(_formatTime(at), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 10.5)), menu]);
      }),
    );
  }
}

String _formatDate(DateTime dt) {
  final minute = dt.minute.toString().padLeft(2, '0');
  final hour = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
  final ap = dt.hour >= 12 ? 'PM' : 'AM';
  return '${_month(dt.month)} ${dt.day}, ${dt.year} • $hour:$minute $ap';
}

String _formatTime(DateTime dt) {
  final minute = dt.minute.toString().padLeft(2, '0');
  final hour = dt.hour == 0 ? 12 : dt.hour > 12 ? dt.hour - 12 : dt.hour;
  return '$hour:$minute ${dt.hour >= 12 ? 'PM' : 'AM'}';
}

String _month(int m) => ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'][m - 1];
String _label(String s) => s.replaceAll('_', ' ').split(' ').map((x) => x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}').join(' ');
Color _statusColor(String status) {
  if (status == 'completed') return ClinexaTheme.success;
  if (status == 'cancelled' || status == 'no_show') return ClinexaTheme.emergency;
  if (status == 'waiting' || status == 'checked_in') return ClinexaTheme.warning;
  if (status == 'in_consultation') return Color(0xFF6B56C8);
  return ClinexaTheme.primary;
}
