import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';
import '../advanced/patient_360_page.dart';

class PatientsPage extends StatefulWidget {
  const PatientsPage({super.key});
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
    debounce = Timer(const Duration(milliseconds: 350), load);
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
        title: const Row(children: [Icon(Icons.person_add_alt_1_rounded, color: ClinexaTheme.primary), SizedBox(width: 9), Text('Register patient')]),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name *', prefixIcon: Icon(Icons.person_outline_rounded))),
              const SizedBox(height: 11),
              Row(children: [
                Expanded(child: TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)))),
              ]),
              const SizedBox(height: 11),
              Row(children: [
                Expanded(child: TextField(controller: sex, decoration: const InputDecoration(labelText: 'Sex'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: blood, decoration: const InputDecoration(labelText: 'Blood group'))),
              ]),
              const SizedBox(height: 11),
              TextField(controller: emergency, decoration: const InputDecoration(labelText: 'Emergency contact', prefixIcon: Icon(Icons.emergency_outlined))),
              const SizedBox(height: 11),
              TextField(controller: allergies, maxLines: 2, decoration: const InputDecoration(labelText: 'Known allergies')),
              const SizedBox(height: 11),
              TextField(controller: conditions, maxLines: 2, decoration: const InputDecoration(labelText: 'Existing conditions')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.check_rounded), label: const Text('Create patient')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient registered successfully.')));
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
              Expanded(child: TextField(controller: sys, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Systolic'))),
              const SizedBox(width: 9),
              Expanded(child: TextField(controller: dia, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Diastolic'))),
            ]),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: TextField(controller: hr, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Heart rate'))),
              const SizedBox(width: 9),
              Expanded(child: TextField(controller: spo2, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'SpO₂'))),
            ]),
            const SizedBox(height: 9),
            Row(children: [
              Expanded(child: TextField(controller: temp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Temperature °C'))),
              const SizedBox(width: 9),
              Expanded(child: TextField(controller: weight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight kg'))),
              const SizedBox(width: 9),
              Expanded(child: TextField(controller: height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height cm'))),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save observations')),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vitals saved.')));
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
            eyebrow: 'Care directory',
            title: 'Patients',
            subtitle: 'Search the longitudinal record, register a patient and jump directly into care actions without losing context.',
            actions: [
              OutlinedButton.icon(onPressed: load, icon: const Icon(Icons.refresh_rounded), label: const Text('Refresh')),
              FilledButton.icon(onPressed: addPatient, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Register patient')),
            ],
          ),
          const SizedBox(height: 18),
          CxSurface(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Expanded(child: TextField(
                controller: search,
                onChanged: searchChanged,
                onSubmitted: (_) => load(),
                decoration: const InputDecoration(labelText: 'Search name, patient ID or phone', prefixIcon: Icon(Icons.search_rounded)),
              )),
              if (width >= 620) ...[
                const SizedBox(width: 10),
                CxStatusChip(label: '${data.length} visible', icon: Icons.people_outline_rounded),
              ],
            ]),
          ),
          if (error != null) ...[const SizedBox(height: 12), CxErrorBanner(message: error!, onRetry: load)],
          const SizedBox(height: 14),
          if (loading) ...List.generate(5, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: CxSkeleton(height: 86))),
          if (!loading && data.isEmpty) const CxSurface(child: CxEmptyState(icon: Icons.people_outline_rounded, title: 'No patients found', message: 'Adjust the search or register a fictional/demo patient for this development workspace.')),
          if (!loading) LayoutBuilder(builder: (_, c) {
            final cols = c.maxWidth >= 1120 ? 3 : c.maxWidth >= 700 ? 2 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: cols == 1 ? 2.25 : 1.48),
              itemBuilder: (_, i) => _PatientCard(
                patient: Map<String, dynamic>.from(data[i] as Map),
                onOpen: open360,
                onVitals: addVitals,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final Map<String, dynamic> patient;
  final void Function(Map<String, dynamic>) onOpen;
  final Future<void> Function(Map<String, dynamic>) onVitals;
  const _PatientCard({required this.patient, required this.onOpen, required this.onVitals});

  @override
  Widget build(BuildContext context) {
    final name = patient['full_name']?.toString() ?? 'Patient';
    final initial = name.isEmpty ? 'P' : name[0].toUpperCase();
    return CxSurface(
      onTap: () => onOpen(patient),
      elevated: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(gradient: const LinearGradient(colors: [ClinexaTheme.primary, ClinexaTheme.primaryBright]), borderRadius: BorderRadius.circular(16)), child: Center(child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)))),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 3),
            Text(patient['patient_code']?.toString() ?? 'No patient code', style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ])),
          const Icon(Icons.arrow_outward_rounded, color: ClinexaTheme.muted, size: 18),
        ]),
        const Spacer(),
        Wrap(spacing: 7, runSpacing: 7, children: [
          if (patient['blood_group'] != null) CxStatusChip(label: 'Blood ${patient['blood_group']}', color: ClinexaTheme.emergency, icon: Icons.bloodtype_outlined),
          if (patient['phone'] != null) CxStatusChip(label: patient['phone'].toString(), color: const Color(0xFF4567C6), icon: Icons.phone_outlined),
        ]),
        const SizedBox(height: 10),
        Text('Allergies  ${patient['allergies'] ?? 'not recorded'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5)),
        const SizedBox(height: 4),
        Text('Conditions  ${patient['conditions'] ?? 'not recorded'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5)),
        const SizedBox(height: 11),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => onVitals(patient), icon: const Icon(Icons.monitor_heart_outlined, size: 17), label: const Text('Vitals'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton(onPressed: () => onOpen(patient), child: const Text('Open 360°'))),
        ]),
      ]),
    );
  }
}
