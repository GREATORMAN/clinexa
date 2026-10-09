import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class RecordsPage extends StatefulWidget { const RecordsPage({super.key}); @override State<RecordsPage> createState() => _RecordsPageState(); }

class _RecordsPageState extends State<RecordsPage> {
  List<dynamic> patients = []; List<dynamic> doctors = [];
  List<dynamic> encounters = []; List<dynamic> prescriptions = []; List<dynamic> labs = []; List<dynamic> vitals = [];
  String? patientId; String? error; bool loading = false;
  @override void initState() { super.initState(); bootstrap(); }

  Future<void> bootstrap() async {
    try {
      final r = await Future.wait([Api.dio.get('/api/v1/patients'), Api.dio.get('/api/v1/doctors')]);
      patients = List.from(r[0].data); doctors = List.from(r[1].data);
      if (patients.isNotEmpty) patientId = patients.first['id'].toString();
      if (mounted) setState(() {});
      await loadRecords();
    } catch (e) { if (mounted) setState(() => error = Api.errorMessage(e)); }
  }

  Future<void> loadRecords() async {
    if (patientId == null) return;
    setState(() { loading = true; error = null; });
    try {
      final r = await Future.wait([
        Api.dio.get('/api/v1/patients/$patientId/encounters'),
        Api.dio.get('/api/v1/patients/$patientId/prescriptions'),
        Api.dio.get('/api/v1/patients/$patientId/labs'),
        Api.dio.get('/api/v1/patients/$patientId/vitals'),
      ]);
      if (mounted) setState(() { encounters = List.from(r[0].data); prescriptions = List.from(r[1].data); labs = List.from(r[2].data); vitals = List.from(r[3].data); });
    } catch (e) { if (mounted) setState(() => error = Api.errorMessage(e)); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> addEncounter() async {
    if (patientId == null) return;
    final chief = TextEditingController(); final history = TextEditingController(); final exam = TextEditingController(); final assessment = TextEditingController(); final plan = TextEditingController(); final follow = TextEditingController();
    String? doctorId = doctors.isNotEmpty ? doctors.first['id'].toString() : null;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: Text('New consultation note'),
      content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 580), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (doctors.isNotEmpty) DropdownButtonFormField<String>(isExpanded: true, value: doctorId, decoration: InputDecoration(labelText: 'Doctor'), items: doctors.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['full_name'].toString()))).toList(), onChanged: (v) => setLocal(() => doctorId = v)),
        SizedBox(height: 10), TextField(controller: chief, maxLines: 2, decoration: InputDecoration(labelText: 'Chief complaint')),
        SizedBox(height: 10), TextField(controller: history, maxLines: 3, decoration: InputDecoration(labelText: 'History')),
        SizedBox(height: 10), TextField(controller: exam, maxLines: 3, decoration: InputDecoration(labelText: 'Examination')),
        SizedBox(height: 10), TextField(controller: assessment, maxLines: 3, decoration: InputDecoration(labelText: 'Assessment recorded by clinician')),
        SizedBox(height: 10), TextField(controller: plan, maxLines: 3, decoration: InputDecoration(labelText: 'Plan')),
        SizedBox(height: 10), TextField(controller: follow, maxLines: 2, decoration: InputDecoration(labelText: 'Follow-up')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Save note'))],
    )));
    if (ok != true) return;
    try { await Api.dio.post('/api/v1/encounters', data: {'patient_id': patientId, 'doctor_id': doctorId, 'chief_complaint': nullIfEmpty(chief.text), 'history': nullIfEmpty(history.text), 'examination': nullIfEmpty(exam.text), 'assessment': nullIfEmpty(assessment.text), 'plan': nullIfEmpty(plan.text), 'follow_up': nullIfEmpty(follow.text)}); if (mounted) showMessage(context, 'Clinical note saved.'); await loadRecords(); } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  Future<void> addPrescription() async {
    if (patientId == null || doctors.isEmpty) { showMessage(context, 'A doctor is required before creating a prescription.'); return; }
    String doctorId = doctors.first['id'].toString(); final med = TextEditingController(); final strength = TextEditingController(); final form = TextEditingController(); final freq = TextEditingController(); final duration = TextEditingController(); final instructions = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: Text('Create prescription'),
      content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 540), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Prescription details must be entered and confirmed by an authorized clinician.'), SizedBox(height: 12),
        DropdownButtonFormField<String>(isExpanded: true, value: doctorId, decoration: InputDecoration(labelText: 'Prescribing doctor'), items: doctors.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['full_name'].toString()))).toList(), onChanged: (v) => setLocal(() => doctorId = v ?? doctorId)),
        SizedBox(height: 10), TextField(controller: med, decoration: InputDecoration(labelText: 'Medication *')),
        SizedBox(height: 10), Row(children: [Expanded(child: TextField(controller: strength, decoration: InputDecoration(labelText: 'Strength'))), SizedBox(width: 8), Expanded(child: TextField(controller: form, decoration: InputDecoration(labelText: 'Form')))]),
        SizedBox(height: 10), Row(children: [Expanded(child: TextField(controller: freq, decoration: InputDecoration(labelText: 'Frequency'))), SizedBox(width: 8), Expanded(child: TextField(controller: duration, decoration: InputDecoration(labelText: 'Duration')))]),
        SizedBox(height: 10), TextField(controller: instructions, maxLines: 3, decoration: InputDecoration(labelText: 'Instructions')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Confirm prescription'))],
    )));
    if (ok != true || med.text.trim().isEmpty) return;
    try { await Api.dio.post('/api/v1/prescriptions', data: {'patient_id': patientId, 'doctor_id': doctorId, 'medication_name': med.text.trim(), 'strength': nullIfEmpty(strength.text), 'form': nullIfEmpty(form.text), 'frequency': nullIfEmpty(freq.text), 'duration': nullIfEmpty(duration.text), 'instructions': nullIfEmpty(instructions.text)}); if (mounted) showMessage(context, 'Prescription saved.'); await loadRecords(); } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  Future<void> addLab() async {
    if (patientId == null) return;
    final test = TextEditingController(); final value = TextEditingController(); final unit = TextEditingController(); final range = TextEditingController(); final lab = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Add lab result'),
      content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 520), child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: test, decoration: InputDecoration(labelText: 'Test name *')), SizedBox(height: 10),
        Row(children: [Expanded(child: TextField(controller: value, decoration: InputDecoration(labelText: 'Result *'))), SizedBox(width: 8), Expanded(child: TextField(controller: unit, decoration: InputDecoration(labelText: 'Unit')))]),
        SizedBox(height: 10), TextField(controller: range, decoration: InputDecoration(labelText: 'Reference range supplied by lab')),
        SizedBox(height: 10), TextField(controller: lab, decoration: InputDecoration(labelText: 'Laboratory')),
        SizedBox(height: 10), Text('The app stores the supplied value; it does not diagnose disease from this result.'),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Save result'))],
    ));
    if (ok != true || test.text.trim().isEmpty || value.text.trim().isEmpty) return;
    try { await Api.dio.post('/api/v1/labs', data: {'patient_id': patientId, 'test_name': test.text.trim(), 'result_value': value.text.trim(), 'unit': nullIfEmpty(unit.text), 'reference_range': nullIfEmpty(range.text), 'laboratory': nullIfEmpty(lab.text), 'verified': true}); if (mounted) showMessage(context, 'Lab result saved.'); await loadRecords(); } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  Future<void> addVitals() async {
    if (patientId == null) return;
    final sys = TextEditingController(); final dia = TextEditingController(); final hr = TextEditingController(); final spo2 = TextEditingController(); final temp = TextEditingController(); final weight = TextEditingController(); final height = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: Text('Record vitals'), content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 480), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [Expanded(child: TextField(controller: sys, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Systolic'))), SizedBox(width: 8), Expanded(child: TextField(controller: dia, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Diastolic')))]),
      SizedBox(height: 8), Row(children: [Expanded(child: TextField(controller: hr, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Heart rate'))), SizedBox(width: 8), Expanded(child: TextField(controller: spo2, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'SpO₂')))]),
      SizedBox(height: 8), Row(children: [Expanded(child: TextField(controller: temp, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Temperature °C'))), SizedBox(width: 8), Expanded(child: TextField(controller: weight, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Weight kg')))]),
      SizedBox(height: 8), TextField(controller: height, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Height cm')),
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Save'))]));
    if (ok != true) return; double? n(String v) => double.tryParse(v.trim());
    try { await Api.dio.post('/api/v1/patients/$patientId/vitals', data: {'systolic': n(sys.text), 'diastolic': n(dia.text), 'heart_rate': n(hr.text), 'spo2': n(spo2.text), 'temperature_c': n(temp.text), 'weight_kg': n(weight.text), 'height_cm': n(height.text), 'source': 'clinician_entered'}); if (mounted) showMessage(context, 'Vitals saved.'); await loadRecords(); } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  String? nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  @override
  Widget build(BuildContext context) => DefaultTabController(length: 4, child: SectionPage(
    title: 'Clinical Records', subtitle: 'Consultations, prescriptions, labs and vitals',
    actions: [IconButton(onPressed: loadRecords, icon: Icon(Icons.refresh))],
    child: patients.isEmpty ? Center(child: Text('Add a patient first.')) : Column(children: [
      Padding(padding: EdgeInsets.all(14), child: DropdownButtonFormField<String>(isExpanded: true, 
        value: patientId, decoration: InputDecoration(labelText: 'Patient'),
        items: patients.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['full_name'].toString()))).toList(),
        onChanged: (v) async { setState(() => patientId = v); await loadRecords(); },
      )),
      if (loading) LinearProgressIndicator(),
      if (error != null) Padding(padding: EdgeInsets.symmetric(horizontal: 14), child: ErrorCard(error!)),
      TabBar(isScrollable: true, tabs: [Tab(text: 'Encounters'), Tab(text: 'Prescriptions'), Tab(text: 'Labs'), Tab(text: 'Vitals')]),
      Expanded(child: TabBarView(children: [
        _RecordList(
          rows: encounters,
          empty: 'No encounters.',
          addLabel: 'New clinical note',
          onAdd: addEncounter,
          title: (x) => x['chief_complaint']?.toString() ?? 'Encounter',
          subtitle: (x) => "${x['assessment'] ?? ''}\n${x['created_at'] ?? ''}",
        ),
        _RecordList(
          rows: prescriptions,
          empty: 'No prescriptions.',
          addLabel: 'Create prescription',
          onAdd: addPrescription,
          title: (x) => x['medication_name']?.toString() ?? 'Medication',
          subtitle: (x) => "${x['strength'] ?? ''} ${x['frequency'] ?? ''} • ${x['duration'] ?? ''}\n${x['instructions'] ?? ''}",
        ),
        _RecordList(rows: labs, empty: 'No lab results.', addLabel: 'Add lab result', onAdd: addLab, title: (x) => '${x['test_name'] ?? ''}: ${x['result_value'] ?? ''} ${x['unit'] ?? ''}', subtitle: (x) => 'Reference: ${x['reference_range'] ?? 'Not supplied'} • ${x['laboratory'] ?? ''}'),
        _RecordList(rows: vitals, empty: 'No vitals.', addLabel: 'Record vitals', onAdd: addVitals, title: (x) => 'BP ${x['systolic'] ?? '—'}/${x['diastolic'] ?? '—'} • HR ${x['heart_rate'] ?? '—'}', subtitle: (x) => 'SpO₂ ${x['spo2'] ?? '—'} • Temp ${x['temperature_c'] ?? '—'} • ${x['observed_at'] ?? ''}'),
      ])),
    ]),
  ));
}

class _RecordList extends StatelessWidget {
  final List<dynamic> rows; final String empty; final String addLabel; final VoidCallback onAdd; final String Function(Map<String,dynamic>) title; final String Function(Map<String,dynamic>) subtitle;
  const _RecordList({required this.rows, required this.empty, required this.addLabel, required this.onAdd, required this.title, required this.subtitle});
  @override Widget build(BuildContext context) => ListView(padding: EdgeInsets.all(14), children: [
    Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: onAdd, icon: Icon(Icons.add), label: Text(addLabel))), SizedBox(height: 10),
    Card(child: Column(children: [for (final raw in rows) Builder(builder: (_) { final x = Map<String,dynamic>.from(raw); return ListTile(title: Text(title(x)), subtitle: Text(subtitle(x))); }), if (rows.isEmpty) Padding(padding: EdgeInsets.all(28), child: Text(empty))])),
  ]);
}

