import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class MedicineCentrePage extends StatefulWidget {
  final String? initialPatientId;
  const MedicineCentrePage({super.key, this.initialPatientId});

  @override
  State<MedicineCentrePage> createState() => _MedicineCentrePageState();
}

class _MedicineCentrePageState extends State<MedicineCentrePage> {
  List<dynamic> patients = [];
  String? patientId;
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    patientId = widget.initialPatientId;
    bootstrap();
  }

  Future<void> bootstrap() async {
    try {
      final response = await Api.dio.get('/api/v1/patients');
      patients = List<dynamic>.from(response.data as List);
      patientId ??= patients.isNotEmpty ? patients.first['id'].toString() : null;
      if (mounted) setState(() {});
      await load();
    } catch (e) {
      if (mounted) setState(() { error = Api.errorMessage(e); loading = false; });
    }
  }

  Future<void> load() async {
    if (patientId == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final response = await Api.dio.get('/api/v1/advanced/medication-centre/$patientId');
      if (!mounted) return;
      setState(() { data = Map<String, dynamic>.from(response.data as Map); loading = false; });
    } catch (e) {
      if (mounted) setState(() { error = Api.errorMessage(e); loading = false; });
    }
  }

  List<dynamic> list(String key) => List<dynamic>.from((data?[key] as List?) ?? const []);

  Future<void> addMedication() async {
    if (patientId == null) return;
    final name = TextEditingController();
    final strength = TextEditingController();
    final form = TextEditingController();
    final frequency = TextEditingController();
    final route = TextEditingController();
    final duration = TextEditingController();
    final doctor = TextEditingController();
    final instructions = TextEditingController();
    final reminders = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add verified medicine'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Medicine name *')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: strength, decoration: const InputDecoration(labelText: 'Strength'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: form, decoration: const InputDecoration(labelText: 'Form'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: frequency, decoration: const InputDecoration(labelText: 'Frequency'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: route, decoration: const InputDecoration(labelText: 'Route'))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: duration, decoration: const InputDecoration(labelText: 'Duration')),
                const SizedBox(height: 10),
                TextField(controller: doctor, decoration: const InputDecoration(labelText: 'Prescribing doctor/source')),
                const SizedBox(height: 10),
                TextField(controller: instructions, maxLines: 2, decoration: const InputDecoration(labelText: 'Instructions')),
                const SizedBox(height: 10),
                TextField(
                  controller: reminders,
                  decoration: const InputDecoration(
                    labelText: 'Reminder times (optional)',
                    hintText: '09:00,21:00 — enter exact times only',
                  ),
                ),
                const SizedBox(height: 10),
                const _SafetyNote(
                  text: 'Clinexa does not infer reminder times from a frequency such as “twice daily”. Enter exact times only if they were explicitly chosen by the patient/clinician.',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save medicine')),
        ],
      ),
    );

    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await Api.dio.post('/api/v1/advanced/medication-centre', data: {
        'patient_id': patientId,
        'medication_name': name.text.trim(),
        'strength': _empty(strength.text),
        'form': _empty(form.text),
        'frequency': _empty(frequency.text),
        'route': _empty(route.text),
        'duration': _empty(duration.text),
        'prescribing_doctor_text': _empty(doctor.text),
        'instructions': _empty(instructions.text),
        'reminder_times': _empty(reminders.text),
        'status': 'active',
      });
      if (mounted) showMessage(context, 'Medicine added to this patient.');
      await load();
    } catch (e) {
      if (mounted) showMessage(context, Api.errorMessage(e));
    }
  }

  String? _empty(String value) => value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    final current = list('current');
    final previous = list('previous');
    final schedules = list('schedules');
    final imports = list('ocr_imports');

    return SectionPage(
      title: 'Medicine Centre',
      subtitle: 'Patient-linked medicines, prescription sources and explicit reminder schedules',
      actions: [
        IconButton(onPressed: load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded)),
        FilledButton.icon(onPressed: patientId == null ? null : addMedication, icon: const Icon(Icons.add_rounded), label: const Text('Add medicine')),
      ],
      child: patients.isEmpty
          ? const Center(child: Text('Add a patient before managing medicines.'))
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                DropdownButtonFormField<String>(
                  value: patientId,
                  decoration: const InputDecoration(labelText: 'Patient'),
                  items: patients.map((p) => DropdownMenuItem<String>(value: p['id'].toString(), child: Text('${p['full_name']} • ${p['patient_code']}'))).toList(),
                  onChanged: (v) async { setState(() => patientId = v); await load(); },
                ),
                if (error != null) ...[const SizedBox(height: 12), ErrorCard(error!)],
                if (loading) ...[const SizedBox(height: 16), const LinearProgressIndicator()],
                if (!loading) ...[
                  const SizedBox(height: 16),
                  _SummaryStrip(current: current.length, previous: previous.length, reminders: schedules.where((s) => s['active'] == true).length, imports: imports.where((x) => x['status'] == 'confirmed').length),
                  const SizedBox(height: 14),
                  _MedicationSection(
                    title: 'Current medicines',
                    subtitle: 'Verified medicines currently marked active',
                    icon: Icons.medication_rounded,
                    medicines: current,
                    emptyText: 'No active medicines have been verified for this patient.',
                  ),
                  const SizedBox(height: 14),
                  _MedicationSection(
                    title: 'Previous medicines',
                    subtitle: 'Completed, stopped or historical medicines',
                    icon: Icons.history_rounded,
                    medicines: previous,
                    emptyText: 'No previous medicines recorded.',
                  ),
                  const SizedBox(height: 14),
                  _ReminderSection(schedules: schedules),
                  const SizedBox(height: 14),
                  _ImportSection(imports: imports),
                  const SizedBox(height: 14),
                  const _SafetyNote(
                    text: 'OCR and AI suggestions never enter the permanent medication record automatically. A person must review and confirm every imported medicine first.',
                  ),
                ],
              ],
            ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final int current;
  final int previous;
  final int reminders;
  final int imports;
  const _SummaryStrip({required this.current, required this.previous, required this.reminders, required this.imports});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Metric(label: 'Current', value: current.toString(), icon: Icons.medication_rounded),
          _Metric(label: 'Previous', value: previous.toString(), icon: Icons.history_rounded),
          _Metric(label: 'Active reminders', value: reminders.toString(), icon: Icons.notifications_active_outlined),
          _Metric(label: 'OCR imports', value: imports.toString(), icon: Icons.document_scanner_outlined),
        ],
      );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        width: 176,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE4EAF1))),
        child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)), Text(label, style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)))])]),
      );
}

