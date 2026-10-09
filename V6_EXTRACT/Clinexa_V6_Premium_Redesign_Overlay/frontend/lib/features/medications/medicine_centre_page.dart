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

  List<dynamic> list(String key) => List<dynamic>.from((data?[key] as List?) ?? const []);
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
        title: const Text('Add verified medicine'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(child: Column(children: [
            if (prefill != null) ...[
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ClinexaTheme.mint, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFCFEAE6))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.inventory_2_outlined, color: ClinexaTheme.primary), const SizedBox(width: 9), Expanded(child: Text('Formulary selected: ${prefill['display_name']}. This only prefills identity fields; frequency, duration and instructions must come from the verified clinical source.', style: const TextStyle(fontSize: 10.5, height: 1.45)))])),
              const SizedBox(height: 12),
            ],
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Medicine name *')),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: TextField(controller: strength, decoration: const InputDecoration(labelText: 'Strength'))), const SizedBox(width: 10), Expanded(child: TextField(controller: form, decoration: const InputDecoration(labelText: 'Form')))]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: TextField(controller: frequency, decoration: const InputDecoration(labelText: 'Frequency'))), const SizedBox(width: 10), Expanded(child: TextField(controller: route, decoration: const InputDecoration(labelText: 'Route')))]),
            const SizedBox(height: 10),
            TextField(controller: duration, decoration: const InputDecoration(labelText: 'Duration')),
            const SizedBox(height: 10),
            TextField(controller: doctor, decoration: const InputDecoration(labelText: 'Prescribing doctor/source')),
            const SizedBox(height: 10),
            TextField(controller: instructions, maxLines: 2, decoration: const InputDecoration(labelText: 'Instructions')),
            const SizedBox(height: 10),
            TextField(controller: reminders, decoration: const InputDecoration(labelText: 'Exact reminder times (optional)', hintText: '09:00,21:00')),
            const SizedBox(height: 12),
            const _Safety(text: 'Clinexa never infers dosage, frequency or reminder times from the catalog. Save only information verified against a prescription or clinician record.'),
          ])),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save verified medicine'))],
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medicine saved to this patient.')));
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
      if (catalogQuery.trim().isEmpty) return true;
      final q = catalogQuery.toLowerCase();
      return '${x['display_name']} ${x['generic_name']} ${x['category']}'.toLowerCase().contains(q);
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
            subtitle: 'Verified medicines, OCR imports, reminders and the local formulary — all tied to one patient instead of scattered pages.',
            actions: [
              IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded)),
              FilledButton.icon(onPressed: patientId == null ? null : () => addMedication(), icon: const Icon(Icons.add_rounded), label: const Text('Add verified medicine')),
            ],
          ),
          const SizedBox(height: 16),
          CxSurface(
            padding: const EdgeInsets.all(13),
            child: Row(children: [
              CircleAvatar(radius: 22, backgroundColor: ClinexaTheme.mint, foregroundColor: ClinexaTheme.primary, child: Text((selected?['full_name']?.toString() ?? 'P').substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))),
              const SizedBox(width: 11),
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: patientId,
                decoration: const InputDecoration(labelText: 'Patient', border: InputBorder.none, filled: false),
                items: patients.map((p) => DropdownMenuItem<String>(value: p['id'].toString(), child: Text('${p['full_name']} • ${p['patient_code']}'))).toList(),
                onChanged: (v) async { setState(() => patientId = v); await load(); },
              )),
            ]),
          ),
          if (error != null) ...[const SizedBox(height: 12), CxErrorBanner(message: error!, onRetry: load)],
          const SizedBox(height: 14),
          LayoutBuilder(builder: (_, c) {
            final cols = c.maxWidth >= 920 ? 4 : c.maxWidth >= 520 ? 2 : 1;
            return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: cols == 1 ? 2.45 : 1.55, children: [
              CxMetricCard(label: 'Active', value: '${current.length}', caption: 'Verified current medicines', icon: Icons.medication_rounded),
              CxMetricCard(label: 'History', value: '${previous.length}', caption: 'Completed or stopped records', icon: Icons.history_rounded, tone: const Color(0xFF4567C6)),
              CxMetricCard(label: 'Reminders', value: '${schedules.where((x) => x['active'] == true).length}', caption: 'Explicit medication schedules', icon: Icons.alarm_outlined, tone: ClinexaTheme.success),
              CxMetricCard(label: 'OCR imports', value: '${imports.length}', caption: 'Prescription OCR review history', icon: Icons.document_scanner_outlined, tone: ClinexaTheme.warning),
            ]);
          }),
          const SizedBox(height: 14),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, icon: Icon(Icons.medication_outlined), label: Text('Current')),
              ButtonSegment(value: 1, icon: Icon(Icons.history_rounded), label: Text('History')),
              ButtonSegment(value: 2, icon: Icon(Icons.alarm_outlined), label: Text('Reminders')),
              ButtonSegment(value: 3, icon: Icon(Icons.inventory_2_outlined), label: Text('Formulary')),
            ],
            selected: {tab},
            onSelectionChanged: (v) => setState(() => tab = v.first),
          ),
          const SizedBox(height: 14),
          if (loading) const CxSurface(child: Column(children: [CxSkeleton(height: 70), SizedBox(height: 10), CxSkeleton(height: 70), SizedBox(height: 10), CxSkeleton(height: 70)])) else _tabBody(current, previous, schedules, imports, filteredCatalog),
          const SizedBox(height: 14),
          const _Safety(text: 'OCR and AI never silently create or modify medication instructions. Formulary matches are identity suggestions only; verified clinical information remains the source of truth.'),
        ],
      ),
    );
  }

  Widget _tabBody(List<dynamic> current, List<dynamic> previous, List<dynamic> schedules, List<dynamic> imports, List<dynamic> filteredCatalog) {
    if (tab == 0) return _MedicationGrid(title: 'Current medicines', subtitle: 'Verified medication records currently marked active.', medicines: current);
    if (tab == 1) return _MedicationGrid(title: 'Medication history', subtitle: 'Completed, stopped and historical medication records.', medicines: previous);
    if (tab == 2) return CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CxSectionHeader(title: 'Reminder schedules', subtitle: '${schedules.length} schedules linked to this patient'),
      const SizedBox(height: 12),
      if (schedules.isEmpty) const CxEmptyState(icon: Icons.alarm_off_outlined, title: 'No reminders', message: 'Exact reminder times appear here only when explicitly configured.'),
      ...schedules.map((x) => _ReminderTile(item: Map<String, dynamic>.from(x as Map))),
      if (imports.isNotEmpty) ...[
        const Divider(height: 28),
        const CxSectionHeader(title: 'OCR import history', subtitle: 'Prescription scans that entered the structured review workflow.'),
        const SizedBox(height: 10),
        ...imports.take(8).map((x) => _ImportTile(item: Map<String, dynamic>.from(x as Map))),
      ],
    ]));
    return CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CxSectionHeader(title: 'Local medication formulary', subtitle: '${catalog.length} common catalog items used for OCR matching and pharmacy workflows.'),
      const SizedBox(height: 12),
      TextField(onChanged: (v) => setState(() => catalogQuery = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search medicine, category or generic name…')),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth >= 960 ? 4 : c.maxWidth >= 650 ? 3 : c.maxWidth >= 430 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredCatalog.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: cols == 1 ? 2.35 : .78),
          itemBuilder: (_, i) {
            final item = Map<String, dynamic>.from(filteredCatalog[i] as Map);
            return _FormularyCard(item: item, onUse: () => addMedication(prefill: item));
          },
        );
      }),
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
        const SizedBox(height: 12),
        if (medicines.isEmpty) const CxEmptyState(icon: Icons.medication_outlined, title: 'No medicines here', message: 'Verified medicines will appear here once they are recorded or confirmed from OCR.'),
        LayoutBuilder(builder: (_, c) {
          final cols = c.maxWidth >= 820 ? 2 : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: medicines.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: cols == 1 ? 2.6 : 1.75),
            itemBuilder: (_, i) => _MedicineCard(item: Map<String, dynamic>.from(medicines[i] as Map)),
          );
        }),
      ]));
}

