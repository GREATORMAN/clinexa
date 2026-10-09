import 'package:flutter/material.dart';

import '../../core/network/api.dart';

class DoctorConsultationPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String patientCode;
  final String doctorId;
  final String? appointmentId;
  final String? appointmentStatus;

  const DoctorConsultationPage({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.patientCode,
    required this.doctorId,
    this.appointmentId,
    this.appointmentStatus,
  });

  @override
  State<DoctorConsultationPage> createState() => _DoctorConsultationPageState();
}

class _DoctorConsultationPageState extends State<DoctorConsultationPage> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 4, vsync: this);
    load();
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final r = await Api.dio.get('/api/v1/advanced/patients/${widget.patientId}/360');
      if (mounted) setState(() => data = Map<String, dynamic>.from(r.data as Map));
    } catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<dynamic> list(String key) => List<dynamic>.from(data?[key] as List? ?? const []);

  Future<void> updateAppointment(String status) async {
    if (widget.appointmentId == null) return;
    try {
      await Api.dio.patch('/api/v1/appointments/${widget.appointmentId}/status', data: {'status': status});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Appointment marked ${status.replaceAll('_', ' ')}.')));
    } catch (e) {
      if (mounted) _message(Api.errorMessage(e));
    }
  }

  Future<void> recordEncounter() async {
    final chief = TextEditingController();
    final history = TextEditingController();
    final examination = TextEditingController();
    final assessment = TextEditingController();
    final plan = TextEditingController();
    final followUp = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record consultation note'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(children: [
              TextField(controller: chief, decoration: const InputDecoration(labelText: 'Chief complaint'), maxLines: 2),
              const SizedBox(height: 10),
              TextField(controller: history, decoration: const InputDecoration(labelText: 'History'), maxLines: 3),
              const SizedBox(height: 10),
              TextField(controller: examination, decoration: const InputDecoration(labelText: 'Examination'), maxLines: 3),
              const SizedBox(height: 10),
              TextField(controller: assessment, decoration: const InputDecoration(labelText: 'Assessment recorded by clinician'), maxLines: 3),
              const SizedBox(height: 10),
              TextField(controller: plan, decoration: const InputDecoration(labelText: 'Plan'), maxLines: 3),
              const SizedBox(height: 10),
              TextField(controller: followUp, decoration: const InputDecoration(labelText: 'Follow-up'), maxLines: 2),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save clinical note')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Api.dio.post('/api/v1/encounters', data: {
        'patient_id': widget.patientId,
        'doctor_id': widget.doctorId,
        if (widget.appointmentId != null) 'appointment_id': widget.appointmentId,
        'chief_complaint': chief.text.trim().isEmpty ? null : chief.text.trim(),
        'history': history.text.trim().isEmpty ? null : history.text.trim(),
        'examination': examination.text.trim().isEmpty ? null : examination.text.trim(),
        'assessment': assessment.text.trim().isEmpty ? null : assessment.text.trim(),
        'plan': plan.text.trim().isEmpty ? null : plan.text.trim(),
        'follow_up': followUp.text.trim().isEmpty ? null : followUp.text.trim(),
      });
      await load();
      if (mounted) _message('Consultation note saved to the patient timeline.');
    } catch (e) {
      if (mounted) _message(Api.errorMessage(e));
    }
  }

  Future<void> prescribe() async {
    final medicine = TextEditingController();
    final strength = TextEditingController();
    final form = TextEditingController();
    final frequency = TextEditingController();
    final duration = TextEditingController();
    final instructions = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create electronic prescription'),
        content: SizedBox(
          width: 540,
          child: SingleChildScrollView(child: Column(children: [
            TextField(controller: medicine, decoration: const InputDecoration(labelText: 'Medicine name *')),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: TextField(controller: strength, decoration: const InputDecoration(labelText: 'Strength'))), const SizedBox(width: 10), Expanded(child: TextField(controller: form, decoration: const InputDecoration(labelText: 'Form')))]),
            const SizedBox(height: 10),
            TextField(controller: frequency, decoration: const InputDecoration(labelText: 'Frequency')),
            const SizedBox(height: 10),
            TextField(controller: duration, decoration: const InputDecoration(labelText: 'Duration')),
            const SizedBox(height: 10),
            TextField(controller: instructions, decoration: const InputDecoration(labelText: 'Instructions'), maxLines: 2),
            const SizedBox(height: 12),
            const _SafetyNote(text: 'Clinexa does not generate or alter the medicine or dose. The clinician is explicitly entering and confirming this prescription.'),
          ])),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm prescription'))],
      ),
    );
    if (confirmed != true || medicine.text.trim().isEmpty) return;
    try {
      await Api.dio.post('/api/v1/prescriptions', data: {
        'patient_id': widget.patientId,
        'doctor_id': widget.doctorId,
        'medication_name': medicine.text.trim(),
        'strength': strength.text.trim().isEmpty ? null : strength.text.trim(),
        'form': form.text.trim().isEmpty ? null : form.text.trim(),
        'frequency': frequency.text.trim().isEmpty ? null : frequency.text.trim(),
        'duration': duration.text.trim().isEmpty ? null : duration.text.trim(),
        'instructions': instructions.text.trim().isEmpty ? null : instructions.text.trim(),
      });
      await load();
      if (mounted) _message('Prescription saved and added to the patient Medicine Centre.');
    } catch (e) {
      if (mounted) _message(Api.errorMessage(e));
    }
  }

  Future<void> orderLab() async {
    final test = TextEditingController();
    final specimen = TextEditingController();
    String priority = 'routine';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Order laboratory test'),
        content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: test, decoration: const InputDecoration(labelText: 'Test name *')),
          const SizedBox(height: 10),
          TextField(controller: specimen, decoration: const InputDecoration(labelText: 'Specimen (optional)')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(isExpanded: true, initialValue: priority, decoration: const InputDecoration(labelText: 'Priority'), items: const [DropdownMenuItem(value: 'routine', child: Text('Routine')), DropdownMenuItem(value: 'urgent', child: Text('Urgent'))], onChanged: (v) => setLocal(() => priority = v ?? priority)),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Place order'))],
      )),
    );
    if (confirmed != true || test.text.trim().isEmpty) return;
    try {
      await Api.dio.post('/api/v1/advanced/lab-orders', data: {
        'patient_id': widget.patientId,
        'doctor_id': widget.doctorId,
        'test_name': test.text.trim(),
        'priority': priority,
        'specimen': specimen.text.trim().isEmpty ? null : specimen.text.trim(),
      });
      if (mounted) _message('Lab order sent into the laboratory workflow.');
    } catch (e) {
      if (mounted) _message(Api.errorMessage(e));
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final patient = Map<String, dynamic>.from(data?['patient'] as Map? ?? const {});
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.patientName} • consultation'),
        actions: [IconButton(onPressed: load, tooltip: 'Refresh patient record', icon: const Icon(Icons.refresh_rounded))],
        bottom: TabBar(controller: tabs, isScrollable: true, tabs: const [Tab(text: 'Overview'), Tab(text: 'Timeline'), Tab(text: 'Medicines'), Tab(text: 'Labs & documents')]),
      ),
      body: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: const BoxDecoration(color: Color(0xFFF8FAFC), border: Border(bottom: BorderSide(color: Color(0xFFE5EAF0)))),
          child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(widget.patientCode, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (widget.appointmentId != null) ...[
              OutlinedButton.icon(onPressed: () => updateAppointment('in_consultation'), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start visit')),
              OutlinedButton.icon(onPressed: () => updateAppointment('completed'), icon: const Icon(Icons.check_rounded), label: const Text('Complete visit')),
            ],
            FilledButton.icon(onPressed: recordEncounter, icon: const Icon(Icons.edit_note_rounded), label: const Text('Clinical note')),
            FilledButton.tonalIcon(onPressed: prescribe, icon: const Icon(Icons.medication_outlined), label: const Text('Prescribe')),
            FilledButton.tonalIcon(onPressed: orderLab, icon: const Icon(Icons.science_outlined), label: const Text('Order lab')),
          ]),
        ),
        if (loading) const LinearProgressIndicator(),
        if (error != null) Padding(padding: const EdgeInsets.all(12), child: _SafetyNote(text: error!)),
        Expanded(
          child: TabBarView(controller: tabs, children: [
            _overview(patient),
            _timeline(),
            _medicines(),
            _labsAndDocuments(),
          ]),
        ),
      ]),
    );
  }

  Widget _overview(Map<String, dynamic> patient) => ListView(padding: const EdgeInsets.all(16), children: [
    _Section(title: 'Patient summary', children: [
      _KeyValue('Name', patient['full_name']),
      _KeyValue('Patient ID', patient['patient_code']),
      _KeyValue('Blood group', patient['blood_group']),
      _KeyValue('Allergies', patient['allergies'] ?? 'Not recorded'),
      _KeyValue('Conditions', patient['conditions'] ?? 'Not recorded'),
    ]),
    const SizedBox(height: 12),
    _Section(title: 'Recent vitals', children: list('vitals').take(5).map((v) => ListTile(dense: true, leading: const Icon(Icons.monitor_heart_outlined), title: Text('BP ${v['systolic'] ?? '—'}/${v['diastolic'] ?? '—'} • HR ${v['heart_rate'] ?? '—'}'), subtitle: Text('SpO₂ ${v['spo2'] ?? '—'} • Temp ${v['temperature_c'] ?? '—'} • ${v['observed_at'] ?? ''}'))).toList()),
    const SizedBox(height: 12),
    _Section(title: 'Recent symptoms', children: list('symptoms').take(5).map((s) => ListTile(dense: true, leading: const Icon(Icons.sick_outlined), title: Text('${s['symptom'] ?? 'Symptom'} • ${s['severity'] ?? '—'}/10'), subtitle: Text(s['note']?.toString() ?? ''))).toList()),
  ]);

  Widget _timeline() => ListView(padding: const EdgeInsets.all(16), children: [
    _Section(title: 'Clinical encounters', children: list('encounters').map((e) => ExpansionTile(title: Text(e['chief_complaint']?.toString() ?? 'Encounter'), subtitle: Text(e['created_at']?.toString() ?? ''), childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12), children: [
      _KeyValue('History', e['history']), _KeyValue('Examination', e['examination']), _KeyValue('Assessment', e['assessment']), _KeyValue('Plan', e['plan']), _KeyValue('Follow-up', e['follow_up']),
    ])).toList()),
    const SizedBox(height: 12),
    _Section(title: 'Appointments', children: list('appointments').take(12).map((a) => ListTile(dense: true, leading: const Icon(Icons.event_outlined), title: Text('${a['start_at'] ?? ''}'), subtitle: Text('${a['status'] ?? ''} • ${a['reason'] ?? ''}'))).toList()),
  ]);

  Widget _medicines() => ListView(padding: const EdgeInsets.all(16), children: [
    const _SafetyNote(text: 'Only clinician-confirmed or human-verified medicines are shown here. OCR drafts do not become medication records until confirmed.'),
    const SizedBox(height: 12),
    _Section(title: 'Current medicine record', children: list('patient_medications').map((m) => ListTile(dense: true, leading: const Icon(Icons.medication_outlined), title: Text('${m['medication_name'] ?? 'Medicine'} ${m['strength'] ?? ''}'), subtitle: Text('${m['frequency'] ?? ''} • ${m['route'] ?? ''} • ${m['status'] ?? ''}\nSource: ${(m['source_type'] ?? 'record').toString().replaceAll('_', ' ')}'))).toList()),
    const SizedBox(height: 12),
    _Section(title: 'Prescription history', children: list('prescriptions').take(15).map((m) => ListTile(dense: true, leading: const Icon(Icons.receipt_long_outlined), title: Text('${m['medication_name'] ?? 'Medicine'} ${m['strength'] ?? ''}'), subtitle: Text('${m['frequency'] ?? ''} • ${m['duration'] ?? ''}'))).toList()),
  ]);

  Widget _labsAndDocuments() => ListView(padding: const EdgeInsets.all(16), children: [
    _Section(title: 'Laboratory results', children: list('labs').take(20).map((l) => ListTile(dense: true, leading: const Icon(Icons.science_outlined), title: Text(l['test_name']?.toString() ?? 'Lab'), subtitle: Text('${l['result_value'] ?? ''} ${l['unit'] ?? ''} • reference ${l['reference_range'] ?? 'not recorded'}'))).toList()),
    const SizedBox(height: 12),
    _Section(title: 'Documents', children: list('documents').take(20).map((d) => ListTile(dense: true, leading: const Icon(Icons.description_outlined), title: Text(d['original_name']?.toString() ?? 'Document'), subtitle: Text('${d['category'] ?? ''} • ${d['created_at'] ?? ''}'))).toList()),
  ]);
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), const SizedBox(height: 8), if (children.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No records yet.', style: TextStyle(color: Color(0xFF667085)))) else ...children])));
}

class _KeyValue extends StatelessWidget {
  final String label;
  final Object? value;
  const _KeyValue(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Color(0xFF667085), fontWeight: FontWeight.w600))), Expanded(child: Text(value?.toString().isNotEmpty == true ? value.toString() : '—', style: const TextStyle(fontWeight: FontWeight.w600)))]));
}

class _SafetyNote extends StatelessWidget {
  final String text;
  const _SafetyNote({required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF8E8), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF4D58A))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline_rounded, size: 18), const SizedBox(width: 8), Expanded(child: Text(text, style: const TextStyle(fontSize: 11, height: 1.35)))]));
}
