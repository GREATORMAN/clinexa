import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class PatientPortalPage extends StatefulWidget {
  const PatientPortalPage({super.key});

  @override
  State<PatientPortalPage> createState() => _PatientPortalPageState();
}

class _PatientPortalPageState extends State<PatientPortalPage> {
  Map<String, dynamic>? data;
  List<dynamic> doctors = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  List<dynamic> list(String key) => List<dynamic>.from((data?[key] as List?) ?? const []);

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([
        Api.dio.get('/api/v1/portal/home'),
        Api.dio.get('/api/v1/portal/doctors'),
      ]);
      if (!mounted) return;
      setState(() {
        data = Map<String, dynamic>.from(results[0].data as Map);
        doctors = List<dynamic>.from(results[1].data as List);
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { error = Api.errorMessage(e); loading = false; });
    }
  }

  Future<void> requestAppointment() async {
    if (doctors.isEmpty) {
      showMessage(context, 'No doctors are currently available in the directory.');
      return;
    }
    String doctorId = doctors.first['id'].toString();
    String type = 'in_person';
    DateTime selected = DateTime.now().add(const Duration(days: 1));
    final reason = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Request appointment'),
          content: SizedBox(
            width: 520,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: doctorId,
                decoration: const InputDecoration(labelText: 'Doctor'),
                items: doctors.map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text('${d['full_name']} • ${d['specialty']}'))).toList(),
                onChanged: (v) => setLocal(() => doctorId = v ?? doctorId),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: type,
                decoration: const InputDecoration(labelText: 'Appointment type'),
                items: const [
                  DropdownMenuItem(value: 'in_person', child: Text('In person')),
                  DropdownMenuItem(value: 'teleconsultation', child: Text('Teleconsultation')),
                ],
                onChanged: (v) => setLocal(() => type = v ?? type),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Requested time'),
                subtitle: Text(selected.toLocal().toString().substring(0, 16)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () async {
                  final date = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: selected);
                  if (date == null || !ctx.mounted) return;
                  final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(selected));
                  if (time == null) return;
                  setLocal(() => selected = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
              TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Reason (optional)')),
              const SizedBox(height: 12),
              const _Notice(text: 'Clinexa sends this as an appointment request. The selected time is not treated as clinically confirmed until the scheduling workflow accepts it.'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Request')),
          ],
        ),
      ),
    );
    if (ok != true) return;

    try {
      await Api.dio.post('/api/v1/portal/appointments', data: {
        'doctor_id': doctorId,
        'start_at': selected.toIso8601String(),
        'appointment_type': type,
        'reason': reason.text.trim().isEmpty ? null : reason.text.trim(),
      });
      if (mounted) showMessage(context, 'Appointment request created.');
      await load();
    } catch (e) {
      if (mounted) showMessage(context, Api.errorMessage(e));
    }
  }

  Future<void> cancelAppointment(Map<String, dynamic> appointment) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Cancel appointment?'),
      content: const Text('This will update the appointment status to cancelled.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel appointment'))],
    ));
    if (ok != true) return;
    try {
      await Api.dio.post('/api/v1/portal/appointments/${appointment['id']}/cancel');
      await load();
    } catch (e) {
      if (mounted) showMessage(context, Api.errorMessage(e));
    }
  }

  Future<void> logDose(Map<String, dynamic> schedule, String status) async {
    final now = DateTime.now();
    try {
      await Api.dio.post('/api/v1/portal/medications/${schedule['id']}/dose-logs', data: {
        'scheduled_for': now.toIso8601String(),
        'status': status,
        'note': null,
      });
      if (mounted) showMessage(context, 'Medication status logged as $status.');
    } catch (e) {
      if (mounted) showMessage(context, Api.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = data?['patient'] as Map?;
    final appointments = list('appointments');
    final medications = list('medications');
    final schedules = list('medication_schedules');
    final labs = list('labs');
    final documents = list('documents');

    return SectionPage(
      title: 'My Clinexa',
      subtitle: 'Your appointments, verified medicines, results and records',
      actions: [
        IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
        FilledButton.icon(onPressed: requestAppointment, icon: const Icon(Icons.calendar_month_outlined), label: const Text('Request appointment')),
      ],
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (error != null) ErrorCard(error!),
          if (loading) const LinearProgressIndicator(),
          if (!loading && patient != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(children: [
                  CircleAvatar(radius: 24, child: Text((patient['full_name']?.toString() ?? 'P').substring(0, 1).toUpperCase())),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(patient['full_name']?.toString() ?? 'Patient', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                    Text('${patient['patient_code']} • Blood ${patient['blood_group'] ?? 'not recorded'}', style: const TextStyle(color: Color(0xFF667085))),
                  ])),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            _PortalSection(
              title: 'Appointments',
              icon: Icons.calendar_month_outlined,
              empty: 'No appointments yet.',
              children: appointments.take(8).map((raw) {
                final a = Map<String, dynamic>.from(raw as Map);
                final cancellable = !{'completed', 'cancelled', 'no_show'}.contains(a['status']);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: Text(a['reason']?.toString().isNotEmpty == true ? a['reason'].toString() : 'Appointment'),
                  subtitle: Text('${a['start_at']} • ${a['status']}'),
                  trailing: cancellable ? IconButton(tooltip: 'Cancel', onPressed: () => cancelAppointment(a), icon: const Icon(Icons.cancel_outlined)) : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            _PortalSection(
              title: 'Verified medicines',
              icon: Icons.medication_outlined,
              empty: 'No verified medicines in your record.',
              children: medications.take(10).map((raw) {
                final m = Map<String, dynamic>.from(raw as Map);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.medication_rounded),
                  title: Text(m['medication_name']?.toString() ?? 'Medicine'),
                  subtitle: Text([m['strength'], m['frequency'], m['duration']].where((x) => x != null && x.toString().isNotEmpty).join(' • ')),
                  trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFE7F4EE), borderRadius: BorderRadius.circular(999)), child: Text(m['status']?.toString() ?? 'active', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                );
              }).toList(),
            ),
            if (schedules.isNotEmpty) ...[
              const SizedBox(height: 14),
              _PortalSection(
                title: 'Medication reminders',
                icon: Icons.alarm_outlined,
                empty: 'No reminders configured.',
                children: schedules.where((x) => x['active'] == true).take(8).map((raw) {
                  final s = Map<String, dynamic>.from(raw as Map);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s['medication_name']?.toString() ?? 'Medicine'),
                    subtitle: Text('${s['dose_label'] ?? ''} • ${s['times_csv'] ?? ''}'),
                    trailing: Wrap(spacing: 2, children: [
                      IconButton(tooltip: 'Log taken', onPressed: () => logDose(s, 'taken'), icon: const Icon(Icons.check_circle_outline_rounded)),
                      IconButton(tooltip: 'Log skipped', onPressed: () => logDose(s, 'skipped'), icon: const Icon(Icons.remove_circle_outline_rounded)),
                    ]),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            _PortalSection(
              title: 'Recent lab results',
              icon: Icons.science_outlined,
              empty: 'No lab results available.',
              children: labs.take(8).map((raw) {
                final l = Map<String, dynamic>.from(raw as Map);
                return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.biotech_outlined), title: Text(l['test_name']?.toString() ?? 'Lab test'), subtitle: Text('${l['result_value'] ?? ''} ${l['unit'] ?? ''} • reference ${l['reference_range'] ?? 'not recorded'}'));
              }).toList(),
            ),
            const SizedBox(height: 14),
            _PortalSection(
              title: 'Records vault',
              icon: Icons.folder_outlined,
              empty: 'No documents uploaded.',
              children: documents.take(10).map((raw) {
                final d = Map<String, dynamic>.from(raw as Map);
                return ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.description_outlined), title: Text(d['original_name']?.toString() ?? 'Document'), subtitle: Text('${d['category'] ?? 'other'} • ${d['created_at'] ?? ''}'));
              }).toList(),
            ),
            const SizedBox(height: 14),
            const _Notice(text: 'Only clinician-verified or explicitly confirmed records are presented as permanent medication information. OCR/AI draft text is kept separate until reviewed.'),
          ],
        ],
      ),
    );
  }
}

class _PortalSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String empty;
  final List<Widget> children;
  const _PortalSection({required this.title, required this.icon, required this.empty, required this.children});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
            const SizedBox(height: 10),
            if (children.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(empty)) else ...children,
          ]),
        ),
      );
}

class _Notice extends StatelessWidget {
  final String text;
  const _Notice({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF5F8FB), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline_rounded, size: 18), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5, height: 1.4)))]),
      );
}
