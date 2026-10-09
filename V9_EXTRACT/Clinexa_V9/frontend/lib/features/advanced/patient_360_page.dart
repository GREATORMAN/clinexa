import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';
import '../medications/medicine_centre_page.dart';
import '../care/care_tasks_page.dart';

class Patient360Page extends StatefulWidget {
  final String? initialPatientId;
  Patient360Page({super.key, this.initialPatientId});
  @override
  State<Patient360Page> createState() => _Patient360PageState();
}

class _Patient360PageState extends State<Patient360Page> {
  List<dynamic> patients = [];
  String? patientId;
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;
  int section = 0;

  @override
  void initState() {
    super.initState();
    patientId = widget.initialPatientId;
    loadPatients();
  }

  Future<void> loadPatients() async {
    try {
      final r = await Api.dio.get('/api/v1/patients');
      patients = List<dynamic>.from(r.data as List);
      if (patients.isNotEmpty) patientId ??= patients.first['id'].toString();
      await load360();
    } catch (e) {
      if (mounted) setState(() { error = Api.errorMessage(e); loading = false; });
    }
  }

  Future<void> load360() async {
    if (patientId == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final r = await Api.dio.get('/api/v1/advanced/patients/$patientId/360');
      if (mounted) setState(() => data = Map<String, dynamic>.from(r.data));
    } catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<dynamic> _list(String key) => List<dynamic>.from(data?[key] as List? ?? []);

  Future<void> addSymptom() async {
    if (patientId == null) return;
    final symptom = TextEditingController();
    final note = TextEditingController();
    double severity = 3;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Record a symptom'),
          content: SizedBox(
            width: 460,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: symptom, decoration: InputDecoration(labelText: 'Symptom', prefixIcon: Icon(Icons.monitor_heart_outlined))),
              SizedBox(height: 14),
              Row(children: [
                Text('Severity', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(width: 12),
                Expanded(child: Slider(value: severity, min: 1, max: 10, divisions: 9, label: severity.round().toString(), onChanged: (v) => setLocal(() => severity = v))),
                CxStatusChip(label: '${severity.round()}/10', color: severity >= 7 ? ClinexaTheme.emergency : severity >= 4 ? ClinexaTheme.warning : ClinexaTheme.success),
              ]),
              SizedBox(height: 8),
              TextField(controller: note, maxLines: 3, decoration: InputDecoration(labelText: 'Context or note')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Save entry')),
          ],
        ),
      ),
    );
    if (ok == true && symptom.text.trim().isNotEmpty) {
      await Api.dio.post('/api/v1/advanced/symptoms/$patientId', data: {
        'symptom': symptom.text.trim(),
        'severity': severity.round(),
        'note': note.text.trim(),
      });
      await load360();
    }
  }

  Future<void> openMedicineCentre() async {
    if (patientId == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => MedicineCentrePage(initialPatientId: patientId)));
    await load360();
  }

  Future<void> aiSummary() async {
    if (patientId == null) return;
    showDialog(context: context, barrierDismissible: false, builder: (_) => Center(child: CircularProgressIndicator()));
    try {
      final r = await Api.dio.get('/api/v1/ai/patient/$patientId/summary');
      if (!mounted) return;
      Navigator.pop(context);
      final text = (r.data as Map)['answer']?.toString() ?? 'No summary returned.';
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [Icon(Icons.auto_awesome_rounded, color: ClinexaTheme.primary), SizedBox(width: 9), Text('AI record summary')]),
          content: SizedBox(width: 620, child: SingleChildScrollView(child: Text(text, style: TextStyle(height: 1.55)))),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text('Close'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 700 ? 16.0 : 28.0;
    final patient = data?['patient'] is Map ? Map<String, dynamic>.from(data!['patient'] as Map) : null;

    return RefreshIndicator(
      onRefresh: load360,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 26, pad, 38),
        children: [
          CxPageHeader(
            icon: Icons.hub_rounded,
            eyebrow: 'Longitudinal clinical record',
            title: 'Patient 360°',
            subtitle: 'A single clinical command view for history, medicines, observations, documents, care and upcoming work.',
            actions: [
              OutlinedButton.icon(onPressed: patientId == null ? null : aiSummary, icon: Icon(Icons.auto_awesome_outlined), label: Text('AI summary')),
              IconButton(onPressed: load360, icon: Icon(Icons.refresh_rounded), tooltip: 'Refresh'),
            ],
          ),
          SizedBox(height: 18),
          CxSurface(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 42, height: 42, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(13)), child: Icon(Icons.person_search_rounded, color: ClinexaTheme.primary)),
              SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(isExpanded: true, 
                  initialValue: patientId,
                  decoration: InputDecoration(labelText: 'Patient record', filled: false, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13)),
                  items: patients.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text('${p['full_name']}  •  ${p['patient_code']}'))).toList(),
                  onChanged: (v) { setState(() => patientId = v); load360(); },
                ),
              ),
            ]),
          ),
          if (error != null) ...[SizedBox(height: 14), CxErrorBanner(message: error!, onRetry: load360)],
          if (loading) ...[
            SizedBox(height: 14),
            CxSkeleton(height: 190, radius: 24),
            SizedBox(height: 12),
            Row(children: [Expanded(child: CxSkeleton(height: 110)), SizedBox(width: 10), Expanded(child: CxSkeleton(height: 110))]),
          ],
          if (!loading && patient == null) ...[
            SizedBox(height: 16),
            CxSurface(child: CxEmptyState(icon: Icons.person_search_outlined, title: 'Choose a patient', message: 'Select an authorized patient to open their longitudinal record.')),
          ],
          if (!loading && patient != null) ...[
            SizedBox(height: 14),
            _PatientHero(patient: patient, medications: _list('patient_medications'), appointments: _list('appointments'), labs: _list('labs')),
            SizedBox(height: 14),
            _ActionStrip(onSymptom: addSymptom, onMedicine: openMedicineCentre, onAi: aiSummary),
            SizedBox(height: 18),
            _MetricGrid(data: data ?? {}),
            SizedBox(height: 18),
            _SectionSelector(index: section, onChanged: (v) => setState(() => section = v)),
            SizedBox(height: 12),
            AnimatedSwitcher(duration: Duration(milliseconds: 260), switchInCurve: Curves.easeOutCubic, child: KeyedSubtree(key: ValueKey(section), child: _sectionContent(section))),
          ],
        ],
      ),
    );
  }

  Widget _sectionContent(int index) {
    switch (index) {
      case 1:
        return _ClinicalGrid(
          left: _RecordPanel(
            title: 'Active & historical medicines',
            subtitle: 'Verified clinical medication record',
            icon: Icons.medication_liquid_outlined,
            children: [
              ..._list('patient_medications').take(12).map((m) => _RecordRow(
                    icon: Icons.medication_rounded,
                    tone: ClinexaTheme.primary,
                    title: m['medication_name']?.toString() ?? 'Medication',
                    subtitle: [m['strength'], m['form'], m['frequency'], m['route']].where((x) => x != null && x.toString().trim().isNotEmpty).join(' • '),
                    trailing: CxStatusChip(label: m['status']?.toString() ?? 'record', color: m['status'] == 'active' ? ClinexaTheme.success : Theme.of(context).colorScheme.onSurfaceVariant),
                  )),
              ..._list('medication_schedules').take(6).map((m) => _RecordRow(icon: Icons.alarm_rounded, tone: Color(0xFF4567C6), title: 'Reminder • ${m['medication_name'] ?? 'Medication'}', subtitle: '${m['times_csv'] ?? 'No times'} • ${m['dose_label'] ?? ''}')),
            ],
          ),
          right: _RecordPanel(
            title: 'Prescription imports',
            subtitle: 'OCR drafts and electronic prescriptions',
            icon: Icons.document_scanner_outlined,
            children: [
              ..._list('ocr_prescriptions').take(8).map((x) => _RecordRow(icon: Icons.document_scanner_outlined, tone: ClinexaTheme.warning, title: 'OCR prescription', subtitle: '${x['status'] ?? 'draft'} • ${x['created_at'] ?? ''}')),
              ..._list('prescriptions').take(8).map((x) => _RecordRow(icon: Icons.receipt_long_outlined, tone: ClinexaTheme.primary, title: x['medication_name']?.toString() ?? 'Prescription', subtitle: [x['strength'], x['frequency'], x['status']].where((v) => v != null && v.toString().isNotEmpty).join(' • '))),
            ],
          ),
        );
      case 2:
        return _ClinicalGrid(
          left: _RecordPanel(
            title: 'Vitals', subtitle: 'Most recent observations', icon: Icons.monitor_heart_outlined,
            children: _list('vitals').take(12).map((v) => _RecordRow(
              icon: Icons.monitor_heart_outlined,
              tone: ClinexaTheme.emergency,
              title: 'BP ${v['systolic'] ?? '—'}/${v['diastolic'] ?? '—'}  •  HR ${v['heart_rate'] ?? '—'}',
              subtitle: 'SpO₂ ${v['spo2'] ?? '—'} • Temp ${v['temperature_c'] ?? '—'} • ${v['observed_at'] ?? ''}',
            )).toList(),
          ),
          right: _RecordPanel(
            title: 'Laboratory results', subtitle: 'Available structured results', icon: Icons.science_outlined,
            children: _list('labs').take(12).map((l) => _RecordRow(
              icon: Icons.science_outlined,
              tone: Color(0xFF6B56C8),
              title: l['test_name']?.toString() ?? 'Lab result',
              subtitle: '${l['result_value'] ?? '—'} ${l['unit'] ?? ''} • range ${l['reference_range'] ?? 'not recorded'}',
            )).toList(),
          ),
        );
      case 3:
        return _ClinicalGrid(
          left: _RecordPanel(
            title: 'Care & symptoms', subtitle: 'Patient-reported and planned follow-up', icon: Icons.favorite_border_rounded,
            children: [
              ..._list('symptoms').take(10).map((s) => _RecordRow(icon: Icons.sick_outlined, tone: (s['severity'] ?? 1) >= 7 ? ClinexaTheme.emergency : ClinexaTheme.warning, title: '${s['symptom'] ?? 'Symptom'} • severity ${s['severity'] ?? '—'}/10', subtitle: s['note']?.toString() ?? '')),
              TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text('Patient care tasks')), body: CareTasksPage(initialPatientId: patientId)))), icon: Icon(Icons.checklist_rounded), label: Text('Care tasks (${_list('care_tasks').length})')),
              ..._list('care_tasks').take(5).map((x) => _RecordRow(icon: Icons.checklist_rounded, tone: ClinexaTheme.primary, title: x['title']?.toString() ?? 'Care task', subtitle: '${x['priority']} • ${x['status']}')),
              ..._list('care_plans').take(8).map((x) => _RecordRow(icon: Icons.task_alt_rounded, tone: ClinexaTheme.success, title: x['title']?.toString() ?? 'Care plan', subtitle: x['status']?.toString() ?? '')),
            ],
          ),
          right: _RecordPanel(
            title: 'Coverage & consent', subtitle: 'Administrative context attached to care', icon: Icons.shield_outlined,
            children: [
              ..._list('insurance').take(6).map((x) => _RecordRow(icon: Icons.health_and_safety_outlined, tone: Color(0xFF4567C6), title: x['provider']?.toString() ?? 'Insurance', subtitle: '${x['plan_name'] ?? ''} • ${x['status'] ?? ''}')),
              ..._list('consents').take(8).map((x) => _RecordRow(icon: Icons.verified_user_outlined, tone: x['granted'] == true ? ClinexaTheme.success : Theme.of(context).colorScheme.onSurfaceVariant, title: x['consent_type']?.toString() ?? 'Consent', subtitle: x['granted'] == true ? 'Granted' : 'Not granted')),
            ],
          ),
        );
      default:
        return _ClinicalGrid(
          left: _RecordPanel(
            title: 'Longitudinal timeline', subtitle: 'Recent encounters and appointments', icon: Icons.timeline_rounded,
            children: [
              ..._list('encounters').take(8).map((e) => _RecordRow(icon: Icons.note_alt_outlined, tone: ClinexaTheme.primary, title: e['chief_complaint']?.toString() ?? 'Clinical encounter', subtitle: e['assessment']?.toString() ?? 'Clinical note')),
              ..._list('appointments').take(8).map((e) => _RecordRow(icon: Icons.calendar_month_outlined, tone: Color(0xFF4567C6), title: 'Appointment • ${e['status'] ?? 'scheduled'}', subtitle: '${e['start_at'] ?? ''} • ${e['reason'] ?? ''}')),
            ],
          ),
          right: _RecordPanel(
            title: 'Documents & emergency', subtitle: 'Records available in the patient context', icon: Icons.folder_copy_outlined,
            children: [
              ..._list('documents').take(8).map((d) => _RecordRow(icon: Icons.description_outlined, tone: ClinexaTheme.warning, title: d['original_name']?.toString() ?? 'Document', subtitle: '${d['category'] ?? 'record'} • ${d['created_at'] ?? ''}')),
              if (data?['emergency_profile'] != null) _RecordRow(icon: Icons.emergency_outlined, tone: ClinexaTheme.emergency, title: 'Emergency profile active', subtitle: '${_list('trusted_contacts').length} trusted contact(s) • ${_list('nfc_bands').where((x) => x['active'] == true).length} active band(s)'),
            ],
          ),
        );
    }
  }
}

