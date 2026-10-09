import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';
import '../medications/medicine_centre_page.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<dynamic> patients = [];
  List<dynamic> docs = [];
  String? patientId;
  String? error;
  bool uploading = false;
  String? runningOcrId;

  @override
  void initState() {
    super.initState();
    bootstrap();
  }

  Future<void> bootstrap() async {
    try {
      final r = await Api.dio.get('/api/v1/patients');
      patients = List<dynamic>.from(r.data as List);
      if (patients.isNotEmpty) patientId = patients.first['id'].toString();
      if (mounted) setState(() {});
      await loadDocs();
    } catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
    }
  }

  Future<void> loadDocs() async {
    if (patientId == null) return;
    try {
      final r = await Api.dio.get('/api/v1/documents/patient/$patientId');
      if (mounted) setState(() { docs = List<dynamic>.from(r.data as List); error = null; });
    } catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
    }
  }

  Future<void> upload() async {
    if (patientId == null) {
      showMessage(context, 'Add a patient first.');
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      withData: true,
    );
    if (!mounted) return;
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.single;
    if (f.bytes == null) {
      showMessage(context, 'Could not read the selected file.');
      return;
    }

    String category = 'prescription';
    final desc = TextEditingController();
    if (!mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Upload ${f.name}'),
          content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(isExpanded: true, 
                value: category,
                decoration: InputDecoration(labelText: 'Document category'),
                items: [
                  DropdownMenuItem(value: 'prescription', child: Text('Prescription')),
                  DropdownMenuItem(value: 'lab_report', child: Text('Lab report')),
                  DropdownMenuItem(value: 'discharge_summary', child: Text('Discharge summary')),
                  DropdownMenuItem(value: 'referral', child: Text('Referral')),
                  DropdownMenuItem(value: 'insurance', child: Text('Insurance')),
                  DropdownMenuItem(value: 'bill', child: Text('Hospital bill')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setLocal(() => category = v ?? category),
              ),
              SizedBox(height: 10),
              TextField(controller: desc, maxLines: 2, decoration: InputDecoration(labelText: 'Description')),
              SizedBox(height: 12),
              _InfoBox(text: 'Prescription OCR is saved as a draft first. Medicines only enter the patient record after a person checks and confirms them.'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Upload')),
          ],
        ),
      ),
    );
    if (proceed != true) return;

    setState(() => uploading = true);
    try {
      final form = FormData.fromMap({
        'patient_id': patientId,
        'category': category,
        'description': desc.text.trim(),
        'file': MultipartFile.fromBytes(f.bytes!, filename: f.name),
      });
      await Api.dio.post('/api/v1/documents/upload', data: form, options: Options(contentType: 'multipart/form-data'));
      if (mounted) showMessage(context, 'Document uploaded securely.');
      await loadDocs();
    } catch (e) {
      if (mounted) showMessage(context, Api.errorMessage(e));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<Uint8List?> _previewBytes(Map<String, dynamic> doc) async {
    final mime = doc['mime_type']?.toString() ?? '';
    if (!mime.startsWith('image/')) return null;
    try {
      final response = await Api.dio.get<List<int>>(
        '/api/v1/documents/${doc['id']}/download',
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.data == null) return null;
      return Uint8List.fromList(response.data!);
    } catch (_) {
      return null;
    }
  }

  Future<void> runOcr(Map<String, dynamic> doc) async {
    setState(() => runningOcrId = doc['id']?.toString());
    try {
      final results = await Future.wait([
        Api.dio.post('/api/v1/documents/${doc['id']}/ocr'),
        _previewBytes(doc),
      ]);
      final response = results[0] as Response<dynamic>;
      final preview = results[1] as Uint8List?;
      final result = Map<String, dynamic>.from(response.data as Map);
      final ocr = Map<String, dynamic>.from(result['ocr'] as Map);
      final engine = Map<String, dynamic>.from(result['engine'] as Map);
      final draftRaw = result['prescription_draft'];
      if (!mounted) return;

      if (draftRaw is Map) {
        await _reviewPrescription(
          doc: doc,
          ocr: ocr,
          engine: engine,
          draft: Map<String, dynamic>.from(draftRaw),
          previewBytes: preview,
        );
      } else {
        await _reviewGenericOcr(ocr: ocr, engine: engine);
      }
    } catch (e) {
      if (mounted) showMessage(context, Api.errorMessage(e));
    } finally {
      if (mounted) setState(() => runningOcrId = null);
    }
  }

  Future<void> _reviewGenericOcr({required Map<String, dynamic> ocr, required Map<String, dynamic> engine}) async {
    final text = TextEditingController(text: ocr['raw_text']?.toString() ?? '');
    final verify = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('OCR review required'),
        content: SizedBox(
          width: double.maxFinite,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _InfoBox(text: engine['message']?.toString() ?? 'Verify extracted text against the original.'),
                SizedBox(height: 10),
                Text('OCR confidence: ${_overallConfidence(ocr['confidence'])}'),
                SizedBox(height: 12),
                TextField(
                  controller: text,
                  minLines: 8,
                  maxLines: 18,
                  decoration: InputDecoration(labelText: 'Extracted text'),
                ),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep as draft')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Verify text')),
        ],
      ),
    );
    if (verify == true) {
      await Api.dio.post('/api/v1/documents/ocr/${ocr['id']}/verify', data: {'confirmed_text': text.text});
      if (mounted) showMessage(context, 'OCR text verified.');
    }
  }

  Future<void> _reviewPrescription({
    required Map<String, dynamic> doc,
    required Map<String, dynamic> ocr,
    required Map<String, dynamic> engine,
    required Map<String, dynamic> draft,
    required Uint8List? previewBytes,
  }) async {
    final doctor = TextEditingController(text: draft['doctor_name']?.toString() ?? '');
    final prescriptionDate = TextEditingController(text: draft['prescription_date']?.toString() ?? '');
    final items = List<dynamic>.from((draft['items'] as List?) ?? [])
        .map((raw) => _DraftMedicine.fromMap(Map<String, dynamic>.from(raw as Map)))
        .toList();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(children: [Icon(Icons.document_scanner_outlined), SizedBox(width: 9), Text('Review prescription OCR')]),
          content: SizedBox(
            width: double.maxFinite,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 980, maxHeight: MediaQuery.sizeOf(ctx).height * .72),
              child: Column(
                children: [
                  _InfoBox(text: engine['message']?.toString() ?? 'Review every field against the original prescription.'),
                SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final split = constraints.maxWidth >= 820;
                      final original = _OriginalDocumentPane(doc: doc, previewBytes: previewBytes, rawText: ocr['raw_text']?.toString() ?? '');
                      final review = _ReviewFieldsPane(
                        doctor: doctor,
                        prescriptionDate: prescriptionDate,
                        items: items,
                        onAdd: () => setLocal(() => items.add(_DraftMedicine.empty())),
                        onRemove: (index) => setLocal(() => items.removeAt(index)),
                        onChanged: () => setLocal(() {}),
                      );
                      if (split) return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(flex: 4, child: original), SizedBox(width: 14), Expanded(flex: 6, child: review)]);
                      return ListView(children: [SizedBox(height: 280, child: original), SizedBox(height: 14), SizedBox(height: 520, child: review)]);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep as draft')),
          FilledButton.icon(
            onPressed: items.any((x) => x.include && x.name.text.trim().isNotEmpty) ? () => Navigator.pop(ctx, true) : null,
            icon: Icon(Icons.verified_rounded),
            label: Text('Confirm & save medicines'),
          ),
        ],
      ),
    ),
  );

    if (confirmed != true) return;
    try {
      final payloadItems = items.where((x) => x.include).map((x) => x.toPayload()).toList();
      final response = await Api.dio.post('/api/v1/documents/ocr/${ocr['id']}/confirm-prescription', data: {
        'doctor_name': _nullIfEmpty(doctor.text),
        'prescription_date': _nullIfEmpty(prescriptionDate.text),
        'items': payloadItems,
      });
      final count = (response.data as Map)['medicine_count'] ?? payloadItems.length;
      if (!mounted) return;
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Prescription saved'),
          content: Text('$count verified medicine${count == 1 ? '' : 's'} added to this patient’s Medicine Centre.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Stay here')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Open Medicine Centre')),
          ],
        ),
      );
      if (open == true && mounted) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => MedicineCentrePage(initialPatientId: patientId)));
      }
      await loadDocs();
    } catch (e) {
      if (mounted) showMessage(context, Api.errorMessage(e));
    }
  }

  String _overallConfidence(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
    if (n == null) return 'not available';
    final percent = n > 1 ? n : n * 100;
    return '${percent.toStringAsFixed(0)}%';
  }

  String? _nullIfEmpty(String value) => value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 700 ? 16.0 : 28.0;
    final prescriptions = docs.where((d) => d['category']?.toString() == 'prescription').length;

    return RefreshIndicator(
      onRefresh: loadDocs,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 26, pad, 42),
        children: [
          CxPageHeader(
            icon: Icons.document_scanner_rounded,
            eyebrow: 'Document intelligence',
            title: 'Documents & OCR',
            subtitle: 'Turn uploaded prescriptions and reports into reviewable structured data while keeping the original source beside every extraction.',
            actions: [
              OutlinedButton.icon(onPressed: loadDocs, icon: Icon(Icons.refresh_rounded), label: Text('Refresh')),
              FilledButton.icon(onPressed: uploading ? null : upload, icon: Icon(Icons.add_photo_alternate_outlined), label: Text(uploading ? 'Uploading…' : 'Scan / upload')),
            ],
          ),
          SizedBox(height: 16),
          CxSpotlightHero(
            eyebrow: 'Clinexa document pipeline',
            title: 'From prescription image to verified medicines.',
            subtitle: 'OCR stays a draft until a person checks the detected medicine, strength, frequency, route and duration against the source. Verified items then flow into that patient’s Medicine Centre.',
            icon: Icons.auto_fix_high_rounded,
            stats: [
              CxHeroStat(value: '${docs.length}', label: 'Documents', icon: Icons.folder_copy_outlined),
              CxHeroStat(value: '$prescriptions', label: 'Prescriptions', icon: Icons.receipt_long_outlined),
              CxHeroStat(value: '${patients.length}', label: 'Patients', icon: Icons.people_outline_rounded),
            ],
          ),
          SizedBox(height: 16),
          CxAdaptiveGrid(
            minItemWidth: 225,
            maxColumns: 3,
            children: [
              _WorkflowStep(number: '01', icon: Icons.add_a_photo_outlined, title: 'Capture', message: 'Upload a photo, image or PDF and keep the original in the record vault.'),
              _WorkflowStep(number: '02', icon: Icons.document_scanner_outlined, title: 'Extract', message: 'OCR detects source text and proposes structured prescription fields without guessing unreadable content.'),
              _WorkflowStep(number: '03', icon: Icons.verified_user_outlined, title: 'Verify & save', message: 'Review every medicine, then explicitly confirm before anything reaches the permanent medication record.'),
            ],
          ),
          SizedBox(height: 16),
          if (patients.isEmpty)
            CxSurface(child: CxEmptyState(icon: Icons.person_add_alt_1_outlined, title: 'Add a patient first', message: 'Documents must be linked to a patient record before they can be uploaded.'))
          else ...[
            CxSurface(
              padding: EdgeInsets.all(14),
              child: Row(children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(gradient: ClinexaTheme.accentGradient, borderRadius: BorderRadius.circular(13)), child: Icon(Icons.person_search_rounded, color: Colors.white, size: 20)),
                SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(isExpanded: true, 
                    value: patientId,
                    decoration: InputDecoration(labelText: 'Patient record', filled: false),
                    items: patients.map((p) => DropdownMenuItem<String>(value: p['id'].toString(), child: Text('${p['full_name']} • ${p['patient_code']}'))).toList(),
                    onChanged: (v) async { setState(() => patientId = v); await loadDocs(); },
                  ),
                ),
              ]),
            ),
            if (error != null) ...[SizedBox(height: 12), CxErrorBanner(message: error!, onRetry: loadDocs)],
            SizedBox(height: 16),
            CxSurface(
              elevated: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CxSectionHeader(
                  title: 'Patient document vault',
                  subtitle: 'Open OCR only when useful; prescription extraction remains human-reviewed.',
                  action: CxStatusChip(label: '${docs.length} files', icon: Icons.folder_outlined),
                ),
                SizedBox(height: 14),
                if (docs.isEmpty)
                  CxEmptyState(icon: Icons.upload_file_rounded, title: 'No documents yet', message: 'Upload a prescription, laboratory report, discharge summary or other supported record.')
                else
                  ...docs.map((raw) {
                    final d = Map<String, dynamic>.from(raw as Map);
                    final busy = runningOcrId == d['id']?.toString();
                    return _DocumentCard(
                      doc: d,
                      busy: busy,
                      onOcr: () => runOcr(d),
                    );
                  }),
              ]),
            ),
            SizedBox(height: 14),
            CxSurface(
              color: Theme.of(context).colorScheme.primaryContainer,
              border: Border.all(color: ClinexaTheme.primary.withValues(alpha: .12)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.shield_outlined, color: ClinexaTheme.primary),
                SizedBox(width: 11),
                Expanded(child: Text('Clinical safety: unreadable content stays uncertain. OCR and the medicine catalog can suggest a match, but Clinexa does not silently create or change a dose. Prescription fields require explicit confirmation.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 10.8, height: 1.5))),
              ]),
            ),
          ],
        ],
      ),
    );
  }

}

