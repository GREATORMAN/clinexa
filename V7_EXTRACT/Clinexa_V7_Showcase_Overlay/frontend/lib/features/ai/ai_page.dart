import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class AiPage extends StatefulWidget { const AiPage({super.key}); @override State<AiPage> createState() => _AiPageState(); }

class _AiPageState extends State<AiPage> {
  final ctrl = TextEditingController();
  final List<Map<String,String>> chat = [];
  Map<String,dynamic>? status;
  List<dynamic> patients = []; List<dynamic> doctors = []; bool loading = false;
  @override void initState() { super.initState(); bootstrap(); }

  Future<void> bootstrap() async {
    try {
      final r = await Future.wait([Api.dio.get('/api/v1/ai/status'), Api.dio.get('/api/v1/patients'), Api.dio.get('/api/v1/doctors')]);
      if (mounted) setState(() { status = Map<String,dynamic>.from(r[0].data); patients = List.from(r[1].data); doctors = List.from(r[2].data); });
    } catch (_) { if (mounted) setState(() => status = {'online': false}); }
  }

  Future<void> send() async {
    final message = ctrl.text.trim(); if (message.isEmpty || loading) return;
    setState(() { chat.add({'role': 'user', 'text': message}); ctrl.clear(); loading = true; });
    try { final r = await Api.dio.post('/api/v1/ai/chat', data: {'message': message}); if (mounted) setState(() => chat.add({'role': 'assistant', 'text': r.data['answer']?.toString() ?? ''})); } catch (e) { if (mounted) setState(() => chat.add({'role': 'assistant', 'text': Api.errorMessage(e)})); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<DateTime?> pickDateTime(DateTime initial) async {
    final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> aiBooking() async {
    if (patients.isEmpty || doctors.isEmpty) { showMessage(context, 'Add a patient and doctor first.'); return; }
    String patientId = patients.first['id'].toString(); String doctorId = doctors.first['id'].toString(); DateTime start = DateTime.now().add(const Duration(days: 1)); final reason = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: const Text('AI-assisted appointment'),
      content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: patientId, decoration: const InputDecoration(labelText: 'Patient'), items: patients.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['full_name'].toString()))).toList(), onChanged: (v) => setLocal(() => patientId = v ?? patientId)),
        const SizedBox(height: 10), DropdownButtonFormField<String>(initialValue: doctorId, decoration: const InputDecoration(labelText: 'Doctor'), items: doctors.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text('${d['full_name']} — ${d['specialty']}'))).toList(), onChanged: (v) => setLocal(() => doctorId = v ?? doctorId)),
        const SizedBox(height: 10), ListTile(contentPadding: EdgeInsets.zero, title: const Text('Requested time'), subtitle: Text(start.toString()), trailing: const Icon(Icons.edit_calendar), onTap: () async { final x = await pickDateTime(start); if (x != null) setLocal(() => start = x); }),
        TextField(controller: reason, decoration: const InputDecoration(labelText: 'Reason')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create proposal'))],
    )));
    if (ok != true) return;
    final payload = {'patient_id': patientId, 'doctor_id': doctorId, 'start_at': start.toIso8601String(), 'appointment_type': 'in_person', 'reason': reason.text.trim().isEmpty ? null : reason.text.trim(), 'confirmed': false};
    try {
      final r = await Api.dio.post('/api/v1/ai/propose-booking', data: payload); final proposal = Map<String,dynamic>.from(r.data['proposal']);
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm booking'),
          content: Text(
            "Patient: ${proposal['patient']}\n"
            "Doctor: ${proposal['doctor']} (${proposal['specialty']})\n"
            "Time: ${proposal['start_at']}\n"
            "Type: ${proposal['appointment_type']}\n\n"
            "Clinexa will only book after you confirm.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm booking'),
            ),
          ],
        ),
      );
      if (confirm == true) { payload['confirmed'] = true; await Api.dio.post('/api/v1/ai/propose-booking', data: payload); if (mounted) showMessage(context, 'Appointment booked after confirmation.'); }
    } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  @override
  Widget build(BuildContext context) => SectionPage(
    title: 'Local AI', subtitle: 'Ollama assistant with confirmation-controlled actions',
    actions: [FilledButton.tonalIcon(onPressed: aiBooking, icon: const Icon(Icons.event_available_outlined), label: const Text('AI booking'))],
    child: Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
        Icon((status?['online'] ?? false) ? Icons.check_circle_outline : Icons.cloud_off_outlined), const SizedBox(width: 10),
        Expanded(child: Text((status?['online'] ?? false) ? 'Ollama online — ${status?['model']}' : 'Ollama offline — hospital features continue to work')),
      ])))),
      Expanded(child: chat.isEmpty ? const Center(child: Padding(padding: EdgeInsets.all(30), child: Text('Ask about healthcare terminology or app navigation. Clinexa AI does not independently diagnose, prescribe, or change medication doses.', textAlign: TextAlign.center))) : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: chat.length, itemBuilder: (_, i) { final m = chat[i]; final user = m['role'] == 'user'; return Align(alignment: user ? Alignment.centerRight : Alignment.centerLeft, child: Container(
          constraints: const BoxConstraints(maxWidth: 650), margin: const EdgeInsets.symmetric(vertical: 5), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: user ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)), child: Text(m['text'] ?? ''),
        )); },
      )),
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: TextField(controller: ctrl, onSubmitted: (_) => send(), decoration: const InputDecoration(labelText: 'Ask Clinexa', hintText: 'Explain what a CBC test measures'))), const SizedBox(width: 8), IconButton.filled(onPressed: loading ? null : send, icon: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send))])),
    ]),
  );
}