class _MedicineCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _MedicineCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final active = item['status'] == 'active';
    return Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: active ? const Color(0xFFF7FCFB) : ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(18), border: Border.all(color: active ? const Color(0xFFCFEAE6) : ClinexaTheme.line)), child: Row(children: [
      const CxMedicineVisual(imageKey: 'capsule'),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item['medication_name']?.toString() ?? 'Medicine', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 3),
        Text([item['strength'], item['form'], item['frequency']].where((x) => x != null && x.toString().isNotEmpty).join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5)),
        if (item['prescribing_doctor_text'] != null) ...[const SizedBox(height: 3), Text('Source: ${item['prescribing_doctor_text']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 9.5))],
        const SizedBox(height: 7),
        Wrap(spacing: 6, runSpacing: 6, children: [CxStatusChip(label: item['status']?.toString() ?? 'active', color: active ? ClinexaTheme.success : ClinexaTheme.muted), if (item['verified'] == true) const CxStatusChip(label: 'verified', color: ClinexaTheme.primary, icon: Icons.verified_rounded), CxStatusChip(label: (item['source_type'] ?? 'record').toString().replaceAll('_', ' '), color: const Color(0xFF4567C6))]),
      ])),
    ]));
  }
}

class _ReminderTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ReminderTile({required this.item});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.line)), child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: ClinexaTheme.mint, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.alarm_rounded, color: ClinexaTheme.primary, size: 19)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['medication_name']?.toString() ?? 'Medicine', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text('${item['dose_label'] ?? ''} • ${item['times_csv'] ?? ''}', style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5))])),
        CxStatusChip(label: item['active'] == true ? 'active' : 'paused', color: item['active'] == true ? ClinexaTheme.success : ClinexaTheme.muted),
      ]));
}