class _MedicationSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<dynamic> medicines;
  final String emptyText;
  const _MedicationSection({required this.title, required this.subtitle, required this.icon, required this.medicines, required this.emptyText});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), Text(subtitle, style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085))) ]))]),
            const SizedBox(height: 14),
            if (medicines.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(emptyText)) else ...medicines.map((raw) {
              final m = Map<String, dynamic>.from(raw as Map);
              final details = [m['strength'], m['form'], m['frequency'], m['route'], m['duration']].where((x) => x != null && x.toString().trim().isNotEmpty).join(' • ');
              final source = m['source_type']?.toString() ?? 'record';
              return Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0xFFE9F4F3), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.medication_outlined, size: 20)),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m['medication_name']?.toString() ?? 'Medicine', style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (details.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(details, style: const TextStyle(fontSize: 12.5))),
                    if ((m['instructions']?.toString() ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(m['instructions'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: Color(0xFF667085)))),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 5, children: [
                      _Chip(text: source.replaceAll('_', ' ')),
                      if ((m['prescribing_doctor_text']?.toString() ?? '').isNotEmpty) _Chip(text: m['prescribing_doctor_text'].toString()),
                      _Chip(text: m['verified'] == true ? 'Verified' : 'Needs review'),
                    ]),
                  ])),
                ]),
              );
            }),
          ]),
        ),
      );
}

class _ReminderSection extends StatelessWidget {
  final List<dynamic> schedules;
  const _ReminderSection({required this.schedules});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Reminder schedules', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Only exact times entered by a person are shown here.', style: TextStyle(fontSize: 11.5, color: Color(0xFF667085))),
            const SizedBox(height: 12),
            if (schedules.isEmpty) const Text('No reminder schedules configured.') else ...schedules.map((raw) {
              final s = Map<String, dynamic>.from(raw as Map);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(s['active'] == true ? Icons.alarm_on_rounded : Icons.alarm_off_rounded),
                title: Text(s['medication_name']?.toString() ?? 'Medicine'),
                subtitle: Text('${s['dose_label'] ?? ''} • ${s['times_csv'] ?? ''}'),
                trailing: _Chip(text: s['active'] == true ? 'Active' : 'Inactive'),
              );
            }),
          ]),
        ),
      );
}

class _ImportSection extends StatelessWidget {
  final List<dynamic> imports;
  const _ImportSection({required this.imports});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Prescription OCR history', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 12),
            if (imports.isEmpty) const Text('No prescription OCR imports for this patient.') else ...imports.map((raw) {
              final x = Map<String, dynamic>.from(raw as Map);
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.document_scanner_outlined),
                title: Text(x['doctor_name_text']?.toString().isNotEmpty == true ? x['doctor_name_text'].toString() : 'Prescription import'),
                subtitle: Text(x['prescription_date_text']?.toString() ?? x['created_at']?.toString() ?? ''),
                trailing: _Chip(text: x['status']?.toString() ?? 'draft'),
              );
            }),
          ]),
        ),
      );
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFEEF2F6), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600)),
      );
}

class _SafetyNote extends StatelessWidget {
  final String text;
  const _SafetyNote({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: const Color(0xFFFFF8E8), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFF5E3AE))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.verified_user_outlined, size: 19), const SizedBox(width: 9), Expanded(child: Text(text, style: const TextStyle(fontSize: 11.5, height: 1.4)))]),
      );
}
