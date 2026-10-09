import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';
import '../advanced/patient_360_page.dart';

class PatientsPage extends StatefulWidget {
  PatientsPage({super.key});
  @override
  State<PatientsPage> createState() => _PatientsPageState();
}

class _PatientsPageState extends State<PatientsPage> {
  final search = TextEditingController();
  List<dynamic> data = [];
  bool loading = false;
  String? error;
  Timer? debounce;

  @override
  void initState() { super.initState(); load(); }

  @override
  void dispose() { debounce?.cancel(); search.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final q = search.text.trim();
      final r = await Api.dio.get('/api/v1/patients', queryParameters: q.isEmpty ? null : {'q': q});
      if (mounted) setState(() => data = List<dynamic>.from(r.data));
    } catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void searchChanged(String _) {
    debounce?.cancel();
    debounce = Timer(Duration(milliseconds: 350), load);
  }

  Future<void> addPatient() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final sex = TextEditingController();
    final blood = TextEditingController();
    final emergency = TextEditingController();
    final allergies = TextEditingController();
    final conditions = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [Icon(Icons.person_add_alt_1_rounded, color: ClinexaTheme.primary), SizedBox(width: 9), Text('Register patient')]),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: InputDecoration(labelText: 'Full name *', prefixIcon: Icon(Icons.person_outline_rounded))),
              SizedBox(height: 11),
              Row(children: [
                Expanded(child: TextField(controller: phone, decoration: InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)))),
                SizedBox(width: 10),
                Expanded(child: TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)))),
              ]),
              SizedBox(height: 11),
              Row(children: [
                Expanded(child: TextField(controller: sex, decoration: InputDecoration(labelText: 'Sex'))),
                SizedBox(width: 10),
                Expanded(child: TextField(controller: blood, decoration: InputDecoration(labelText: 'Blood group'))),
              ]),
              SizedBox(height: 11),
              TextField(controller: emergency, decoration: InputDecoration(labelText: 'Emergency contact', prefixIcon: Icon(Icons.emergency_outlined))),
              SizedBox(height: 11),
              TextField(controller: allergies, maxLines: 2, decoration: InputDecoration(labelText: 'Known allergies')),
              SizedBox(height: 11),
              TextField(controller: conditions, maxLines: 2, decoration: InputDecoration(labelText: 'Existing conditions')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: Icon(Icons.check_rounded), label: Text('Create patient')),
        ],
      ),
    );
    if (saved != true || name.text.trim().length < 2) return;
    try {
      await Api.dio.post('/api/v1/patients', data: {
        'full_name': name.text.trim(),
        'phone': _empty(phone.text),
        'email': _empty(email.text),
        'sex': _empty(sex.text),
        'blood_group': _empty(blood.text),
        'emergency_contact': _empty(emergency.text),
        'allergies': _empty(allergies.text),
        'conditions': _empty(conditions.text),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Patient registered successfully.')));
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  String? _empty(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> addVitals(Map<String, dynamic> patient) async {
    final sys = TextEditingController();
    final dia = TextEditingController();
    final hr = TextEditingController();
    final temp = TextEditingController();
    final spo2 = TextEditingController();
    final weight = TextEditingController();
    final height = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Vitals • ${patient['full_name']}'),
        content: SizedBox(
          width: 520,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: TextField(controller: sys, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Systolic'))),
              SizedBox(width: 9),
              Expanded(child: TextField(controller: dia, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Diastolic'))),
            ]),
            SizedBox(height: 9),
            Row(children: [
              Expanded(child: TextField(controller: hr, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Heart rate'))),
              SizedBox(width: 9),
              Expanded(child: TextField(controller: spo2, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'SpO₂'))),
            ]),
            SizedBox(height: 9),
            Row(children: [
              Expanded(child: TextField(controller: temp, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Temperature °C'))),
              SizedBox(width: 9),
              Expanded(child: TextField(controller: weight, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Weight kg'))),
              SizedBox(width: 9),
              Expanded(child: TextField(controller: height, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Height cm'))),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Save observations')),
        ],
      ),
    );
    if (ok != true) return;
    double? n(String s) => double.tryParse(s.trim());
    try {
      await Api.dio.post('/api/v1/patients/${patient['id']}/vitals', data: {
        'systolic': n(sys.text), 'diastolic': n(dia.text), 'heart_rate': n(hr.text),
        'temperature_c': n(temp.text), 'spo2': n(spo2.text), 'weight_kg': n(weight.text),
        'height_cm': n(height.text), 'source': 'clinician_entered',
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vitals saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  void open360(Map<String, dynamic> patient) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Patient360Page(initialPatientId: patient['id']?.toString())));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 700 ? 16.0 : 28.0;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 26, pad, 38),
        children: [
          CxPageHeader(
            icon: Icons.people_alt_rounded,
            eyebrow: 'Care directory',
            title: 'Patients',
            subtitle: 'Search the longitudinal record, register a patient and jump directly into care actions without losing context.',
            actions: [
              OutlinedButton.icon(onPressed: load, icon: Icon(Icons.refresh_rounded), label: Text('Refresh')),
              FilledButton.icon(onPressed: addPatient, icon: Icon(Icons.person_add_alt_1_rounded), label: Text('Register patient')),
            ],
          ),
          SizedBox(height: 18),
          CxSurface(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Expanded(child: TextField(
                controller: search,
                onChanged: searchChanged,
                onSubmitted: (_) => load(),
                decoration: InputDecoration(labelText: 'Search name, patient ID or phone', prefixIcon: Icon(Icons.search_rounded)),
              )),
              if (width >= 620) ...[
                SizedBox(width: 10),
                CxStatusChip(label: '${data.length} visible', icon: Icons.people_outline_rounded),
              ],
            ]),
          ),
          if (error != null) ...[SizedBox(height: 12), CxErrorBanner(message: error!, onRetry: load)],
          SizedBox(height: 14),
          if (loading) ...List.generate(5, (_) => Padding(padding: EdgeInsets.only(bottom: 10), child: CxSkeleton(height: 86))),
          if (!loading && data.isEmpty) CxSurface(child: CxEmptyState(icon: Icons.people_outline_rounded, title: 'No patients found', message: 'Adjust the search or register a fictional/demo patient for this development workspace.')),
          if (!loading) CxAdaptiveGrid(
            minItemWidth: 330,
            maxColumns: 3,
            children: data.map((raw) => _PatientCard(
              patient: Map<String, dynamic>.from(raw as Map),
              onOpen: open360,
              onVitals: addVitals,
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  final void Function(Map<String, dynamic>) onOpen;
  final Future<void> Function(Map<String, dynamic>) onVitals;
  _PatientCard({required this.patient, required this.onOpen, required this.onVitals});

  @override
  Widget build(BuildContext context) {
    final name = patient['full_name']?.toString() ?? 'Patient';
    final initial = name.isEmpty ? 'P' : name[0].toUpperCase();
    return CxSurface(
      onTap: () => onOpen(patient),
      elevated: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(gradient: LinearGradient(colors: [ClinexaTheme.primary, ClinexaTheme.primaryBright]), borderRadius: BorderRadius.circular(16)), child: Center(child: Text(initial, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)))),
          SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            SizedBox(height: 3),
            Text(patient['patient_code']?.toString() ?? 'No patient code', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ])),
          Icon(Icons.arrow_outward_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
        ]),
        SizedBox(height: 16),
        Wrap(spacing: 7, runSpacing: 7, children: [
          if (patient['blood_group'] != null) CxStatusChip(label: 'Blood ${patient['blood_group']}', color: ClinexaTheme.emergency, icon: Icons.bloodtype_outlined),
          if (patient['phone'] != null) CxStatusChip(label: patient['phone'].toString(), color: Color(0xFF4567C6), icon: Icons.phone_outlined),
        ]),
        SizedBox(height: 10),
        Text('Allergies  ${patient['allergies'] ?? 'not recorded'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5)),
        SizedBox(height: 4),
        Text('Conditions  ${patient['conditions'] ?? 'not recorded'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5)),
        SizedBox(height: 11),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => onVitals(patient), icon: Icon(Icons.monitor_heart_outlined, size: 17), label: Text('Vitals'))),
          SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: () => onOpen(patient), child: Text('Open 360°'))),
        ]),
      ]),
    );
  }
}