class _WorkflowStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String message;
  const _WorkflowStep({required this.number, required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) => CxSurface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: ClinexaTheme.primary, size: 19)),
            Spacer(),
            Text(number, style: TextStyle(color: Color(0xFFB3BEC8), fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -1)),
          ]),
          SizedBox(height: 14),
          Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          SizedBox(height: 5),
          Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.3, height: 1.45)),
        ]),
      );
}

class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final bool busy;
  final VoidCallback onOcr;
  const _DocumentCard({required this.doc, required this.busy, required this.onOcr});

  @override
  Widget build(BuildContext context) {
    final prescription = doc['category']?.toString() == 'prescription';
    final tone = prescription ? ClinexaTheme.primary : ClinexaTheme.accent;
    return Container(
      margin: EdgeInsets.only(bottom: 9),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(17), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 590;
        final info = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: tone.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)), child: Icon(prescription ? Icons.medication_outlined : Icons.description_outlined, color: tone, size: 20)),
          SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc['original_name']?.toString() ?? 'Document', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.8)),
            SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 5, children: [
              CxStatusChip(label: _prettyCategory(doc['category']?.toString() ?? 'other'), color: tone),
              if (doc['created_at'] != null) CxStatusChip(label: doc['created_at'].toString().split('T').first, color: Theme.of(context).colorScheme.onSurfaceVariant, icon: Icons.schedule_rounded),
            ]),
          ])),
        ]);
        final action = FilledButton.tonalIcon(
          onPressed: busy ? null : onOcr,
          icon: busy ? SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.document_scanner_outlined, size: 18),
          label: Text(busy ? 'Reading…' : prescription ? 'Extract medicines' : 'Run OCR'),
        );
        if (compact) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, SizedBox(height: 10), action]);
        return Row(children: [Expanded(child: info), SizedBox(width: 12), action]);
      }),
    );
  }

  static String _prettyCategory(String value) => value.replaceAll('_', ' ').split(' ').map((x) => x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}').join(' ');
}

