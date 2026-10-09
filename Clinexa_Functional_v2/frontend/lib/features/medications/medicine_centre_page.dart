import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';

class MedicineCentrePage extends StatefulWidget {
  final String? initialPatientId;
  const MedicineCentrePage({super.key, this.initialPatientId});
  @override
  State<MedicineCentrePage> createState() => _MedicineCentrePageState();
}

class _MedicineCentrePageState extends State<MedicineCentrePage> {
  List<dynamic> patients = [];
  List<dynamic> catalog = [];
  String? patientId;
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;
  int tab = 0;
  String catalogQuery = '';
  String catalogCategory = 'All';

  @override
  void initState() {
    super.initState();
    patientId = widget.initialPatientId;
    bootstrap();
  }

  Future<void> bootstrap() async {
    try {
      final responses = await Future.wait([
        Api.dio.get('/api/v1/patients'),
        Api.dio.get('/api/v1/advanced/medication-catalog'),
      ]);
      patients = List<dynamic>.from(responses[0].data as List);
      catalog = List<dynamic>.from(responses[1].data as List);
      patientId ??= patients.isNotEmpty ? patients.first['id'].toString() : null;
      await load();
    } catch (e) {
      if (mounted) setState(() { error = Api.errorMessage(e); loading = false; });
    }
  }