class _PatientHero extends StatelessWidget {
  final Map<String, dynamic> patient;
  final List<dynamic> medications;
  final List<dynamic> appointments;
  final List<dynamic> labs;
  _PatientHero({required this.patient, required this.medications, required this.appointments, required this.labs});

  @override
  Widget build(BuildContext context) {
    final name = patient['full_name']?.toString() ?? 'Patient';
    final initial = name.trim().isEmpty ? 'P' : name.trim()[0].toUpperCase();
    final active = medications.where((m) => m['status'] == 'active').length;
    return Container(
      padding: EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [ClinexaTheme.navy, Color(0xFF12394C), Color(0xFF684566)]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: Color(0x1A0B1424), blurRadius: 34, offset: Offset(0, 16))],
      ),
      child: LayoutBuilder(builder: (_, c) {
        final compact = c.maxWidth < 660;
        final identity = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 62, height: 62, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withAlpha(28), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withAlpha(32))), child: Center(child: Text(initial, style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)))),
          SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(color: Colors.white, fontSize: 24, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -.5)),
            SizedBox(height: 6),
            Text('${patient['patient_code'] ?? '—'}  •  ${patient['sex'] ?? '—'}  •  Blood ${patient['blood_group'] ?? '—'}', style: TextStyle(color: Color(0xFFD6E4E6), fontSize: 12.5)),
            SizedBox(height: 12),
            Wrap(spacing: 7, runSpacing: 7, children: [
              _HeroPill(label: 'Allergies: ${patient['allergies'] ?? 'not recorded'}', icon: Icons.warning_amber_rounded),
              _HeroPill(label: 'Conditions: ${patient['conditions'] ?? 'not recorded'}', icon: Icons.health_and_safety_outlined),
            ]),
          ])),
        ]);
        final stats = Wrap(spacing: 9, runSpacing: 9, children: [
          _HeroStat(value: '$active', label: 'active medicines'),
          _HeroStat(value: '${appointments.length}', label: 'appointments'),
          _HeroStat(value: '${labs.length}', label: 'lab results'),
        ]);
        if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [identity, SizedBox(height: 18), stats]);
        return Row(children: [Expanded(child: identity), SizedBox(width: 18), stats]);
      }),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label; final IconData icon;
  _HeroPill({required this.label, required this.icon});
  @override Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxWidth: 340),
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withAlpha(18), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withAlpha(25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 13, color: Colors.white), SizedBox(width: 6), Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)))]),
  );
}

