import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';

class CareTasksPage extends StatefulWidget {
  final String? initialPatientId;
  const CareTasksPage({super.key, this.initialPatientId});
  @override
  State<CareTasksPage> createState() => _CareTasksPageState();
}

class _CareTasksPageState extends State<CareTasksPage> {
  List<dynamic> tasks = [];
  List<dynamic> patients = [];
  bool loading = true;
  bool saving = false;
  String? error;
  String filter = 'active';
  String query = '';
  String? patientFilter;
  final Set<String> updating = {};

  @override
  void initState() { super.initState(); patientFilter = widget.initialPatientId; load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final r = await Future.wait([Api.dio.get('/api/v1/care-tasks'), Api.dio.get('/api/v1/patients')]);
      if (!mounted) return;
      setState(() { tasks = List<dynamic>.from(r[0].data); patients = List<dynamic>.from(r[1].data); });
    } catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool overdue(dynamic t) {
    final date = DateTime.tryParse('${t['due_at'] ?? ''}Z');
    return date != null && date.isBefore(DateTime.now().toUtc()) && !['completed', 'cancelled'].contains(t['status']);
  }

  Future<void> create() async {
    if (patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add a patient before creating a care task.')));
      return;
    }
    final title = TextEditingController();
    final notes = TextEditingController();
    final form = GlobalKey<FormState>();
    String patient = patients.any((p) => p['id'] == patientFilter) ? patientFilter! : patients.first['id'].toString();
    String priority = 'normal';
    DateTime? due;
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, change) => AlertDialog(
      title: Text('New care task'),
      content: ConstrainedBox(constraints: BoxConstraints(maxWidth: 480), child: SingleChildScrollView(child: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(isExpanded: true, initialValue: patient, decoration: InputDecoration(labelText: 'Patient'),
          items: patients.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text('${p['full_name']}', overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => patient = v ?? patient),
        SizedBox(height: 14),
        TextFormField(controller: title, maxLength: 200, decoration: InputDecoration(labelText: 'Task title', hintText: 'e.g. Review uploaded lab results'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a task title' : null),
        SizedBox(height: 8),
        DropdownButtonFormField<String>(isExpanded: true, initialValue: priority, decoration: InputDecoration(labelText: 'Priority'), items: [DropdownMenuItem(value: 'normal', child: Text('Normal')), DropdownMenuItem(value: 'high', child: Text('High')), DropdownMenuItem(value: 'urgent', child: Text('Urgent'))], onChanged: (v) => priority = v ?? priority),
        SizedBox(height: 14),
        TextFormField(controller: notes, maxLines: 3, maxLength: 4000, decoration: InputDecoration(labelText: 'Handoff notes (optional)')),
        SizedBox(height: 8),
        OutlinedButton.icon(icon: Icon(Icons.event_outlined), label: Text(due == null ? 'Choose due date (optional)' : 'Due ${due!.day}/${due!.month}/${due!.year}'), onPressed: () async {
          final now = DateTime.now();
          final date = await showDatePicker(context: ctx, initialDate: due ?? now, firstDate: DateTime(now.year, now.month, now.day), lastDate: now.add(Duration(days: 730)));
          if (date != null && ctx.mounted) change(() => due = DateTime(date.year, date.month, date.day, 17));
        }),
        if (due != null) TextButton(onPressed: () => change(() => due = null), child: Text('Clear due date')),
      ])))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')), FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(ctx, true); }, child: Text('Create task'))],
    )));
    final payload = {'patient_id': patient, 'title': title.text.trim(), 'notes': notes.text.trim(), 'priority': priority, 'due_at': due?.toUtc().toIso8601String()};
    title.dispose(); notes.dispose();
    if (accepted != true || !mounted) return;
    setState(() => saving = true);
    try {
      await Api.dio.post('/api/v1/care-tasks', data: payload);
      await load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e)))); }
    finally { if (mounted) setState(() => saving = false); }
  }

  Future<void> status(dynamic task, String value) async {
    final id = task['id'].toString();
    if (updating.contains(id)) return;
    setState(() => updating.add(id));
    try {
      final r = await Api.dio.patch('/api/v1/care-tasks/$id', data: {'status': value, 'version': task['version']});
      if (mounted) setState(() => tasks[tasks.indexWhere((t) => t['id'] == id)] = r.data);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e)))); }
    finally { if (mounted) setState(() => updating.remove(id)); }
  }

  @override
  Widget build(BuildContext context) {
    final active = tasks.where((t) => !['completed', 'cancelled'].contains(t['status'])).toList();
    final visible = tasks.where((t) {
      final match = '${t['title']} ${t['patient_name']} ${t['patient_code']}'.toLowerCase().contains(query.toLowerCase());
      return match && (patientFilter == null || t['patient_id'] == patientFilter) && (filter == 'all' || (filter == 'active' && active.contains(t)) || (filter == 'overdue' && overdue(t)) || t['status'] == filter);
    }).toList();
    return RefreshIndicator(onRefresh: load, child: ListView(padding: EdgeInsets.all(20), children: [
      CxPageHeader(eyebrow: 'Care coordination', title: 'Every handoff, accounted for.', subtitle: 'Patient-linked tasks with priorities, due dates and a shared completion trail.', actions: [FilledButton.icon(onPressed: loading || saving || !Api.can('patient.clinical.write') ? null : create, icon: Icon(Icons.add_rounded), label: Text('New task'))]),
      SizedBox(height: 20),
      CxAdaptiveGrid(minItemWidth: 180, children: [
        CxMetricCard(label: 'Active', value: loading ? '—' : '${active.length}', caption: 'Open and in progress', icon: Icons.checklist_rounded),
        CxMetricCard(label: 'Overdue', value: loading ? '—' : '${tasks.where(overdue).length}', caption: 'Past their due date', icon: Icons.schedule_rounded, tone: ClinexaTheme.emergency),
        CxMetricCard(label: 'Completed', value: loading ? '—' : '${tasks.where((t) => t['status'] == 'completed').length}', caption: 'Completed care tasks', icon: Icons.task_alt_rounded, tone: ClinexaTheme.success),
      ]),
      SizedBox(height: 20),
      if (error != null) CxErrorBanner(message: error!, onRetry: load),
      CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(onChanged: (v) => setState(() => query = v), decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search task or patient…')),
        SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: {'active': 'Active', 'overdue': 'Overdue', 'completed': 'Completed', 'all': 'All tasks'}.entries.map((e) => ChoiceChip(label: Text(e.value), selected: filter == e.key, onSelected: (_) => setState(() => filter = e.key))).toList()),
        if (patientFilter != null) TextButton(onPressed: () => setState(() => patientFilter = null), child: Text('Show all patients')),
        SizedBox(height: 18),
        if (loading) ...List.generate(3, (_) => Padding(padding: EdgeInsets.only(bottom: 12), child: CxSkeleton(height: 120))),
        if (!loading && error == null && visible.isEmpty) CxEmptyState(icon: Icons.task_alt_rounded, title: 'All clear in this view', message: 'Create a care task or adjust your filters.'),
        if (!loading) ...visible.map((t) {
          final color = overdue(t) || t['priority'] == 'urgent' ? ClinexaTheme.emergency : t['priority'] == 'high' ? ClinexaTheme.warning : ClinexaTheme.primary;
          final due = DateTime.tryParse('${t['due_at'] ?? ''}Z')?.toLocal();
          return Padding(padding: EdgeInsets.only(bottom: 12), child: CxSurface(color: Theme.of(context).colorScheme.surfaceContainerLow, radius: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 4, height: 40, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${t['title']}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)), SizedBox(height: 5), Text('${t['patient_name']} • ${t['patient_code']}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12))])),
              if (updating.contains(t['id'])) SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else if (Api.can('patient.clinical.write')) PopupMenuButton<String>(tooltip: 'Update task', onSelected: (s) => status(t, s), itemBuilder: (_) => [PopupMenuItem(value: 'in_progress', child: Text('Start task')), PopupMenuItem(value: 'completed', child: Text('Complete task')), PopupMenuItem(value: 'open', child: Text('Reopen')), PopupMenuItem(value: 'cancelled', child: Text('Cancel task'))]),
            ]),
            if ('${t['notes'] ?? ''}'.isNotEmpty) ...[SizedBox(height: 12), Text('${t['notes']}', style: TextStyle(fontSize: 13, height: 1.5))],
            SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [CxStatusChip(label: '${t['status']}'.replaceAll('_', ' ')), CxStatusChip(label: '${t['priority']}', color: color), if (due != null) CxStatusChip(label: '${overdue(t) ? 'Overdue • ' : 'Due '}${due.day}/${due.month}/${due.year}', color: overdue(t) ? ClinexaTheme.emergency : Theme.of(context).colorScheme.onSurfaceVariant, icon: Icons.schedule_rounded)]),
          ])));
        }),
      ])),
    ]));
  }
}
