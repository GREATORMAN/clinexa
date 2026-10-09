import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

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

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final r = await Api.dio.get('/api/v1/patients', queryParameters: search.text.trim().isEmpty ? null : {'q': search.text.trim()});
      if (mounted) setState(() => data = List<dynamic>.from(r.data));
    } catch (e) { if (mounted) setState(() => error = Api.errorMessage(e)); }
    finally { if (mounted) setState(() => loading = false); }
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
    final meds = TextEditingController();
    final saved = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Add patient'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name *')),
        const SizedBox(height: 10), TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 10), TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        const SizedBox(height: 10), Row(children: [Expanded(child: TextField(controller: sex, decoration: const InputDecoration(labelText: 'Sex'))), const SizedBox(width: 10), Expanded(child: TextField(controller: blood, decoration: const InputDecoration(labelText: 'Blood group')))]),
        const SizedBox(height: 10), TextField(controller: emergency, decoration: const InputDecoration(labelText: 'Emergency contact')),
        const SizedBox(height: 10), TextField(controller: allergies, maxLines: 2, decoration: const InputDecoration(labelText: 'Allergies')),
        const SizedBox(height: 10), TextField(controller: conditions, maxLines: 2, decoration: const InputDecoration(labelText: 'Existing conditions')),
        const SizedBox(height: 10), TextField(controller: meds, maxLines: 2, decoration: const InputDecoration(labelText: 'Current medications')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save patient'))],
    ));
    if (saved != true || name.text.trim().length < 2) return;
    try {
      await Api.dio.post('/api/v1/patients', data: {
        'full_name': name.text.trim(), 'phone': emptyToNull(phone.text), 'email': emptyToNull(email.text), 'sex': emptyToNull(sex.text),
        'blood_group': emptyToNull(blood.text), 'emergency_contact': emptyToNull(emergency.text), 'allergies': emptyToNull(allergies.text),
        'conditions': emptyToNull(conditions.text), 'current_medications': emptyToNull(meds.text),
      });
      if (mounted) showMessage(context, 'Patient created.');
      await load();
    } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  String? emptyToNull(String value) => value.trim().isEmpty ? null : value.trim();

  Future<void> addVitals(Map<String, dynamic> patient) async {
    final sys = TextEditingController(); final dia = TextEditingController(); final hr = TextEditingController();
    final temp = TextEditingController(); final spo2 = TextEditingController(); final weight = TextEditingController(); final height = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Record vitals — ${patient['full_name']}'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [Expanded(child: TextField(controller: sys, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Systolic'))), const SizedBox(width: 8), Expanded(child: TextField(controller: dia, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Diastolic')))]),
        const SizedBox(height: 8), Row(children: [Expanded(child: TextField(controller: hr, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Heart rate'))), const SizedBox(width: 8), Expanded(child: TextField(controller: spo2, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'SpO₂')))]),
        const SizedBox(height: 8), Row(children: [Expanded(child: TextField(controller: temp, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Temperature °C'))), const SizedBox(width: 8), Expanded(child: TextField(controller: weight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Weight kg')))]),
        const SizedBox(height: 8), TextField(controller: height, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Height cm')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save vitals'))],
    ));
    if (ok != true) return;
    double? n(String s) => double.tryParse(s.trim());
    try {
      await Api.dio.post('/api/v1/patients/${patient['id']}/vitals', data: {
        'systolic': n(sys.text), 'diastolic': n(dia.text), 'heart_rate': n(hr.text), 'temperature_c': n(temp.text),
        'spo2': n(spo2.text), 'weight_kg': n(weight.text), 'height_cm': n(height.text), 'source': 'clinician_entered',
      });
      if (mounted) showMessage(context, 'Vitals saved.');
    } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  Future<void> showTimeline(Map<String, dynamic> patient) async {
    try {
      final r = await Api.dio.get('/api/v1/patients/${patient['id']}/timeline');
      final rows = List<dynamic>.from(r.data);
      if (!mounted) return;
      await showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Text('${patient['full_name']} — timeline'),
        content: SizedBox(width: 600, height: 430, child: rows.isEmpty ? const Center(child: Text('No clinical events yet.')) : ListView.separated(
          itemCount: rows.length, separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, i) { final x = Map<String, dynamic>.from(rows[i]); return ListTile(leading: const Icon(Icons.timeline), title: Text((x['summary'] ?? x['type']).toString()), subtitle: Text('${x['type']} • ${x['at'] ?? ''}')); },
        )),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  @override
  Widget build(BuildContext context) => SectionPage(
    title: 'Patients', subtitle: 'Register, search, review timeline and record vitals',
    actions: [IconButton(tooltip: 'Refresh', onPressed: load, icon: const Icon(Icons.refresh)), FilledButton.icon(onPressed: addPatient, icon: const Icon(Icons.person_add_alt_1), label: const Text('Add'))],
    child: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(18), children: [
      TextField(controller: search, onSubmitted: (_) => load(), decoration: InputDecoration(labelText: 'Search patients', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(onPressed: load, icon: const Icon(Icons.arrow_forward)))),
      const SizedBox(height: 14),
      if (loading) const LinearProgressIndicator(),
      if (error != null) ...[const SizedBox(height: 10), ErrorCard(error!)],
      const SizedBox(height: 10),
      Card(child: Column(children: [
        for (final raw in data) Builder(builder: (_) {
          final p = Map<String, dynamic>.from(raw);
          return ListTile(
            leading: CircleAvatar(child: Text((p['full_name']?.toString().isNotEmpty ?? false) ? p['full_name'].toString()[0].toUpperCase() : 'P')),
            title: Text(p['full_name']?.toString() ?? 'Patient'),
            subtitle: Text('${p['patient_code'] ?? ''}${p['phone'] != null ? ' • ${p['phone']}' : ''}${p['blood_group'] != null ? ' • ${p['blood_group']}' : ''}'),
            trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'timeline') showTimeline(p); if (v == 'vitals') addVitals(p); }, itemBuilder: (_) => const [PopupMenuItem(value: 'timeline', child: Text('View timeline')), PopupMenuItem(value: 'vitals', child: Text('Record vitals'))]),
            onTap: () => showTimeline(p),
          );
        }),
        if (data.isEmpty && !loading) const Padding(padding: EdgeInsets.all(28), child: Text('No patients found. Tap Add to register one.')),
      ])),
    ])),
  );
}