class _OriginalDocumentPane extends StatelessWidget {
  final Map<String, dynamic> doc;
  final Uint8List? previewBytes;
  final String rawText;
  const _OriginalDocumentPane({required this.doc, required this.previewBytes, required this.rawText});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Original source', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
        SizedBox(height: 3),
        Text(doc['original_name']?.toString() ?? 'Document', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
        SizedBox(height: 10),
        Expanded(
          child: previewBytes != null
              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: InteractiveViewer(minScale: .8, maxScale: 5, child: Image.memory(previewBytes!, fit: BoxFit.contain)))
              : Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(12)),
                  child: SingleChildScrollView(child: Text(rawText.isEmpty ? 'Preview unavailable for this file type. The original document remains stored in Clinexa.' : rawText, style: TextStyle(fontSize: 11.5, height: 1.45, color: scheme.onSurface))),
                ),
        ),
      ]),
    );
  }
}

class _ReviewFieldsPane extends StatelessWidget {
  final TextEditingController doctor;
  final TextEditingController prescriptionDate;
  final List<_DraftMedicine> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final VoidCallback onChanged;
  const _ReviewFieldsPane({required this.doctor, required this.prescriptionDate, required this.items, required this.onAdd, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text('Structured review', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: scheme.onSurface))), TextButton.icon(onPressed: onAdd, icon: Icon(Icons.add_rounded), label: Text('Add row'))]),
        SizedBox(height: 8),
        Row(children: [Expanded(child: TextField(controller: doctor, decoration: InputDecoration(labelText: 'Doctor as written'))), SizedBox(width: 10), Expanded(child: TextField(controller: prescriptionDate, decoration: InputDecoration(labelText: 'Prescription date as written')))]),
        SizedBox(height: 12),
        Expanded(
          child: items.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.manage_search_rounded, size: 36, color: scheme.onSurfaceVariant), SizedBox(height: 8), Text('No medicine lines could be extracted safely.', style: TextStyle(color: scheme.onSurfaceVariant)), SizedBox(height: 8), FilledButton.tonalIcon(onPressed: onAdd, icon: Icon(Icons.add), label: Text('Add from original'))]))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) => _MedicineEditor(item: items[index], onRemove: () => onRemove(index), onChanged: onChanged),
                ),
        ),
      ]),
    );
  }
}