class _ImportTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ImportTile({required this.item});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.line)), child: Row(children: [
        const Icon(Icons.document_scanner_outlined, color: ClinexaTheme.warning), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['doctor_name_text']?.toString().isNotEmpty == true ? item['doctor_name_text'].toString() : 'Prescription OCR', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text('${item['prescription_date_text'] ?? 'date not captured'} • ${item['created_at'] ?? ''}', style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5))])),
        CxStatusChip(label: item['status']?.toString() ?? 'draft', color: item['status'] == 'confirmed' ? ClinexaTheme.success : ClinexaTheme.warning),
      ]));
}

class _FormularyCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onUse;
  const _FormularyCard({required this.item, required this.onUse});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: ClinexaTheme.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CxMedicineVisual(imageKey: item['image_key']?.toString() ?? 'capsule'), const Spacer(), if (item['prescription_required'] == true) const CxStatusChip(label: 'Rx', color: ClinexaTheme.warning) else const CxStatusChip(label: 'Formulary', color: ClinexaTheme.success)]),
          const SizedBox(height: 11),
          Text(item['display_name']?.toString() ?? 'Medicine', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 3),
          Text([item['strength'], item['form']].where((x) => x != null && x.toString().isNotEmpty).join(' • '), style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5)),
          const SizedBox(height: 7),
          Expanded(child: Text(item['description']?.toString() ?? '', maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10, height: 1.35))),
          const SizedBox(height: 8),
          CxStatusChip(label: item['category']?.toString() ?? 'Medicine', color: const Color(0xFF4567C6)),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: onUse, icon: const Icon(Icons.add_rounded), label: const Text('Use for verified entry'))),
        ]),
      );
}

class _Safety extends StatelessWidget {
  final String text;
  const _Safety({required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.line)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.shield_outlined, size: 18, color: ClinexaTheme.primary), const SizedBox(width: 9), Expanded(child: Text(text, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5, height: 1.45)))]));
}

extension _FirstOrNull<T> on Iterable<T> { T? get firstOrNull => isEmpty ? null : first; }
