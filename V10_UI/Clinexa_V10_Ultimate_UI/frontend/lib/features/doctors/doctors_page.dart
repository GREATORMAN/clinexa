import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';

class DoctorsPage extends StatefulWidget {
  const DoctorsPage({super.key});
  @override
  State<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends State<DoctorsPage> {
  List<dynamic> data = [];
  List<dynamic> departments = [];
  String? error;
  bool loading = true;
  String query = '';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final results = await Future.wait([
        Api.dio.get('/api/v1/doctors'),
        Api.dio.get('/api/v1/admin/departments'),
      ]);
      if (mounted) {
        setState(() {
          data = List<dynamic>.from(results[0].data as List);
          departments = List<dynamic>.from(results[1].data as List);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addDoctor() async {
    final name = TextEditingController();
    final specialty = TextEditingController();
    final qualifications = TextEditingController();
    final languages = TextEditingController();
    String? deptId;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(children: [Icon(Icons.medical_services_outlined, color: ClinexaTheme.primary), SizedBox(width: 9), Text('Add clinician')]),
          content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: InputDecoration(labelText: 'Full name *', prefixIcon: Icon(Icons.person_outline_rounded))),
              SizedBox(height: 11),
              TextField(controller: specialty, decoration: InputDecoration(labelText: 'Specialty *', prefixIcon: Icon(Icons.workspace_premium_outlined))),
              SizedBox(height: 11),
              DropdownButtonFormField<String>(isExpanded: true, initialValue: deptId, decoration: InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.domain_outlined)), items: departments.map((x) { final d = Map<String,dynamic>.from(x as Map); return DropdownMenuItem(value: d['id'].toString(), child: Text(d['name'].toString())); }).toList(), onChanged: (v) => setLocal(() => deptId = v)),
              SizedBox(height: 11),
              TextField(controller: qualifications, decoration: InputDecoration(labelText: 'Qualifications')),
              SizedBox(height: 11),
              TextField(controller: languages, decoration: InputDecoration(labelText: 'Languages')),
            ])),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
            FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: Icon(Icons.check_rounded), label: Text('Save clinician')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty || specialty.text.trim().isEmpty) return;
    try {
      await Api.dio.post('/api/v1/doctors', data: {
        'full_name': name.text.trim(),
        'specialty': specialty.text.trim(),
        'department_id': deptId,
        'qualifications': qualifications.text.trim().isEmpty ? null : qualifications.text.trim(),
        'languages': languages.text.trim().isEmpty ? null : languages.text.trim(),
        'consultation_minutes': 20,
      });
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  Future<void> addDepartment() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Create department'),
      content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 420), child: TextField(controller: c, decoration: InputDecoration(labelText: 'Department name', prefixIcon: Icon(Icons.domain_add_outlined)))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Create'))],
    ));
    if (ok != true || c.text.trim().length < 2) return;
    try { await Api.dio.post('/api/v1/admin/departments', data: {'name': c.text.trim()}); await load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e)))); }
  }

  Future<void> addAvailability(Map<String, dynamic> doctor) async {
    int weekday = 0;
    final start = TextEditingController(text: '09:00');
    final end = TextEditingController(text: '13:00');
    final slot = TextEditingController(text: '20');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Availability • ${doctor['full_name']}'),
          content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 450), child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(initialValue: weekday, decoration: InputDecoration(labelText: 'Weekday', prefixIcon: Icon(Icons.calendar_today_outlined)), items: [0,1,2,3,4,5,6].map((v) => DropdownMenuItem(value: v, child: Text(['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][v]))).toList(), onChanged: (v) => setLocal(() => weekday = v ?? 0)),
            SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: start, decoration: InputDecoration(labelText: 'Start HH:MM'))),
              SizedBox(width: 8),
              Expanded(child: TextField(controller: end, decoration: InputDecoration(labelText: 'End HH:MM'))),
            ]),
            SizedBox(height: 10),
            TextField(controller: slot, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Consultation slot (minutes)')),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Add availability'))],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await Api.dio.post('/api/v1/doctors/${doctor['id']}/availability', data: {
        'weekday': weekday,
        'start_time': start.text.trim(),
        'end_time': end.text.trim(),
        'slot_minutes': int.tryParse(slot.text) ?? 20,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Availability added.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 700 ? 16.0 : 28.0;
    final q = query.trim().toLowerCase();
    final visible = q.isEmpty ? data : data.where((x) => '${x['full_name']} ${x['specialty']} ${x['qualifications'] ?? ''}'.toLowerCase().contains(q)).toList();
    final specialties = data.map((x) => x['specialty']?.toString()).whereType<String>().where((x) => x.isNotEmpty).toSet().length;

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 26, pad, 38),
        children: [
          CxPageHeader(
            icon: Icons.medical_services_rounded,
            eyebrow: 'Clinical workforce',
            title: 'Doctors & care teams',
            subtitle: 'A visual directory for specialties, departments and scheduling availability — designed for fast operational scanning.',
            actions: [
              OutlinedButton.icon(onPressed: Api.can('doctors.manage') ? addDepartment : null, icon: Icon(Icons.domain_add_outlined), label: Text('Department')),
              FilledButton.icon(onPressed: Api.can('doctors.manage') ? addDoctor : null, icon: Icon(Icons.person_add_alt_rounded), label: Text('Add clinician')),
            ],
          ),
          SizedBox(height: 18),
          CxAdaptiveGrid(
            minItemWidth: 230,
            maxColumns: 3,
            children: [
              CxMetricCard(label: 'Clinicians', value: '${data.length}', caption: 'Active directory entries', icon: Icons.medical_services_outlined),
              CxMetricCard(label: 'Specialties', value: '$specialties', caption: 'Clinical specialties represented', icon: Icons.workspace_premium_outlined, tone: ClinexaTheme.accent),
              CxMetricCard(label: 'Departments', value: '${departments.length}', caption: 'Operational care departments', icon: Icons.domain_outlined, tone: ClinexaTheme.success),
            ],
          ),
          if (error != null) ...[SizedBox(height: 12), CxErrorBanner(message: error!, onRetry: load)],
          SizedBox(height: 16),
          CxSurface(padding: EdgeInsets.all(14), child: TextField(onChanged: (v) => setState(() => query = v), decoration: InputDecoration(labelText: 'Search clinician, specialty or qualification', prefixIcon: Icon(Icons.search_rounded)))),
          SizedBox(height: 14),
          if (loading) ...List.generate(6, (_) => Padding(padding: EdgeInsets.only(bottom: 10), child: CxSkeleton(height: 180))),
          if (!loading && visible.isEmpty) CxSurface(child: CxEmptyState(icon: Icons.medical_services_outlined, title: 'No clinicians found', message: 'Adjust the search or add a clinician to this development workspace.')),
          if (!loading) CxAdaptiveGrid(
            minItemWidth: 330,
            maxColumns: 3,
            children: visible.map((raw) => _DoctorCard(
              doctor: Map<String, dynamic>.from(raw as Map),
              onAvailability: addAvailability,
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final Future<void> Function(Map<String, dynamic>) onAvailability;
  const _DoctorCard({required this.doctor, required this.onAvailability});
  @override
  Widget build(BuildContext context) {
    final name = doctor['full_name']?.toString() ?? 'Doctor';
    final initial = name.isEmpty ? 'D' : name[0].toUpperCase();
    return CxSurface(
      elevated: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 54, height: 54, decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF4567C6), Color(0xFF6B56C8)]), borderRadius: BorderRadius.circular(17)), child: Center(child: Text(initial, style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)))),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text(doctor['specialty']?.toString() ?? 'General clinical care', style: TextStyle(color: ClinexaTheme.primary, fontSize: 10.8, fontWeight: FontWeight.w800)),
          ])),
          CxStatusChip(label: doctor['is_active'] == false ? 'Inactive' : 'Active', color: doctor['is_active'] == false ? Theme.of(context).colorScheme.onSurfaceVariant : ClinexaTheme.success),
        ]),
        SizedBox(height: 16),
        if (doctor['qualifications'] != null) Text(doctor['qualifications'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5, height: 1.4)),
        if (doctor['languages'] != null) ...[
          SizedBox(height: 8),
          Row(children: [Icon(Icons.translate_rounded, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant), SizedBox(width: 6), Expanded(child: Text(doctor['languages'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5)))]),
        ],
        SizedBox(height: 12),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: Api.can('doctors.manage') ? () => onAvailability(doctor) : null, icon: Icon(Icons.schedule_rounded, size: 17), label: Text('Add availability'))),
      ]),
    );
  }
}
