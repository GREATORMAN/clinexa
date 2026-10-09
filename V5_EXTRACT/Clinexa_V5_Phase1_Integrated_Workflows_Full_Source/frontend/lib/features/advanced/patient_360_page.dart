import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';
import '../medications/medicine_centre_page.dart';

class Patient360Page extends StatefulWidget {
  const Patient360Page({super.key});
  @override
  State<Patient360Page> createState() => _Patient360PageState();
}

class _Patient360PageState extends State<Patient360Page> {
  List<dynamic> patients = [];
  String? patientId;
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); loadPatients(); }

  Future<void> loadPatients() async {
    try {
      final r = await Api.dio.get('/api/v1/patients');
      patients = List<dynamic>.from(r.data as List);
      if (patients.isNotEmpty) patientId ??= patients.first['id'].toString();
      await load360();
    } catch (e) {
      if (mounted) setState(() { error = Api.errorMessage(e); loading = false; });
    }
  }

  Future<void> load360() async {
    if (patientId == null) { if (mounted) setState(() => loading = false); return; }
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final r = await Api.dio.get('/api/v1/advanced/patients/$patientId/360');
      if (mounted) setState(() => data = Map<String, dynamic>.from(r.data));
    } catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<dynamic> _list(String key) => List<dynamic>.from(data?[key] as List? ?? const []);

  Future<void> addSymptom() async {
    if (patientId == null) return;
    final symptom = TextEditingController();
    final note = TextEditingController();
    double severity = 3;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: const Text('Add symptom entry'),
      content: SizedBox(width: 430, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: symptom, decoration: const InputDecoration(labelText: 'Symptom')),
        const SizedBox(height: 12),
        Row(children: [const Text('Severity'), Expanded(child: Slider(value: severity, min: 1, max: 10, divisions: 9, label: severity.round().toString(), onChanged: (v) => setLocal(() => severity = v)))]),
        TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Note')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
    )));
    if (ok == true && symptom.text.trim().isNotEmpty) {
      await Api.dio.post('/api/v1/advanced/symptoms/$patientId', data: {'symptom': symptom.text.trim(), 'severity': severity.round(), 'note': note.text.trim()});
      await load360();
    }
  }

  Future<void> openMedicineCentre() async {
    if (patientId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MedicineCentrePage(initialPatientId: patientId)),
    );
    await load360();
  }

  Future<void> aiSummary() async {
    if (patientId == null) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    try {
      final r = await Api.dio.get('/api/v1/ai/patient/$patientId/summary');
      if (!mounted) return; Navigator.pop(context);
      final text = (r.data as Map)['answer']?.toString() ?? 'No summary returned.';
      await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('AI record summary'), content: SingleChildScrollView(child: Text(text)), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]));
    } on DioException catch (e) {
      if (!mounted) return; Navigator.pop(context); showMessage(context, Api.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final patient = data?['patient'] as Map?;
    return SectionPage(
      title: 'Patient 360°',
      subtitle: 'One longitudinal workspace for the complete patient journey',
      actions: [IconButton(onPressed: load360, icon: const Icon(Icons.refresh_rounded))],
      child: ListView(padding: const EdgeInsets.all(18), children: [
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(value: patientId, decoration: const InputDecoration(labelText: 'Patient'), items: patients.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text('${p['full_name']} • ${p['patient_code']}'))).toList(), onChanged: (v) { setState(() => patientId = v); load360(); })),
          const SizedBox(width: 10),
          FilledButton.icon(onPressed: patientId == null ? null : aiSummary, icon: const Icon(Icons.auto_awesome_outlined), label: const Text('AI summary')),
        ]),
        if (error != null) ...[const SizedBox(height: 12), ErrorCard(error!)],
        if (loading) ...[const SizedBox(height: 20), const LinearProgressIndicator()],
        if (!loading && patient != null) ...[
          const SizedBox(height: 16), _PatientHero(patient: Map<String, dynamic>.from(patient)),
          const SizedBox(height: 14), Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(onPressed: addSymptom, icon: const Icon(Icons.monitor_heart_outlined), label: const Text('Log symptom')),
            OutlinedButton.icon(onPressed: openMedicineCentre, icon: const Icon(Icons.medication_outlined), label: const Text('Medicine Centre')),
          ]),
          const SizedBox(height: 18), _Section(title: 'Recent timeline', icon: Icons.timeline_rounded, children: [
            ..._list('encounters').take(5).map((e) => _Line(title: e['chief_complaint']?.toString() ?? 'Encounter', sub: e['assessment']?.toString() ?? 'Clinical encounter')),
            ..._list('appointments').take(4).map((e) => _Line(title: 'Appointment • ${e['status']}', sub: '${e['start_at']} • ${e['reason'] ?? ''}')),
          ]),
          const SizedBox(height: 14), _Section(title: 'Vitals', icon: Icons.monitor_heart_outlined, children: _list('vitals').take(6).map((v) => _Line(title: 'BP ${v['systolic'] ?? '—'}/${v['diastolic'] ?? '—'} • HR ${v['heart_rate'] ?? '—'}', sub: 'SpO₂ ${v['spo2'] ?? '—'} • Temp ${v['temperature_c'] ?? '—'} • ${v['observed_at'] ?? ''}')).toList()),
          const SizedBox(height: 14), _Section(title: 'Medicines', icon: Icons.medication_outlined, children: [
            ..._list('patient_medications').take(8).map((m) => _Line(
              title: m['medication_name']?.toString() ?? 'Medication',
              sub: '${m['strength'] ?? ''} • ${m['frequency'] ?? ''} • ${m['status'] ?? ''} • ${(m['source_type'] ?? 'record').toString().replaceAll('_', ' ')}',
            )),
            if (_list('patient_medications').isEmpty) ..._list('prescriptions').take(6).map((m) => _Line(title: m['medication_name']?.toString() ?? 'Prescription', sub: '${m['strength'] ?? ''} • ${m['frequency'] ?? ''} • ${m['status'] ?? ''}')),
            ..._list('medication_schedules').take(4).map((m) => _Line(title: 'Reminder • ${m['medication_name'] ?? 'Medication'}', sub: '${m['dose_label'] ?? ''} • ${m['times_csv'] ?? ''}')),
          ]),
          const SizedBox(height: 14), _Section(title: 'Labs', icon: Icons.science_outlined, children: _list('labs').take(8).map((l) => _Line(title: l['test_name']?.toString() ?? 'Lab', sub: '${l['result_value'] ?? ''} ${l['unit'] ?? ''} • range ${l['reference_range'] ?? 'not recorded'}')).toList()),
          const SizedBox(height: 14), _Section(title: 'Symptoms', icon: Icons.sick_outlined, children: _list('symptoms').take(8).map((s) => _Line(title: '${s['symptom']} • severity ${s['severity']}/10', sub: s['note']?.toString() ?? '')).toList()),
          const SizedBox(height: 14), _Section(title: 'Care, insurance & consent', icon: Icons.shield_outlined, children: [
            ..._list('care_plans').take(5).map((x) => _Line(title: x['title']?.toString() ?? 'Care plan', sub: x['status']?.toString() ?? '')),
            ..._list('insurance').take(4).map((x) => _Line(title: x['provider']?.toString() ?? 'Insurance', sub: '${x['plan_name'] ?? ''} • ${x['status'] ?? ''}')),
            ..._list('consents').take(4).map((x) => _Line(title: x['consent_type']?.toString() ?? 'Consent', sub: x['granted'] == true ? 'Granted' : 'Not granted')),
          ]),
        ],
      ]),
    );
  }
}

