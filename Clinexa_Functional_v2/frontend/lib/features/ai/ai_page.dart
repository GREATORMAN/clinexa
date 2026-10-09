import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';
import '../../core/widgets/section_page.dart';

/// Represents a single message in the clinical AI conversation.
class AiChatMessage {
  final String role; // 'user' | 'assistant'
  final String text;
  final DateTime timestamp;
  final String? patientName;
  final String? headline;
  final List<String> summaryPoints;
  final String? clinicalDetail;
  final Map<String, dynamic>? guardrail;
  final String? patientContextApplied;
  final List<Map<String, dynamic>> suggestedActions;
  final List<String> followupQuestions;
  final String? disclaimer;
  final String? provider;
  final bool isError;

  AiChatMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.patientName,
    this.headline,
    this.summaryPoints = const [],
    this.clinicalDetail,
    this.guardrail,
    this.patientContextApplied,
    this.suggestedActions = const [],
    this.followupQuestions = const [],
    this.disclaimer,
    this.provider,
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final TextEditingController ctrl = TextEditingController();
  final ScrollController scrollCtrl = ScrollController();
  final List<AiChatMessage> messages = [];

  Map<String, dynamic>? status;
  List<dynamic> patients = [];
  List<dynamic> doctors = [];
  String? selectedPatientId;
  bool loading = false;
  bool bootstrapping = true;

  @override
  void initState() {
    super.initState();
    bootstrap();
  }

