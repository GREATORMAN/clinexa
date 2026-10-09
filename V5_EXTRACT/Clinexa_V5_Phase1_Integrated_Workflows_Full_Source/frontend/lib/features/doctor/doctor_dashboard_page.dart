import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';
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
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final response = await Api.dio.get('/api/v1/doctor/workspace');
      if (mounted) setState(() => data = Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
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
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorConsultationPage(
          patientId: patientId,
          patientName: appointment['patient_name']?.toString() ?? 'Patient',
          patientCode: appointment['patient_code']?.toString() ?? '',
          doctorId: doctorId,
          appointmentId: appointment['id']?.toString(),
          appointmentStatus: appointment['status']?.toString(),
        ),
      ),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final doctor = Map<String, dynamic>.from(data?['doctor'] as Map? ?? const {});
    final counts = Map<String, dynamic>.from(data?['counts'] as Map? ?? const {});
    return SectionPage(
      title: 'Doctor workspace',
      subtitle: doctor.isEmpty
          ? 'Your live schedule and clinical work queue'
          : '${doctor['full_name'] ?? 'Doctor'} • ${doctor['specialty'] ?? 'Specialty not recorded'}',
      actions: [IconButton(onPressed: loading ? null : load, tooltip: 'Refresh', icon: const Icon(Icons.refresh_rounded))],
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            if (loading) const LinearProgressIndicator(),
            if (error != null) ...[const SizedBox(height: 12), ErrorCard(error!)],
            if (!loading && error == null) ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Metric(label: 'Today', value: '${counts['today'] ?? 0}', icon: Icons.calendar_today_outlined),
                  _Metric(label: 'Waiting', value: '${counts['waiting'] ?? 0}', icon: Icons.hourglass_top_rounded),
                  _Metric(label: 'Upcoming', value: '${counts['upcoming'] ?? 0}', icon: Icons.event_available_outlined),
                  _Metric(label: 'Labs to review', value: '${counts['pending_labs'] ?? 0}', icon: Icons.science_outlined),
                ],
              ),
              const SizedBox(height: 16),
              _WorkSection(
                title: 'Waiting now',
                subtitle: 'Checked-in and in-consultation patients assigned to you',
                icon: Icons.groups_2_outlined,
                empty: 'No patients are waiting for you.',
                children: list('waiting').map((x) {
                  final a = Map<String, dynamic>.from(x as Map);
                  return _AppointmentTile(appointment: a, primaryAction: 'Open consultation', onTap: () => openConsultation(a));
                }).toList(),
              ),
              const SizedBox(height: 14),
              _WorkSection(
                title: "Today's schedule",
                subtitle: 'Only appointments assigned to your doctor profile',
                icon: Icons.schedule_outlined,
                empty: 'No appointments scheduled today.',
                children: list('today').map((x) {
                  final a = Map<String, dynamic>.from(x as Map);
                  return _AppointmentTile(appointment: a, primaryAction: 'Patient workspace', onTap: () => openConsultation(a));
                }).toList(),
              ),
              const SizedBox(height: 14),
              _WorkSection(
                title: 'Pending lab work',
                subtitle: 'Orders you placed that are still in the laboratory lifecycle',
                icon: Icons.biotech_outlined,
                empty: 'No pending lab orders.',
                children: list('pending_labs').map((x) {
                  final lab = Map<String, dynamic>.from(x as Map);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    leading: const CircleAvatar(child: Icon(Icons.science_outlined, size: 19)),
                    title: Text(lab['test_name']?.toString() ?? 'Lab order', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${(lab['status'] ?? 'ordered').toString().replaceAll('_', ' ')} • ${lab['priority'] ?? 'routine'} • ${lab['ordered_at'] ?? ''}'),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              _WorkSection(
                title: 'Recent patients',
                subtitle: 'Derived from your recorded encounters, not demo counters',
                icon: Icons.history_rounded,
                empty: 'No consultation history yet.',
                children: list('recent_patients').map((x) {
                  final p = Map<String, dynamic>.from(x as Map);
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                    leading: CircleAvatar(child: Text((p['full_name']?.toString() ?? 'P').substring(0, 1).toUpperCase())),
                    title: Text(p['full_name']?.toString() ?? 'Patient', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${p['patient_code'] ?? ''} • last seen ${p['last_seen'] ?? ''}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
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
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _Metric({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    width: 154,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFFE5EAF0)), borderRadius: BorderRadius.circular(18)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
      const SizedBox(height: 13),
      Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(color: Color(0xFF667085), fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _WorkSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String empty;
  final List<Widget> children;
  const _WorkSection({required this.title, required this.subtitle, required this.icon, required this.empty, required this.children});
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon, size: 20), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)), Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF7A8798))) ]))]),
        const SizedBox(height: 10),
        if (children.isEmpty) Padding(padding: const EdgeInsets.all(12), child: Text(empty, style: const TextStyle(color: Color(0xFF667085)))) else ...children,
      ]),
    ),
  );
}

class _AppointmentTile extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final String primaryAction;
  final VoidCallback onTap;
  const _AppointmentTile({required this.appointment, required this.primaryAction, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(14)),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      leading: CircleAvatar(child: Text((appointment['patient_name']?.toString() ?? 'P').substring(0, 1).toUpperCase())),
      title: Text(appointment['patient_name']?.toString() ?? 'Patient', style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${appointment['patient_code'] ?? ''} • ${appointment['start_at'] ?? ''}\n${appointment['reason'] ?? 'No reason recorded'} • ${(appointment['status'] ?? '').toString().replaceAll('_', ' ')}'),
      isThreeLine: true,
      trailing: FilledButton.tonal(onPressed: onTap, child: Text(primaryAction)),
      onTap: onTap,
    ),
  );
}