class _MedicineEditor extends StatelessWidget {
  final _DraftMedicine item;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _MedicineEditor({required this.item, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confidence = item.confidence == null ? null : (item.confidence! * 100).clamp(0, 100).toDouble();
    final cardBg = item.uncertain
        ? (isDark ? const Color(0xFF2C2414) : const Color(0xFFFFFAEC))
        : (isDark ? scheme.surfaceContainerHigh : const Color(0xFFF8FAFC));
    final cardBorder = item.uncertain
        ? (isDark ? const Color(0xFF7E5B10) : const Color(0xFFF0D99A))
        : scheme.outlineVariant;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Checkbox(value: item.include, onChanged: (v) { item.include = v ?? true; onChanged(); }),
          Expanded(child: Text(item.sourceLine.isEmpty ? 'Manually added medicine' : item.sourceLine, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant))),
          if (confidence != null) _ConfidenceBadge(value: confidence, uncertain: item.uncertain),
          IconButton(onPressed: onRemove, icon: Icon(Icons.close_rounded, size: 19)),
        ]),
        if (item.include) ...[
          SizedBox(height: 6),
          TextField(controller: item.name, decoration: InputDecoration(labelText: 'Medicine name *')),
          if (item.catalogMatches.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: scheme.primaryContainer.withValues(alpha: .35), borderRadius: BorderRadius.circular(13), border: Border.all(color: scheme.primary.withValues(alpha: .25))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(Icons.auto_fix_high_rounded, size: 16, color: ClinexaTheme.primary), SizedBox(width: 6), Text('Possible formulary matches', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: scheme.onSurface))]),
                SizedBox(height: 7),
                Wrap(spacing: 6, runSpacing: 6, children: item.catalogMatches.map((match) {
                  final score = ((match['match_score'] as num?)?.toDouble() ?? 0) * 100;
                  return ActionChip(
                    avatar: Icon(Icons.medication_outlined, size: 15),
                    label: Text('${match['display_name'] ?? match['generic_name']} ${score.toStringAsFixed(0)}%'),
                    onPressed: () {
                      item.name.text = match['generic_name']?.toString() ?? item.name.text;
                      if (item.strength.text.trim().isEmpty && match['strength'] != null) item.strength.text = match['strength'].toString();
                      if (item.form.text.trim().isEmpty && match['form'] != null) item.form.text = match['form'].toString();
                      onChanged();
                    },
                  );
                }).toList()),
                SizedBox(height: 6),
                Text('Suggestions are local catalog matches only. They never replace OCR text until you select one.', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 9.5, height: 1.35)),
              ]),
            ),
          ],
          SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: item.strength, decoration: InputDecoration(labelText: 'Strength'))),
            SizedBox(width: 8),
            Expanded(child: TextField(controller: item.form, decoration: InputDecoration(labelText: 'Form'))),
          ]),
          SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: item.frequency, decoration: InputDecoration(labelText: 'Frequency'))),
            SizedBox(width: 8),
            Expanded(child: TextField(controller: item.route, decoration: InputDecoration(labelText: 'Route'))),
            SizedBox(width: 8),
            Expanded(child: TextField(controller: item.duration, decoration: InputDecoration(labelText: 'Duration'))),
          ]),
          SizedBox(height: 8),
          TextField(controller: item.instructions, maxLines: 2, decoration: InputDecoration(labelText: 'Instructions / source line')),
          SizedBox(height: 8),
          TextField(controller: item.reminderTimes, decoration: InputDecoration(labelText: 'Exact reminder times (optional)', hintText: '09:00,21:00')),
        ],
      ]),
    );
  }
}