class _HeroStat extends StatelessWidget {
  final String value; final String label;
  _HeroStat({required this.value, required this.label});
  @override Widget build(BuildContext context) => Container(
    width: 112, padding: EdgeInsets.all(13),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withAlpha(18), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withAlpha(25))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)), SizedBox(height: 2), Text(label, style: TextStyle(color: Color(0xFFD6E4E6), fontSize: 9.5, fontWeight: FontWeight.w700))]),
  );
}

class _ActionStrip extends StatelessWidget {
  final VoidCallback onSymptom; final VoidCallback onMedicine; final VoidCallback onAi;
  _ActionStrip({required this.onSymptom, required this.onMedicine, required this.onAi});
  @override Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
    FilledButton.icon(onPressed: onMedicine, icon: Icon(Icons.medication_outlined), label: Text('Medicine Centre')),
    OutlinedButton.icon(onPressed: onSymptom, icon: Icon(Icons.monitor_heart_outlined), label: Text('Record symptom')),
    OutlinedButton.icon(onPressed: onAi, icon: Icon(Icons.auto_awesome_outlined), label: Text('Summarize record')),
  ]);
}

class _MetricGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  _MetricGrid({required this.data});
  int count(String key) => (data[key] as List?)?.length ?? 0;
  @override Widget build(BuildContext context) => CxAdaptiveGrid(
    minItemWidth: 210,
    children: [
      CxMetricCard(label: 'Encounters', value: '${count('encounters')}', caption: 'Clinical visits in context', icon: Icons.note_alt_outlined),
      CxMetricCard(label: 'Medicines', value: '${count('patient_medications')}', caption: 'Verified and historical', icon: Icons.medication_outlined, tone: ClinexaTheme.success),
      CxMetricCard(label: 'Labs', value: '${count('labs')}', caption: 'Structured result records', icon: Icons.science_outlined, tone: ClinexaTheme.accent),
      CxMetricCard(label: 'Documents', value: '${count('documents')}', caption: 'Files in the record vault', icon: Icons.folder_copy_outlined, tone: ClinexaTheme.warning),
    ],
  );
}