  @override
  void dispose() {
    ctrl.dispose();
    scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> bootstrap() async {
    setState(() => bootstrapping = true);
    try {
      final r = await Future.wait([
        Api.dio.get('/api/v1/ai/status'),
        Api.dio.get('/api/v1/patients'),
        Api.dio.get('/api/v1/doctors'),
      ]);
      if (mounted) {
        setState(() {
          status = Map<String, dynamic>.from(r[0].data);
          patients = List.from(r[1].data);
          doctors = List.from(r[2].data);
          bootstrapping = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          status = {'online': false, 'engine': 'Clinexa Clinical Engine', 'engine_online': true};
          bootstrapping = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollCtrl.hasClients) {
        scrollCtrl.animateTo(
          scrollCtrl.position.maxScrollExtent + 200,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  Map<String, dynamic>? get _selectedPatient {
    if (selectedPatientId == null) return null;
    try {
      return patients.firstWhere((p) => p['id'].toString() == selectedPatientId);
    } catch (_) {
      return null;
    }
  }

  Future<void> send([String? overrideText]) async {
    final query = (overrideText ?? ctrl.text).trim();
    if (query.isEmpty || loading) return;

    final attachedPatient = _selectedPatient;
    final patientLabel = attachedPatient != null ? attachedPatient['full_name']?.toString() : null;

    setState(() {
      messages.add(AiChatMessage(
        role: 'user',
        text: query,
        patientName: patientLabel,
      ));
      if (overrideText == null) ctrl.clear();
      loading = true;
    });
    _scrollToBottom();

    try {
      final payload = {
        'message': query,
        if (selectedPatientId != null) 'patient_id': selectedPatientId,
      };

      final r = await Api.dio.post('/api/v1/ai/chat', data: payload);
      final data = Map<String, dynamic>.from(r.data);

      final summaryList = (data['summary_points'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final actionsList = (data['suggested_actions'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
      final followupsList = (data['followup_questions'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final guardrailData = data['guardrail'] is Map ? Map<String, dynamic>.from(data['guardrail']) : null;

      if (mounted) {
        setState(() {
          messages.add(AiChatMessage(
            role: 'assistant',
            text: data['answer']?.toString() ?? data['clinical_detail']?.toString() ?? '',
            headline: data['headline']?.toString(),
            summaryPoints: summaryList,
            clinicalDetail: data['clinical_detail']?.toString(),
            guardrail: guardrailData,
            patientContextApplied: data['patient_context_applied']?.toString(),
            suggestedActions: actionsList,
            followupQuestions: followupsList,
            disclaimer: data['disclaimer']?.toString(),
            provider: data['provider']?.toString(),
          ));
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          messages.add(AiChatMessage(
            role: 'assistant',
            text: Api.errorMessage(e),
            isError: true,
          ));
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
      _scrollToBottom();
    }
  }

  Future<DateTime?> pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> aiBooking({String? initialPatientId, String? defaultReason}) async {
    if (patients.isEmpty || doctors.isEmpty) {
      showMessage(context, 'Add a patient and doctor first.');
      return;
    }
    String patientId = initialPatientId ?? selectedPatientId ?? patients.first['id'].toString();
    String doctorId = doctors.first['id'].toString();
    DateTime start = DateTime.now().add(const Duration(days: 1));
    final reason = TextEditingController(text: defaultReason ?? 'Clinical follow-up');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.event_available_rounded, color: ClinexaTheme.primary),
            const SizedBox(width: 10),
            const Text('AI-Assisted Appointment Booking'),
          ]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: patientId,
                decoration: const InputDecoration(labelText: 'Patient Record'),
                items: patients
                    .map((p) => DropdownMenuItem(
                          value: p['id'].toString(),
                          child: Text('${p['full_name']} (${p['patient_code'] ?? 'PT'})'),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() => patientId = v ?? patientId),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: doctorId,
                decoration: const InputDecoration(labelText: 'Attending Doctor'),
                items: doctors
                    .map((d) => DropdownMenuItem(
                          value: d['id'].toString(),
                          child: Text('${d['full_name']} — ${d['specialty']}'),
                        ))
                    .toList(),
                onChanged: (v) => setLocal(() => doctorId = v ?? doctorId),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Requested Slot Time'),
                subtitle: Text(
                  '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')} at ${TimeOfDay.fromDateTime(start).format(context)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                trailing: const Icon(Icons.edit_calendar_rounded, color: ClinexaTheme.primary),
                onTap: () async {
                  final x = await pickDateTime(start);
                  if (x != null) setLocal(() => start = x);
                },
              ),
              const SizedBox(height: 6),
              TextField(
                controller: reason,
                decoration: const InputDecoration(labelText: 'Clinical Reason / Notes'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Generate Proposal'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final payload = {
      'patient_id': patientId,
      'doctor_id': doctorId,
      'start_at': start.toIso8601String(),
      'appointment_type': 'in_person',
      'reason': reason.text.trim().isEmpty ? null : reason.text.trim(),
      'confirmed': false,
    };

    try {
      final r = await Api.dio.post('/api/v1/ai/propose-booking', data: payload);
      final proposal = Map<String, dynamic>.from(r.data['proposal']);
      if (!mounted) return;

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm Appointment Booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient: ${proposal['patient']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Doctor: ${proposal['doctor']} (${proposal['specialty']})'),
              const SizedBox(height: 4),
              Text('Time: ${proposal['start_at']}'),
              const SizedBox(height: 4),
              Text('Type: ${proposal['appointment_type']}'),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ClinexaTheme.mint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ClinexaTheme.primary.withValues(alpha: 0.2)),
                ),
                child: const Row(children: [
                  Icon(Icons.shield_outlined, size: 18, color: ClinexaTheme.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Clinexa locks the slot and saves to database only after this confirmation.',
                      style: TextStyle(fontSize: 12, color: ClinexaTheme.primary),
                    ),
                  ),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm & Book')),
          ],
        ),
      );

      if (confirm == true) {
        payload['confirmed'] = true;
        await Api.dio.post('/api/v1/ai/propose-booking', data: payload);
        if (mounted) showMessage(context, 'Appointment booked and confirmed successfully.');
      }
    } catch (e) {
      if (mounted) showMessage(context, Api.errorMessage(e));
    }
  }

  void _handleAction(String action) {
    if (action == 'book_consult') {
      aiBooking();
    } else if (action == 'emergency_dial') {
      _showEmergencyHotlineDialog();
    } else if (action == 'meds') {
      _showMedicationsDialog();
    } else if (action == 'labs') {
      _showLabsDialog();
    } else if (action == 'patient_360') {
      _showPatientDetailsDialog();
    } else if (action == 'chart_summary') {
      send('Summarize this patient\'s active chart, vitals, and medications.');
    } else {
      showMessage(context, 'Navigating to $action...');
    }
  }

  void _showEmergencyHotlineDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF1F2),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: ClinexaTheme.emergency, size: 28),
          SizedBox(width: 10),
          Text('Emergency Medical Protocol', style: TextStyle(color: ClinexaTheme.emergency, fontWeight: FontWeight.w800)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            'If you or the patient are experiencing life-threatening symptoms, immediately dial emergency dispatch:',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          _emergencyPhoneRow('108', 'National Ambulance Service (Emergency ER)'),
          const SizedBox(height: 10),
          _emergencyPhoneRow('112', 'Universal National Emergency Dispatch'),
          const SizedBox(height: 10),
          _emergencyPhoneRow('102', 'Pregnant Mothers & Infant Transport Hotline'),
          const SizedBox(height: 10),
          _emergencyPhoneRow('911', 'International Emergency Dispatch'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ClinexaTheme.emergency.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.medical_services_rounded, color: ClinexaTheme.emergency, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Have the Clinexa NFC Emergency Tag or Patient Code ready for the triage team upon arrival.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF881337)),
                ),
              ),
            ]),
          ),
        ]),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ClinexaTheme.emergency),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood / Close'),
          ),
        ],
      ),
    );
  }

  Widget _emergencyPhoneRow(String number, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: ClinexaTheme.emergency, borderRadius: BorderRadius.circular(8)),
          child: Text(number, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  void _showMedicationsDialog() {
    final p = _selectedPatient;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.medication_rounded, color: ClinexaTheme.primary),
          const SizedBox(width: 10),
          Text(p != null ? 'Medications • ${p['full_name']}' : 'Medication Centre Reference'),
        ]),
        content: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p != null) ...[
              Text('Documented Allergies: ${p['allergies'] ?? 'None recorded'}', style: const TextStyle(fontWeight: FontWeight.w700, color: ClinexaTheme.warning)),
              const SizedBox(height: 8),
              Text('Current Meds Note: ${p['current_medications'] ?? 'No active regimen documented'}'),
            ] else ...[
              const Text('Select a patient from the top bar to inspect their verified electronic medication schedule.'),
            ],
            const SizedBox(height: 16),
            const Text(
              '⚠️ Reminder: Dose titrations, refills, and Schedule II-IV drug orders require authorized clinician signature.',
              style: TextStyle(fontSize: 11.5, color: ClinexaTheme.muted, fontStyle: FontStyle.italic),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showLabsDialog() {
    final p = _selectedPatient;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.science_rounded, color: ClinexaTheme.primary),
          const SizedBox(width: 10),
          Text(p != null ? 'Lab Biomarkers • ${p['full_name']}' : 'Diagnostic Laboratory Standards'),
        ]),
        content: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (p != null) ...[
              Text('Blood Group: ${p['blood_group'] ?? 'Not recorded'}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Ask Clinexa AI: "Interpret recent labs for this patient" or "Check HbA1c reference range".'),
            ] else ...[
              const Text('Reference Standards:\n• HbA1c: < 5.7% (Normal), 5.7–6.4% (Pre-DM), ≥ 6.5% (Diabetes)\n• Fasting Glucose: 70–99 mg/dL\n• Creatinine: 0.7–1.3 mg/dL\n• eGFR: > 90 mL/min/1.73m²'),
            ],
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showPatientDetailsDialog() {
    final p = _selectedPatient;
    if (p == null) {
      showMessage(context, 'Select a patient first from the top selector.');
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.badge_rounded, color: ClinexaTheme.primary),
          const SizedBox(width: 10),
          Text(p['full_name']?.toString() ?? 'Patient Record'),
        ]),
        content: SizedBox(
          width: 480,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Patient Code: ${p['patient_code'] ?? 'N/A'}'),
            const SizedBox(height: 4),
            Text('Gender: ${p['gender'] ?? 'Not recorded'}'),
            const SizedBox(height: 4),
            Text('Blood Group: ${p['blood_group'] ?? 'Not recorded'}'),
            const SizedBox(height: 4),
            Text('Allergies: ${p['allergies'] ?? 'None documented'}'),
            const SizedBox(height: 4),
            Text('Conditions: ${p['conditions'] ?? 'None recorded'}'),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.pop(ctx);
                send('Summarize this patient\'s active chart, vitals, and medications.');
              },
              icon: const Icon(Icons.summarize_rounded, size: 18),
              label: const Text('Generate Full AI Chart Summary'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _clearChat() {
    setState(() => messages.clear());
    showMessage(context, 'Chat history cleared.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOllamaOnline = status?['online'] == true;
    final selectedPat = _selectedPatient;

    return SectionPage(
      title: 'Clinical AI Assistant',
      subtitle: 'Guardrailed decision support grounded in EHR patient records',
      actions: [
        if (messages.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Clear Chat'),
          ),
        FilledButton.tonalIcon(
          onPressed: () => aiBooking(),
          icon: const Icon(Icons.event_available_rounded, size: 18),
          label: const Text('AI Booking'),
        ),
      ],
      child: Column(children: [
        // 1. Top Status & Patient Context Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: CxSurface(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            radius: 18,
            child: Row(children: [
              // AI Core Status Indicator
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOllamaOnline ? ClinexaTheme.success : ClinexaTheme.primaryBright,
                  boxShadow: [
                    BoxShadow(
                      color: (isOllamaOnline ? ClinexaTheme.success : ClinexaTheme.primaryBright).withValues(alpha: 0.5),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    isOllamaOnline
                        ? 'Ollama Neural Core (${status?['model'] ?? 'active'})'
                        : 'Clinexa Clinical Knowledge Engine (Grounded & Offline-Ready)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '🛡️ 5-Layer Guardrails Active: Emergency • Prescribing • Allergies • Drug Interactions • Grounding',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: ClinexaTheme.muted),
                  ),
                ]),
              ),
              const SizedBox(width: 16),
              // Patient Context Dropdown
              Container(
                constraints: const BoxConstraints(maxWidth: 260),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedPatientId != null ? ClinexaTheme.primary : scheme.outlineVariant,
                    width: selectedPatientId != null ? 1.5 : 1.0,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: selectedPatientId,
                    isDense: true,
                    isExpanded: true,
                    hint: const Row(children: [
                      Icon(Icons.person_search_rounded, size: 16, color: ClinexaTheme.muted),
                      SizedBox(width: 6),
                      Text('Select Patient Chart', style: TextStyle(fontSize: 12)),
                    ]),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('🌐 General Medical Reference', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      ...patients.map((p) => DropdownMenuItem<String?>(
                            value: p['id'].toString(),
                            child: Text(
                              '👤 ${p['full_name']} (${p['patient_code'] ?? 'PT'})',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() => selectedPatientId = val);
                    },
                  ),
                ),
              ),
              if (selectedPatientId != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Clear Patient Context',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() => selectedPatientId = null),
                ),
              ],
            ]),
          ),
        ),

        // 2. Active Patient Banner (if selected)
        if (selectedPat != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: ClinexaTheme.mint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ClinexaTheme.primary.withValues(alpha: 0.25)),
              ),
              child: Row(children: [
                const Icon(Icons.folder_shared_rounded, size: 18, color: ClinexaTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Active Chart: ${selectedPat['full_name']} (${selectedPat['patient_code'] ?? 'PT'})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: ClinexaTheme.primary),
                ),
                const SizedBox(width: 14),
                Text('Blood: ${selectedPat['blood_group'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: Color(0xFF134E4A))),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Allergies: ${selectedPat['allergies'] ?? 'None recorded'}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ClinexaTheme.warning),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                  onPressed: () => send('Summarize this patient\'s active chart, vitals, and medications.'),
                  icon: const Icon(Icons.auto_stories_rounded, size: 14, color: ClinexaTheme.primary),
                  label: const Text('Summarize Chart', style: TextStyle(fontSize: 11, color: ClinexaTheme.primary)),
                ),
              ]),
            ),
          ),

        // 3. Conversation Area or Welcome Screen
        Expanded(
          child: messages.isEmpty
              ? _buildWelcomeHero(context)
              : ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return msg.role == 'user'
                        ? _buildUserMessageBubble(context, msg)
                        : _buildAssistantReplyCard(context, msg);
                  },
                ),
        ),

        // 4. Loading Shimmer Indicator
        if (loading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: ClinexaTheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Analyzing EHR records, safety guardrails & pharmacology guidelines...',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
              ),
            ]),
          ),

        // 5. Input Field Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
          child: Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Row(children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.auto_awesome_rounded, color: ClinexaTheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      onSubmitted: (_) => send(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: selectedPat != null
                            ? 'Ask about ${selectedPat['full_name']}\'s chart, labs, meds, or interactions...'
                            : 'Ask clinical guidance, lab ranges, or appointment booking...',
                        hintStyle: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant.withValues(alpha: 0.8)),
                      ),
                    ),
                  ),
                  if (ctrl.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => ctrl.clear(),
                    ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filled(
              style: IconButton.styleFrom(
                backgroundColor: ClinexaTheme.primary,
                padding: const EdgeInsets.all(14),
              ),
              onPressed: loading ? null : () => send(),
              icon: loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            ),
          ]),
        ),
      ]),
    );
  }

  // -------------------------------------------------------------
  // WELCOME HERO & STARTER PROMPTS
  // -------------------------------------------------------------
  Widget _buildWelcomeHero(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                gradient: ClinexaTheme.accentGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: ClinexaTheme.primary.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 16),
            Text(
              'Clinexa Clinical AI Decision Support',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text(
                'Enterprise medical co-pilot engineered for real-time EHR chart synthesis, evidence-based pharmacology, diagnostic interpretation, and zero-compromise safety guardrails.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.5),
              ),
            ),
            const SizedBox(height: 20),

            // 5 Safety Pillars Badge Row
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: const [
              CxStatusChip(label: '🚨 Emergency Triage Flag', color: ClinexaTheme.emergency, icon: Icons.emergency_rounded),
              CxStatusChip(label: '🛡️ No Autonomous Prescribing', color: ClinexaTheme.warning, icon: Icons.block_rounded),
              CxStatusChip(label: '💊 Drug Interaction Shield', color: ClinexaTheme.accent, icon: Icons.medication_liquid_rounded),
              CxStatusChip(label: '📋 EHR Database Grounded', color: ClinexaTheme.primary, icon: Icons.verified_rounded),
            ]),
            const SizedBox(height: 28),

            // Starter Prompts
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'QUICK CLINICAL PROMPTS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.primary, letterSpacing: 1.1),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _starterPromptChip(
                icon: Icons.summarize_rounded,
                title: 'Summarize Patient Record',
                subtitle: 'SOAP synthesis with vitals, meds & labs',
                prompt: 'Summarize the active patient chart with vitals, medications, and recent lab results.',
              ),
              _starterPromptChip(
                icon: Icons.medication_rounded,
                title: 'Analyze Drug Interactions',
                subtitle: 'Screen for ARBs, NSAIDs, anticoagulants',
                prompt: 'Are there any drug-drug interactions or contraindications with active medications?',
              ),
              _starterPromptChip(
                icon: Icons.bloodtype_rounded,
                title: 'HbA1c & Diabetes Targets',
                subtitle: 'ADA glycemic thresholds & eAG correlation',
                prompt: 'Explain HbA1c diagnostic ranges and glycemic targets for diabetes management.',
              ),
              _starterPromptChip(
                icon: Icons.monitor_heart_rounded,
                title: 'Hypertension Management',
                subtitle: 'ACC/AHA blood pressure protocol & Telmisartan',
                prompt: 'What are the ACC/AHA guidelines for Stage 1 and Stage 2 hypertension management?',
              ),
              _starterPromptChip(
                icon: Icons.science_rounded,
                title: 'CBC Diagnostic Biomarkers',
                subtitle: 'Anemia differential & platelet flags',
                prompt: 'Explain what a Complete Blood Count (CBC) measures and interpret key flags.',
              ),
              _starterPromptChip(
                icon: Icons.emergency_rounded,
                title: 'Emergency Triage Check',
                subtitle: 'Chest pain & stroke FAST triage protocol',
                prompt: 'What are the immediate clinical triage protocols for acute chest pain?',
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _starterPromptChip({
    required IconData icon,
    required String title,
    required String subtitle,
    required String prompt,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => send(prompt),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ClinexaTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: ClinexaTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ]),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }

  // -------------------------------------------------------------
  // USER MESSAGE BUBBLE
  // -------------------------------------------------------------
  Widget _buildUserMessageBubble(BuildContext context, AiChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        margin: const EdgeInsets.only(top: 8, bottom: 8, left: 48),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0E6F68), Color(0xFF14534F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(6),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          if (msg.patientName != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.person_pin_rounded, size: 12, color: Colors.white),
                const SizedBox(width: 4),
                Text(
                  'Chart: ${msg.patientName}',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ]),
            ),
          ],
          Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.45, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 10),
          ),
        ]),
      ),
    );
  }

  // -------------------------------------------------------------
  // ASSISTANT REPLY CARD (STRUCTURED & GUARDRAILED)
  // -------------------------------------------------------------
  Widget _buildAssistantReplyCard(BuildContext context, AiChatMessage msg) {
    final scheme = Theme.of(context).colorScheme;
    final guardrail = msg.guardrail;
    final gStatus = guardrail?['status']?.toString();
    final isEmergency = gStatus == 'emergency';
    final isPrescriptionCaution = gStatus == 'prescription_advisory';
    final isAllergyAlert = gStatus == 'allergy_alert';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 860),
        margin: const EdgeInsets.only(top: 8, bottom: 16, right: 32),
        child: CxSurface(
          elevated: true,
          radius: 20,
          padding: const EdgeInsets.all(20),
          border: isEmergency
              ? Border.all(color: ClinexaTheme.emergency, width: 2)
              : isAllergyAlert
                  ? Border.all(color: ClinexaTheme.warning, width: 1.8)
                  : isPrescriptionCaution
                      ? Border.all(color: const Color(0xFFF97316), width: 1.8)
                      : null,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 1. Header: AI Identity + Provider Badge + Copy Button
            Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: isEmergency
                      ? const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF991B1B)])
                      : ClinexaTheme.accentGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEmergency ? Icons.warning_rounded : Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('Clinexa Clinical Assistant', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                    const SizedBox(width: 8),
                    if (msg.provider != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          msg.provider!,
                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
                        ),
                      ),
                  ]),
                  Text(
                    '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
                ]),
              ),
              IconButton(
                tooltip: 'Copy Clinical Note',
                icon: const Icon(Icons.copy_rounded, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: msg.clinicalDetail ?? msg.text));
                  showMessage(context, 'Copied clinical response to clipboard.');
                },
              ),
            ]),
            const SizedBox(height: 14),

            // 2. Guardrail Alert Banner (if applicable)
            if (guardrail != null) ...[
              _buildGuardrailBanner(context, guardrail),
              const SizedBox(height: 14),
            ],

            // 3. Headline
            if (msg.headline != null && msg.headline!.isNotEmpty) ...[
              Text(
                msg.headline!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
              const SizedBox(height: 12),
            ],

            // 4. Key Clinical Takeaways (Summary Box)
            if (msg.summaryPoints.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.checklist_rounded, size: 16, color: ClinexaTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'KEY CLINICAL TAKEAWAYS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scheme.primary, letterSpacing: 0.6),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  ...msg.summaryPoints.map((point) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 4, right: 8),
                            child: Icon(Icons.check_circle_rounded, size: 14, color: ClinexaTheme.primary),
                          ),
                          Expanded(
                            child: FormattedClinicalText(text: point),
                          ),
                        ]),
                      )),
                ]),
              ),
              const SizedBox(height: 14),
            ],

            // 5. Clinical Detail Markdown / Body
            if (msg.clinicalDetail != null && msg.clinicalDetail!.isNotEmpty)
              FormattedClinicalText(text: msg.clinicalDetail!)
            else
              FormattedClinicalText(text: msg.text),

            // 6. Actionable Next Steps (Buttons)
            if (msg.suggestedActions.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'ACTIONABLE CLINICAL NEXT STEPS',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: ClinexaTheme.muted, letterSpacing: 0.8),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ...msg.suggestedActions.map((act) => ActionChip(
                      avatar: Icon(_iconForAction(act['action']?.toString() ?? ''), size: 16),
                      label: Text(act['label']?.toString() ?? 'Action', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                      onPressed: () => _handleAction(act['action']?.toString() ?? ''),
                    )),
              ]),
            ],

            // 7. Interactive Follow-up Prompts
            if (msg.followupQuestions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'RECOMMENDED FOLLOW-UP QUESTIONS',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: ClinexaTheme.muted, letterSpacing: 0.8),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                ...msg.followupQuestions.map((q) => ActionChip(
                      avatar: const Icon(Icons.help_outline_rounded, size: 14, color: ClinexaTheme.primary),
                      label: Text(q, style: const TextStyle(fontSize: 11.5)),
                      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      onPressed: () => send(q),
                    )),
              ]),
            ],

            // 8. Regulatory Clinical Disclaimer
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.gavel_rounded, size: 13, color: ClinexaTheme.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  msg.disclaimer ?? 'Clinexa Decision Support provides authorized clinical reference only. Verify with attending licensed medical personnel.',
                  style: const TextStyle(fontSize: 10.5, color: ClinexaTheme.muted, fontStyle: FontStyle.italic),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildGuardrailBanner(BuildContext context, Map<String, dynamic> guardrail) {
    final status = guardrail['status']?.toString();
    final badge = guardrail['badge']?.toString() ?? 'SAFETY NOTICE';
    final message = guardrail['message']?.toString() ?? '';
    final isEmergency = status == 'emergency';
    final isRx = status == 'prescription_advisory';
    final isAllergy = status == 'allergy_alert';

    final Color bgColor = isEmergency
        ? const Color(0xFFFEF2F2)
        : isAllergy
            ? const Color(0xFFFFFBEB)
            : isRx
                ? const Color(0xFFFFF7ED)
                : const Color(0xFFF0FDF4);

    final Color borderColor = isEmergency
        ? const Color(0xFFF87171)
        : isAllergy
            ? const Color(0xFFFCD34D)
            : isRx
                ? const Color(0xFFFDBA74)
                : const Color(0xFF86EFAC);

    final Color textColor = isEmergency
        ? const Color(0xFF991B1B)
        : isAllergy
            ? const Color(0xFF92400E)
            : isRx
                ? const Color(0xFF9A3412)
                : const Color(0xFF166534);

    final IconData icon = isEmergency
        ? Icons.crisis_alert_rounded
        : isAllergy
            ? Icons.warning_amber_rounded
            : isRx
                ? Icons.lock_outline_rounded
                : Icons.verified_user_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              badge,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w900, fontSize: 11.5, letterSpacing: 0.3),
            ),
          ),
          if (isEmergency)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: ClinexaTheme.emergency,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
              onPressed: _showEmergencyHotlineDialog,
              icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
              label: const Text('Dial 108', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
        ]),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(message, style: TextStyle(color: textColor.withValues(alpha: 0.9), fontSize: 11.5, height: 1.4)),
        ],
      ]),
    );
  }

  IconData _iconForAction(String action) {
    if (action.contains('consult') || action.contains('book')) return Icons.calendar_month_rounded;
    if (action.contains('emergency') || action.contains('dial')) return Icons.phone_forwarded_rounded;
    if (action.contains('med')) return Icons.medication_rounded;
    if (action.contains('lab')) return Icons.biotech_rounded;
    if (action.contains('vital')) return Icons.monitor_heart_rounded;
    if (action.contains('360') || action.contains('patient')) return Icons.badge_rounded;
    return Icons.arrow_outward_rounded;
  }
}