  Future<void> load() async {
    if (patientId == null) { if (mounted) setState(() => loading = false); return; }
    setState(() { loading = true; error = null; });
    try {
      final response = await Api.dio.get('/api/v1/advanced/medication-centre/$patientId');
      data = Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      error = Api.errorMessage(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<dynamic> list(String key) => List<dynamic>.from((data?[key] as List?) ?? []);
  String? _n(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> addMedication({Map<String, dynamic>? prefill}) async {
    if (patientId == null) return;
    final name = TextEditingController(text: prefill?['generic_name']?.toString() ?? '');
    final strength = TextEditingController(text: prefill?['strength']?.toString() ?? '');
    final form = TextEditingController(text: prefill?['form']?.toString() ?? '');
    final frequency = TextEditingController();
    final route = TextEditingController();
    final duration = TextEditingController();
    final doctor = TextEditingController();
    final instructions = TextEditingController();
    final reminders = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add verified medicine'),
        content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 650), child: SingleChildScrollView(child: Column(children: [
            if (prefill != null) ...[
              Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(15), border: Border.all(color: Color(0xFFCFEAE6))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.inventory_2_outlined, color: ClinexaTheme.primary), SizedBox(width: 9), Expanded(child: Text('Formulary selected: ${prefill['display_name']}. This only prefills identity fields; frequency, duration and instructions must come from the verified clinical source.', style: TextStyle(fontSize: 10.5, height: 1.45)))])),
              SizedBox(height: 12),
            ],
            TextField(controller: name, decoration: InputDecoration(labelText: 'Medicine name *')),
            SizedBox(height: 10),
            Row(children: [Expanded(child: TextField(controller: strength, decoration: InputDecoration(labelText: 'Strength'))), SizedBox(width: 10), Expanded(child: TextField(controller: form, decoration: InputDecoration(labelText: 'Form')))]),
            SizedBox(height: 10),
            Row(children: [Expanded(child: TextField(controller: frequency, decoration: InputDecoration(labelText: 'Frequency'))), SizedBox(width: 10), Expanded(child: TextField(controller: route, decoration: InputDecoration(labelText: 'Route')))]),
            SizedBox(height: 10),
            TextField(controller: duration, decoration: InputDecoration(labelText: 'Duration')),
            SizedBox(height: 10),
            TextField(controller: doctor, decoration: InputDecoration(labelText: 'Prescribing doctor/source')),
            SizedBox(height: 10),
            TextField(controller: instructions, maxLines: 2, decoration: InputDecoration(labelText: 'Instructions')),
            SizedBox(height: 10),
            TextField(controller: reminders, decoration: InputDecoration(labelText: 'Exact reminder times (optional)', hintText: '09:00,21:00')),
            SizedBox(height: 12),
            _Safety(text: 'Clinexa never infers dosage, frequency or reminder times from the catalog. Save only information verified against a prescription or clinician record.'),
          ])),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Save verified medicine'))],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      await Api.dio.post('/api/v1/advanced/medication-centre', data: {
        'patient_id': patientId,
        'medication_name': name.text.trim(),
        'strength': _n(strength.text),
        'form': _n(form.text),
        'frequency': _n(frequency.text),
        'route': _n(route.text),
        'duration': _n(duration.text),
        'prescribing_doctor_text': _n(doctor.text),
        'instructions': _n(instructions.text),
        'reminder_times': _n(reminders.text),
        'status': 'active',
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Medicine saved to this patient.')));
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = list('current');
    final previous = list('previous');
    final schedules = list('schedules');
    final imports = list('ocr_imports');
    final selected = patients.where((x) => x['id']?.toString() == patientId).firstOrNull;
    final filteredCatalog = catalog.where((x) {
      final categoryOk = catalogCategory == 'All' || x['category']?.toString() == catalogCategory;
      if (!categoryOk) return false;
      if (catalogQuery.trim().isEmpty) return true;
      final q = catalogQuery.toLowerCase();
      return '${x['display_name']} ${x['generic_name']} ${x['category']} ${x['form']} ${x['strength']}'.toLowerCase().contains(q);
    }).toList();
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 700 ? 16.0 : 28.0;

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 26, pad, 36),
        children: [
          CxPageHeader(
            eyebrow: 'Medication centre',
            title: 'Medicines with provenance.',
            subtitle: 'Verified medicines, prescription OCR, reminders and pharmacy-ready formulary matching — tied to one patient record.',
            icon: Icons.medication_rounded,
            actions: [
              IconButton(onPressed: load, icon: Icon(Icons.refresh_rounded)),
              FilledButton.icon(onPressed: patientId == null ? null : () => addMedication(), icon: Icon(Icons.add_rounded), label: Text('Add verified medicine')),
            ],
          ),
          SizedBox(height: 16),
          CxSurface(
            padding: EdgeInsets.all(13),
            child: Row(children: [
              CircleAvatar(radius: 22, backgroundColor: Theme.of(context).colorScheme.primaryContainer, foregroundColor: ClinexaTheme.primary, child: Text((selected?['full_name']?.toString() ?? 'P').substring(0, 1).toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(width: 11),
              Expanded(child: DropdownButtonFormField<String>(isExpanded: true, 
                value: patientId,
                decoration: InputDecoration(labelText: 'Patient', border: InputBorder.none, filled: false),
                items: patients.map((p) => DropdownMenuItem<String>(value: p['id'].toString(), child: Text('${p['full_name']} • ${p['patient_code']}'))).toList(),
                onChanged: (v) async { setState(() => patientId = v); await load(); },
              )),
            ]),
          ),
          if (error != null) ...[SizedBox(height: 12), CxErrorBanner(message: error!, onRetry: load)],
          SizedBox(height: 14),
          CxAdaptiveGrid(minItemWidth: 215, children: [
            CxMetricCard(label: 'Active', value: '${current.length}', caption: 'Verified current medicines', icon: Icons.medication_rounded),
            CxMetricCard(label: 'History', value: '${previous.length}', caption: 'Completed or stopped records', icon: Icons.history_rounded, tone: ClinexaTheme.accent),
            CxMetricCard(label: 'Reminders', value: '${schedules.where((x) => x['active'] == true).length}', caption: 'Explicit medication schedules', icon: Icons.alarm_outlined, tone: ClinexaTheme.success),
            CxMetricCard(label: 'OCR imports', value: '${imports.length}', caption: 'Prescription OCR review history', icon: Icons.document_scanner_outlined, tone: ClinexaTheme.warning),
          ]),
          SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, icon: Icon(Icons.medication_outlined), label: Text('Current')),
                ButtonSegment(value: 1, icon: Icon(Icons.history_rounded), label: Text('History')),
                ButtonSegment(value: 2, icon: Icon(Icons.alarm_outlined), label: Text('Reminders')),
                ButtonSegment(value: 3, icon: Icon(Icons.inventory_2_outlined), label: Text('Formulary')),
              ],
              selected: {tab},
              onSelectionChanged: (v) => setState(() => tab = v.first),
              showSelectedIcon: false,
            ),
          ),
          SizedBox(height: 14),
          if (loading) CxSurface(child: Column(children: [CxSkeleton(height: 70), SizedBox(height: 10), CxSkeleton(height: 70), SizedBox(height: 10), CxSkeleton(height: 70)])) else _tabBody(current, previous, schedules, imports, filteredCatalog),
          SizedBox(height: 14),
          _Safety(text: 'OCR and AI never silently create or modify medication instructions. Formulary matches are identity suggestions only; verified clinical information remains the source of truth.'),
        ],
      ),
    );
  }

  Widget _tabBody(List<dynamic> current, List<dynamic> previous, List<dynamic> schedules, List<dynamic> imports, List<dynamic> filteredCatalog) {
    if (tab == 0) {
      return _MedicationGrid(title: 'Current medicines', subtitle: 'Verified medication records currently marked active.', medicines: current);
    }
    if (tab == 1) {
      return _MedicationGrid(title: 'Medication history', subtitle: 'Completed, stopped and historical medication records.', medicines: previous);
    }
    if (tab == 2) {
      return CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CxSectionHeader(title: 'Reminder schedules', subtitle: '${schedules.length} schedules linked to this patient'),
      SizedBox(height: 12),
      if (schedules.isEmpty) CxEmptyState(icon: Icons.alarm_off_outlined, title: 'No reminders', message: 'Exact reminder times appear here only when explicitly configured.'),
      ...schedules.map((x) => _ReminderTile(item: Map<String, dynamic>.from(x))),
      if (imports.isNotEmpty) ...[
        Divider(height: 28),
        CxSectionHeader(title: 'OCR import history', subtitle: 'Prescription scans that entered the structured review workflow.'),
        SizedBox(height: 10),
        ...imports.take(8).map((x) => _ImportTile(item: Map<String, dynamic>.from(x))),
      ],
    ]));
    }
    return CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CxSectionHeader(title: 'Local medication formulary', subtitle: '${catalog.length} common catalog items used for OCR matching and pharmacy workflows.'),
      SizedBox(height: 12),
      TextField(onChanged: (v) => setState(() => catalogQuery = v), decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search name, category, form or strength…')),
      SizedBox(height: 10),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final category in <String>{'All', ...catalog.map((x) => x['category']?.toString()).whereType<String>()})
            Padding(
              padding: EdgeInsets.only(right: 7),
              child: ChoiceChip(
                label: Text(category),
                selected: catalogCategory == category,
                onSelected: (_) => setState(() => catalogCategory = category),
              ),
            ),
        ]),
      ),
      SizedBox(height: 12),
      CxAdaptiveGrid(
        minItemWidth: 230,
        maxColumns: 4,
        children: [
          for (final raw in filteredCatalog)
            _FormularyCard(item: Map<String, dynamic>.from(raw), onUse: () => addMedication(prefill: Map<String, dynamic>.from(raw))),
        ],
      ),
    ]));
  }
}