class _SectionSelector extends StatelessWidget {
  final int index; final ValueChanged<int> onChanged;
  _SectionSelector({required this.index, required this.onChanged});
  @override Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: SegmentedButton<int>(
      segments: [
        ButtonSegment(value: 0, icon: Icon(Icons.timeline_rounded), label: Text('Timeline')),
        ButtonSegment(value: 1, icon: Icon(Icons.medication_outlined), label: Text('Medicines')),
        ButtonSegment(value: 2, icon: Icon(Icons.monitor_heart_outlined), label: Text('Clinical data')),
        ButtonSegment(value: 3, icon: Icon(Icons.favorite_border_rounded), label: Text('Care & coverage')),
      ],
      selected: {index},
      showSelectedIcon: false,
      onSelectionChanged: (v) => onChanged(v.first),
    ),
  );
}

class _ClinicalGrid extends StatelessWidget {
  final Widget left; final Widget right;
  _ClinicalGrid({required this.left, required this.right});
  @override Widget build(BuildContext context) => LayoutBuilder(builder: (_, c) {
    if (c.maxWidth < 820) return Column(children: [left, SizedBox(height: 12), right]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: left), SizedBox(width: 12), Expanded(child: right)]);
  });
}

class _RecordPanel extends StatelessWidget {
  final String title; final String subtitle; final IconData icon; final List<Widget> children;
  _RecordPanel({required this.title, required this.subtitle, required this.icon, required this.children});
  @override Widget build(BuildContext context) => CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    CxSectionHeader(title: title, subtitle: subtitle, action: Container(width: 38, height: 38, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: ClinexaTheme.primary, size: 19))),
    SizedBox(height: 13),
    if (children.isEmpty) CxEmptyState(icon: Icons.inbox_outlined, title: 'Nothing recorded yet', message: 'Verified records will appear here as the patient journey progresses.') else ...children,
  ]));
}

class _RecordRow extends StatelessWidget {
  final IconData icon; final Color tone; final String title; final String subtitle; final Widget? trailing;
  _RecordRow({required this.icon, required this.tone, required this.title, required this.subtitle, this.trailing});
  @override Widget build(BuildContext context) => Container(
    margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
    child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: tone.withAlpha(18), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: tone, size: 17)),
      SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)), if (subtitle.trim().isNotEmpty) ...[SizedBox(height: 2), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 9.8, height: 1.35))]])),
      if (trailing != null) ...[SizedBox(width: 8), trailing!],
    ]),
  );
}
