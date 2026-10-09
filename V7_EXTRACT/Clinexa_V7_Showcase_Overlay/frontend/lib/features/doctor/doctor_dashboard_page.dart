import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';
import 'doctor_consultation_page.dart';

class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});
  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final response = await Api.dio.get('/api/v1/doctor/workspace');
      data = Map<String, dynamic>.from(response.data as Map);
    } catch (e) {
      error = Api.errorMessage(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<dynamic> list(String key) => List<dynamic>.from(data?[key] as List? ?? const []);

  Future<void> openConsultation(Map<String, dynamic> appointment) async {
    final doctor = Map<String, dynamic>.from(data?['doctor'] as Map? ?? const {});
    final patientId = appointment['patient_id']?.toString();
    final doctorId = doctor['id']?.toString();
    if (patientId == null || doctorId == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorConsultationPage(
      patientId: patientId,
      patientName: appointment['patient_name']?.toString() ?? 'Patient',
      patientCode: appointment['patient_code']?.toString() ?? '',
      doctorId: doctorId,
      appointmentId: appointment['id']?.toString(),
      appointmentStatus: appointment['status']?.toString(),
    )));
    await load();
  }

  Future<void> openRecentPatient(Map<String, dynamic> p) async {
    final doctor = Map<String, dynamic>.from(data?['doctor'] as Map? ?? const {});
    final doctorId = doctor['id']?.toString();
    final patientId = p['id']?.toString();
    if (doctorId == null || patientId == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorConsultationPage(
      patientId: patientId,
      patientName: p['full_name']?.toString() ?? 'Patient',
      patientCode: p['patient_code']?.toString() ?? '',
      doctorId: doctorId,
    )));
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final doctor = Map<String, dynamic>.from(data?['doctor'] as Map? ?? const {});
    final counts = Map<String, dynamic>.from(data?['counts'] as Map? ?? const {});
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 700 ? 16.0 : 28.0;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 26, pad, 36),
        children: [
          CxPageHeader(
            eyebrow: 'Doctor workspace',
            title: doctor.isEmpty ? 'Clinical command center' : 'Good day, ${doctor['full_name']}',
            subtitle: doctor.isEmpty ? 'Your schedule, waiting patients and clinical review queue.' : '${doctor['specialty'] ?? 'Clinical practice'} • a focused workspace for today’s care.',
            icon: Icons.medical_services_rounded,
            actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh')],
          ),
          const SizedBox(height: 18),
          CxSpotlightHero(
            eyebrow: 'Live clinical workspace',
            title: 'Care starts with context.',
            subtitle: 'Open a waiting patient and move through history, notes, prescription and lab ordering without leaving the consultation workspace.',
            icon: Icons.monitor_heart_rounded,
            stats: [
              CxHeroStat(value: '${counts['waiting'] ?? 0}', label: 'waiting', icon: Icons.groups_2_outlined),
              CxHeroStat(value: '${counts['today'] ?? 0}', label: 'today', icon: Icons.calendar_today_outlined),
            ],
          ),
          if (error != null) ...[const SizedBox(height: 14), CxErrorBanner(message: error!, onRetry: load)],
          const SizedBox(height: 14),
          CxAdaptiveGrid(minItemWidth: 215, children: [
            CxMetricCard(label: 'Today', value: '${counts['today'] ?? 0}', caption: 'Appointments assigned to you', icon: Icons.calendar_today_outlined),
            CxMetricCard(label: 'Waiting', value: '${counts['waiting'] ?? 0}', caption: 'Patients ready for consultation', icon: Icons.groups_2_outlined, tone: ClinexaTheme.warning),
            CxMetricCard(label: 'Upcoming', value: '${counts['upcoming'] ?? 0}', caption: 'Future scheduled visits', icon: Icons.event_available_outlined, tone: ClinexaTheme.accent),
            CxMetricCard(label: 'Lab review', value: '${counts['pending_labs'] ?? 0}', caption: 'Orders still in lab workflow', icon: Icons.science_outlined, tone: ClinexaTheme.success),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (_, c) {
            final split = c.maxWidth >= 900;
            final waiting = _ClinicalPanel(
              title: 'Waiting now',
              subtitle: 'Patients already in today’s clinical flow.',
              icon: Icons.hourglass_top_rounded,
              accent: ClinexaTheme.warning,
              empty: 'No patients are waiting right now.',
              children: list('waiting').map((x) => _PatientVisitTile(appointment: Map<String, dynamic>.from(x as Map), onTap: () => openConsultation(Map<String, dynamic>.from(x as Map)))).toList(),
            );
            final schedule = _ClinicalPanel(
              title: 'Today’s schedule',
              subtitle: 'Your assigned appointments, in chronological order.',
              icon: Icons.schedule_rounded,
              accent: ClinexaTheme.primary,
              empty: 'No appointments scheduled today.',
              children: list('today').map((x) => _PatientVisitTile(appointment: Map<String, dynamic>.from(x as Map), onTap: () => openConsultation(Map<String, dynamic>.from(x as Map)))).toList(),
            );
            if (!split) return Column(children: [waiting, const SizedBox(height: 12), schedule]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: waiting), const SizedBox(width: 12), Expanded(child: schedule)]);
          }),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (_, c) {
            final split = c.maxWidth >= 900;
            final labs = _ClinicalPanel(
              title: 'Lab pipeline',
              subtitle: 'Tests you ordered that still need completion or review.',
              icon: Icons.biotech_outlined,
              accent: const Color(0xFF4567C6),
              empty: 'No pending lab orders.',
              children: list('pending_labs').map((x) {
                final lab = Map<String, dynamic>.from(x as Map);
                return _SimpleRow(icon: Icons.science_outlined, title: lab['test_name']?.toString() ?? 'Lab order', subtitle: '${(lab['status'] ?? 'ordered').toString().replaceAll('_', ' ')} • ${lab['priority'] ?? 'routine'}', status: lab['status']?.toString() ?? 'ordered');
              }).toList(),
            );
            final recent = _ClinicalPanel(
              title: 'Recent patients',
              subtitle: 'People you have seen recently.',
              icon: Icons.history_rounded,
              accent: ClinexaTheme.success,
              empty: 'No recent consultation history.',
              children: list('recent_patients').map((x) {
                final p = Map<String, dynamic>.from(x as Map);
                return _RecentPatientTile(patient: p, onTap: () => openRecentPatient(p));
              }).toList(),
            );
            if (!split) return Column(children: [labs, const SizedBox(height: 12), recent]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: labs), const SizedBox(width: 12), Expanded(child: recent)]);
          }),
        ],
      ),
    );
  }
}

