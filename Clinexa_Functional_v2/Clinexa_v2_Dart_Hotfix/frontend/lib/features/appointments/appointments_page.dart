import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class AppointmentsPage extends StatefulWidget { const AppointmentsPage({super.key}); @override State<AppointmentsPage> createState() => _AppointmentsPageState(); }

class _AppointmentsPageState extends State<AppointmentsPage> {
  List<dynamic> appointments = []; List<dynamic> patients = []; List<dynamic> doctors = []; String? error;
  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final r = await Future.wait([Api.dio.get('/api/v1/appointments'), Api.dio.get('/api/v1/patients'), Api.dio.get('/api/v1/doctors')]);
      if (mounted) setState(() { appointments = List.from(r[0].data); patients = List.from(r[1].data); doctors = List.from(r[2].data); error = null; });
    } catch (e) { if (mounted) setState(() => error = Api.errorMessage(e)); }
  }

  Future<DateTime?> pickDateTime(DateTime initial) async {
    final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)));
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> book() async {
    if (patients.isEmpty || doctors.isEmpty) { showMessage(context, 'Add at least one patient and doctor first.'); return; }
    String patientId = patients.first['id'].toString(); String doctorId = doctors.first['id'].toString(); String type = 'in_person'; DateTime start = DateTime.now().add(const Duration(days: 1));
    final reason = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: const Text('Book appointment'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: patientId, decoration: const InputDecoration(labelText: 'Patient'), items: patients.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text(x['full_name'].toString()))).toList(), onChanged: (v) => setLocal(() => patientId = v ?? patientId)),
        const SizedBox(height: 10), DropdownButtonFormField<String>(value: doctorId, decoration: const InputDecoration(labelText: 'Doctor'), items: doctors.map((x) => DropdownMenuItem(value: x['id'].toString(), child: Text('${x['full_name']} — ${x['specialty']}'))).toList(), onChanged: (v) => setLocal(() => doctorId = v ?? doctorId)),
        const SizedBox(height: 10), DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Type'), items: const [DropdownMenuItem(value: 'in_person', child: Text('In-person')), DropdownMenuItem(value: 'teleconsultation', child: Text('Teleconsultation')), DropdownMenuItem(value: 'follow_up', child: Text('Follow-up'))], onChanged: (v) => setLocal(() => type = v ?? type)),
        const SizedBox(height: 10), ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event), title: const Text('Date and time'), subtitle: Text(start.toString()), trailing: const Icon(Icons.edit), onTap: () async { final x = await pickDateTime(start); if (x != null) setLocal(() => start = x); }),
        TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason / notes')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Book'))],
    )));
    if (ok != true) return;
    try { await Api.dio.post('/api/v1/appointments', data: {'patient_id': patientId, 'doctor_id': doctorId, 'start_at': start.toIso8601String(), 'appointment_type': type, 'reason': reason.text.trim().isEmpty ? null : reason.text.trim()}); if (mounted) showMessage(context, 'Appointment booked.'); await load(); } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  Future<void> setStatus(Map<String,dynamic> a, String status) async {
    try { await Api.dio.patch('/api/v1/appointments/${a['id']}/status', data: {'status': status}); if (mounted) showMessage(context, 'Appointment updated to $status.'); await load(); } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  Future<void> reschedule(Map<String,dynamic> a) async {
    final old = DateTime.tryParse(a['start_at']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 1));
    final start = await pickDateTime(old); if (start == null) return;
    try { await Api.dio.patch('/api/v1/appointments/${a['id']}/reschedule', data: {'start_at': start.toIso8601String()}); if (mounted) showMessage(context, 'Appointment rescheduled.'); await load(); } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  @override
  Widget build(BuildContext context) => SectionPage(
    title: 'Appointments', subtitle: 'Book, check in, queue, reschedule and complete visits',
    actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh)), FilledButton.icon(onPressed: book, icon: const Icon(Icons.add), label: const Text('Book'))],
    child: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(18), children: [
      if (error != null) ErrorCard(error!),
      Card(child: Column(children: [
        for (final raw in appointments) Builder(builder: (_) { final a = Map<String,dynamic>.from(raw); return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.event_available_outlined)),
          title: Text(a['reason']?.toString().isNotEmpty == true ? a['reason'].toString() : 'Appointment'),
          subtitle: Text(
            "${a['start_at'] ?? ''}\n${a['appointment_type'] ?? ''} • ${a['status'] ?? ''}${a['queue_token'] != null ? " • ${a['queue_token']}" : ''}",
          ),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'reschedule') { reschedule(a); } else { setStatus(a, v); } }, itemBuilder: (_) => const [
            PopupMenuItem(value: 'checked_in', child: Text('Check in')), PopupMenuItem(value: 'waiting', child: Text('Mark waiting')), PopupMenuItem(value: 'in_consultation', child: Text('Start consultation')), PopupMenuItem(value: 'completed', child: Text('Complete')), PopupMenuItem(value: 'reschedule', child: Text('Reschedule')), PopupMenuItem(value: 'cancelled', child: Text('Cancel')),
          ]),
        ); }),
        if (appointments.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Text('No appointments yet. Tap Book to create one.')),
      ])),
    ])),
  );
}