class _PatientHero extends StatelessWidget {
  final Map<String, dynamic> patient;
  const _PatientHero({required this.patient});
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    CircleAvatar(radius: 28, child: Text((patient['full_name']?.toString() ?? 'P').substring(0, 1).toUpperCase())),
    const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(patient['full_name']?.toString() ?? 'Patient', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 5), Text('${patient['patient_code']} • ${patient['sex'] ?? '—'} • Blood ${patient['blood_group'] ?? '—'}'), const SizedBox(height: 10), Wrap(spacing: 8, runSpacing: 8, children: [_Tag('Allergies: ${patient['allergies'] ?? 'not recorded'}'), _Tag('Conditions: ${patient['conditions'] ?? 'not recorded'}')])]))
  ])));
}

class _Tag extends StatelessWidget { final String text; const _Tag(this.text); @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(999)), child: Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600))); }
class _Section extends StatelessWidget { final String title; final IconData icon; final List<Widget> children; const _Section({required this.title, required this.icon, required this.children}); @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children:[Icon(icon, size:20), const SizedBox(width:8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))]), const SizedBox(height: 12), if(children.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No records yet.')) else ...children]))); }
class _Line extends StatelessWidget { final String title; final String sub; const _Line({required this.title, required this.sub}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(13)), child: Row(children: [const Icon(Icons.chevron_right_rounded, size:18), const SizedBox(width:6), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)), if(sub.isNotEmpty) Text(sub, maxLines:2, overflow:TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF718096), fontSize: 10.5))]))]))); }