class _DraftMedicine {
  final String? id;
  final String sourceLine;
  final double? confidence;
  final bool uncertain;
  final List<Map<String, dynamic>> catalogMatches;
  bool include;
  final TextEditingController name;
  final TextEditingController strength;
  final TextEditingController form;
  final TextEditingController frequency;
  final TextEditingController route;
  final TextEditingController duration;
  final TextEditingController instructions;
  final TextEditingController reminderTimes;

  _DraftMedicine({
    required this.id,
    required this.sourceLine,
    required this.confidence,
    required this.uncertain,
    required this.catalogMatches,
    required this.include,
    required this.name,
    required this.strength,
    required this.form,
    required this.frequency,
    required this.route,
    required this.duration,
    required this.instructions,
    required this.reminderTimes,
  });

  factory _DraftMedicine.fromMap(Map<String, dynamic> map) => _DraftMedicine(
        id: map['id']?.toString(),
        sourceLine: map['source_line']?.toString() ?? '',
        confidence: (map['confidence'] as num?)?.toDouble(),
        uncertain: map['uncertain'] == true,
        catalogMatches: List<dynamic>.from((map['catalog_matches'] as List?) ?? []).map((x) => Map<String, dynamic>.from(x as Map)).toList(),
        include: map['include'] != false,
        name: TextEditingController(text: map['medication_name']?.toString() ?? ''),
        strength: TextEditingController(text: map['strength']?.toString() ?? ''),
        form: TextEditingController(text: map['form']?.toString() ?? ''),
        frequency: TextEditingController(text: map['frequency']?.toString() ?? ''),
        route: TextEditingController(text: map['route']?.toString() ?? ''),
        duration: TextEditingController(text: map['duration']?.toString() ?? ''),
        instructions: TextEditingController(text: map['instructions']?.toString() ?? ''),
        reminderTimes: TextEditingController(),
      );

