import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class DoctorsPage extends StatefulWidget {
  const DoctorsPage({super.key});
  @override
  State<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends State<DoctorsPage> {
  List<dynamic> data = [];
  List<dynamic> departments = [];
  String? error;
  @override void initState() { super.initState(); load(); }

  Future<void> load() async {
    try {
      final results = await Future.wait([Api.dio.get('/api/v1/doctors'), Api.dio.get('/api/v1/admin/departments')]);
      if (mounted) setState(() { data = List<dynamic>.from(results[0].data); departments = List<dynamic>.from(results[1].data); error = null; });
    } catch (e) { if (mounted) setState(() => error = Api.errorMessage(e)); }
  }

  Future<void> addDoctor() async {
    final name = TextEditingController(); final specialty = TextEditingController(); final qualifications = TextEditingController(); final languages = TextEditingController();
    String? deptId;
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: const Text('Add doctor'),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name *')),
        const SizedBox(height: 10), TextField(controller: specialty, decoration: const InputDecoration(labelText: 'Specialty *')),
        const SizedBox(height: 10), DropdownButtonFormField<String>(value: deptId, decoration: const InputDecoration(labelText: 'Department'), items: departments.map((x) { final d = Map<String,dynamic>.from(x); return DropdownMenuItem(value: d['id'].toString(), child: Text(d['name'].toString())); }).toList(), onChanged: (v) => setLocal(() => deptId = v)),
        const SizedBox(height: 10), TextField(controller: qualifications, decoration: const InputDecoration(labelText: 'Qualifications')),
        const SizedBox(height: 10), TextField(controller: languages, decoration: const InputDecoration(labelText: 'Languages')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save doctor'))],
    )));
    if (ok != true || name.text.trim().isEmpty || specialty.text.trim().isEmpty) return;
    try {
      await Api.dio.post('/api/v1/doctors', data: {'full_name': name.text.trim(), 'specialty': specialty.text.trim(), 'department_id': deptId, 'qualifications': qualifications.text.trim().isEmpty ? null : qualifications.text.trim(), 'languages': languages.text.trim().isEmpty ? null : languages.text.trim(), 'consultation_minutes': 20});
      if (mounted) showMessage(context, 'Doctor added.'); await load();
    } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  Future<void> addDepartment() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Add department'), content: TextField(controller: c, decoration: const InputDecoration(labelText: 'Department name')), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add'))]));
    if (ok != true || c.text.trim().length < 2) return;
    try { await Api.dio.post('/api/v1/admin/departments', data: {'name': c.text.trim()}); if (mounted) showMessage(context, 'Department added.'); await load(); } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  Future<void> addAvailability(Map<String,dynamic> doctor) async {
    int weekday = 0; final start = TextEditingController(text: '09:00'); final end = TextEditingController(text: '13:00'); final slot = TextEditingController(text: '20');
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: Text('Availability — ${doctor['full_name']}'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<int>(value: weekday, decoration: const InputDecoration(labelText: 'Weekday'), items: const [0,1,2,3,4,5,6].map((v) => DropdownMenuItem(value: v, child: Text(const ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][v]))).toList(), onChanged: (v) => setLocal(() => weekday = v ?? 0)),
        const SizedBox(height: 10), Row(children: [Expanded(child: TextField(controller: start, decoration: const InputDecoration(labelText: 'Start HH:MM'))), const SizedBox(width: 8), Expanded(child: TextField(controller: end, decoration: const InputDecoration(labelText: 'End HH:MM')))]),
        const SizedBox(height: 10), TextField(controller: slot, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Slot minutes')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save'))],
    )));
    if (ok != true) return;
    try { await Api.dio.post('/api/v1/doctors/${doctor['id']}/availability', data: {'weekday': weekday, 'start_time': start.text.trim(), 'end_time': end.text.trim(), 'slot_minutes': int.tryParse(slot.text) ?? 20}); if (mounted) showMessage(context, 'Availability added.'); } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  @override
  Widget build(BuildContext context) => SectionPage(
    title: 'Doctors', subtitle: 'Directory, departments and availability',
    actions: [IconButton(onPressed: addDepartment, tooltip: 'Add department', icon: const Icon(Icons.domain_add_outlined)), FilledButton.icon(onPressed: addDoctor, icon: const Icon(Icons.person_add_alt), label: const Text('Doctor'))],
    child: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(18), children: [
      if (error != null) ErrorCard(error!),
      Wrap(spacing: 12, runSpacing: 12, children: data.map((raw) { final d = Map<String,dynamic>.from(raw); return SizedBox(width: 340, child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const CircleAvatar(child: Icon(Icons.medical_services_outlined)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(d['full_name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)), Text(d['specialty']?.toString() ?? '')]))]),
        if (d['qualifications'] != null) ...[const SizedBox(height: 10), Text(d['qualifications'].toString())],
        if (d['languages'] != null) ...[const SizedBox(height: 6), Text('Languages: ${d['languages']}')],
        const SizedBox(height: 12), OutlinedButton.icon(onPressed: () => addAvailability(d), icon: const Icon(Icons.schedule), label: const Text('Add availability')),
      ])))); }).toList()),
      if (data.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(28), child: Text('No doctors configured. Add a department and doctor.'))),
    ])),
  );
}