// -----------------------------------------------------------------
// RICH CLINICAL TEXT RENDERER (MARKDOWN HEADINGS, BULLETS, BOLD)
// -----------------------------------------------------------------
class FormattedClinicalText extends StatelessWidget {
  final String text;

  const FormattedClinicalText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Headings
      if (trimmed.startsWith('### ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            trimmed.substring(4),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
              letterSpacing: -0.2,
            ),
          ),
        ));
      } else if (trimmed.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 6),
          child: Text(
            trimmed.substring(3),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
        ));
      } else if (trimmed.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(
            trimmed.substring(2),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ));
      }
      // Bullet Items
      else if (trimmed.startsWith('- ') || trimmed.startsWith('• ') || trimmed.startsWith('* ')) {
        final content = trimmed.substring(2).trim();
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 7, right: 8),
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
            ),
            Expanded(
              child: _buildInlineRichText(context, content),
            ),
          ]),
        ));
      }
      // Normal Paragraph
      else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _buildInlineRichText(context, trimmed),
        ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
  }

  Widget _buildInlineRichText(BuildContext context, String content) {
    final scheme = Theme.of(context).colorScheme;
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*.*?\*\*|\*.*?\*|`.*?`|[^*`]+)');
    final matches = regex.allMatches(content);

    for (final match in matches) {
      final token = match.group(0) ?? '';
      if (token.startsWith('**') && token.endsWith('**') && token.length >= 4) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ));
      } else if (token.startsWith('`') && token.endsWith('`') && token.length >= 2) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: scheme.surfaceContainerHighest,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ClinexaTheme.primary,
          ),
        ));
      } else {
        spans.add(TextSpan(text: token));
      }
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 13.2,
          height: 1.48,
          color: scheme.onSurface,
        ),
        children: spans,
      ),
    );
  }
}