class _ClinicalPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String empty;
  final List<Widget> children;
  const _ClinicalPanel({required this.title, required this.subtitle, required this.icon, required this.accent, required this.empty, required this.children});
  @override
  Widget build(BuildContext context) => CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CxSectionHeader(title: title, subtitle: subtitle, action: Container(width: 36, height: 36, decoration: BoxDecoration(color: accent.withAlpha(16), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: accent, size: 18))),
        const SizedBox(height: 12),
        if (children.isEmpty) CxEmptyState(icon: icon, title: 'Nothing waiting', message: empty) else ...children.take(8),
      ]));
}

class _PatientVisitTile extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final VoidCallback onTap;
  const _PatientVisitTile({required this.appointment, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.line)),
        child: Row(children: [
          CircleAvatar(radius: 19, backgroundColor: ClinexaTheme.mint, foregroundColor: ClinexaTheme.primary, child: Text((appointment['patient_name']?.toString() ?? 'P').substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(appointment['patient_name']?.toString() ?? 'Patient', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            Text('${appointment['patient_code'] ?? ''} • ${appointment['start_at'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5)),
          ])),
          FilledButton.tonalIcon(onPressed: onTap, icon: const Icon(Icons.arrow_forward_rounded, size: 16), label: const Text('Open')),
        ]),
      );
}

class _SimpleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  const _SimpleRow({required this.icon, required this.title, required this.subtitle, required this.status});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.line)), child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: const Color(0x144567C6), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFF4567C6), size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5))])),
        CxStatusChip(label: status.replaceAll('_', ' '), color: const Color(0xFF4567C6)),
      ]));
}

class _RecentPatientTile extends StatelessWidget {
  final Map<String, dynamic> patient;
  final VoidCallback onTap;
  const _RecentPatientTile({required this.patient, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.line)), child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFE8F5EF), foregroundColor: ClinexaTheme.success, child: Text((patient['full_name']?.toString() ?? 'P').substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))),
        title: Text(patient['full_name']?.toString() ?? 'Patient', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        subtitle: Text('${patient['patient_code'] ?? ''} • last seen ${patient['last_seen'] ?? ''}', style: const TextStyle(fontSize: 10.5)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
        onTap: onTap,
      ));
}