class _MedicationGrid extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<dynamic> medicines;
  const _MedicationGrid({required this.title, required this.subtitle, required this.medicines});
  @override
  Widget build(BuildContext context) => CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CxSectionHeader(title: title, subtitle: subtitle),
        SizedBox(height: 12),
        if (medicines.isEmpty) CxEmptyState(icon: Icons.medication_outlined, title: 'No medicines here', message: 'Verified medicines will appear here once they are recorded or confirmed from OCR.'),
        CxAdaptiveGrid(
          minItemWidth: 330,
          maxColumns: 2,
          children: [for (final raw in medicines) _MedicineCard(item: Map<String, dynamic>.from(raw))],
        ),
      ]));
}

class _MedicineCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MedicineCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final active = item['status'] == 'active';
    return Container(padding: EdgeInsets.all(13), decoration: BoxDecoration(color: active ? Theme.of(context).colorScheme.surfaceContainerLow : Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18), border: Border.all(color: active ? Color(0xFFCFEAE6) : Theme.of(context).colorScheme.outlineVariant)), child: Row(children: [
      CxMedicineVisual(imageKey: 'capsule'),
      SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['medication_name']?.toString() ?? 'Medicine', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        SizedBox(height: 3),
        Text([item['strength'], item['form'], item['frequency']].where((x) => x != null && x.toString().isNotEmpty).join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5)),
        if (item['prescribing_doctor_text'] != null) ...[SizedBox(height: 3), Text('Source: ${item['prescribing_doctor_text']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 9.5))],
        SizedBox(height: 7),
        Wrap(spacing: 6, runSpacing: 6, children: [CxStatusChip(label: item['status']?.toString() ?? 'active', color: active ? ClinexaTheme.success : Theme.of(context).colorScheme.onSurfaceVariant), if (item['verified'] == true) CxStatusChip(label: 'verified', color: ClinexaTheme.primary, icon: Icons.verified_rounded), CxStatusChip(label: (item['source_type'] ?? 'record').toString().replaceAll('_', ' '), color: Color(0xFF4567C6))]),
      ])),
    ]));
  }
}