  factory _DraftMedicine.empty() => _DraftMedicine(
        id: null,
        sourceLine: '',
        confidence: 1,
        uncertain: false,
        catalogMatches: [],
        include: true,
        name: TextEditingController(),
        strength: TextEditingController(),
        form: TextEditingController(),
        frequency: TextEditingController(),
        route: TextEditingController(),
        duration: TextEditingController(),
        instructions: TextEditingController(),
        reminderTimes: TextEditingController(),
      );

  Map<String, dynamic> toPayload() => {
        'item_id': id,
        'include': include,
        'medication_name': name.text.trim(),
        'strength': _n(strength.text),
        'form': _n(form.text),
        'frequency': _n(frequency.text),
        'route': _n(route.text),
        'duration': _n(duration.text),
        'instructions': _n(instructions.text),
        'reminder_times': _n(reminderTimes.text),
        'status': 'active',
      };

  static String? _n(String value) => value.trim().isEmpty ? null : value.trim();
}

class _ConfidenceBadge extends StatelessWidget {
  final double value;
  final bool uncertain;
  const _ConfidenceBadge({required this.value, required this.uncertain});
  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(left: 6),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: uncertain ? Theme.of(context).colorScheme.surfaceContainerLow : Color(0xFFE7F4EE), borderRadius: BorderRadius.circular(999)),
        child: Text('${value.toStringAsFixed(0)}% ${uncertain ? 'check' : 'OCR'}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
      );
}

class _InfoBox extends StatelessWidget {
  final String text;
  const _InfoBox({required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(13), border: Border.all(color: Color(0xFFE2E8F0))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, size: 18), SizedBox(width: 8), Expanded(child: Text(text, style: TextStyle(fontSize: 11.5, height: 1.4)))]),
      );
}