class _ReminderTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ReminderTile({required this.item});
  @override
  Widget build(BuildContext context) => Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(11), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)), child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.alarm_rounded, color: ClinexaTheme.primary, size: 19)),
        SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['medication_name']?.toString() ?? 'Medicine', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text('${item['dose_label'] ?? ''} • ${item['times_csv'] ?? ''}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5))])),
        CxStatusChip(label: item['active'] == true ? 'active' : 'paused', color: item['active'] == true ? ClinexaTheme.success : Theme.of(context).colorScheme.onSurfaceVariant),
      ]));
}

class _ImportTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ImportTile({required this.item});
  @override
  Widget build(BuildContext context) => Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(11), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)), child: Row(children: [
        Icon(Icons.document_scanner_outlined, color: ClinexaTheme.warning), SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['doctor_name_text']?.toString().isNotEmpty == true ? item['doctor_name_text'].toString() : 'Prescription OCR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text('${item['prescription_date_text'] ?? 'date not captured'} • ${item['created_at'] ?? ''}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5))])),
        CxStatusChip(label: item['status']?.toString() ?? 'draft', color: item['status'] == 'confirmed' ? ClinexaTheme.success : ClinexaTheme.warning),
      ]));
}

class _FormularyCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onUse;
  const _FormularyCard({required this.item, required this.onUse});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CxMedicineVisual(imageKey: item['image_key']?.toString() ?? 'capsule'), Spacer(), if (item['prescription_required'] == true) CxStatusChip(label: 'Rx', color: ClinexaTheme.warning) else CxStatusChip(label: 'Formulary', color: ClinexaTheme.success)]),
          SizedBox(height: 11),
          Text(item['display_name']?.toString() ?? 'Medicine', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          SizedBox(height: 3),
          Text([item['strength'], item['form']].where((x) => x != null && x.toString().isNotEmpty).join(' • '), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5)),
          SizedBox(height: 7),
          Text(item['description']?.toString() ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10, height: 1.4)),
          SizedBox(height: 8),
          CxStatusChip(label: item['category']?.toString() ?? 'Medicine', color: Color(0xFF4567C6)),
          SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onUse, icon: Icon(Icons.add_rounded), label: Text('Use for verified entry'))),
        ]),
      );
}

class _Safety extends StatelessWidget {
  final String text;
  const _Safety({required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.shield_outlined, size: 18, color: ClinexaTheme.primary), SizedBox(width: 9), Expanded(child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5, height: 1.45)))]));
}

extension _FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
