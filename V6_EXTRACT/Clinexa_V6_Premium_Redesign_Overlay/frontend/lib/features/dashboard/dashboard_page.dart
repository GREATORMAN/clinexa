import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? data;
  List<dynamic> queue = [];
  List<dynamic> notifications = [];
  String? error;
  bool loading = true;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final responses = await Future.wait([
        Api.dio.get('/api/v1/admin/dashboard'),
        Api.dio.get('/api/v1/appointments/queue/active'),
        Api.dio.get('/api/v1/notifications'),
      ]);
      data = Map<String, dynamic>.from(responses[0].data as Map);
      queue = List<dynamic>.from(responses[1].data as List);
      notifications = List<dynamic>.from(responses[2].data as List);
    } catch (e) {
      error = Api.errorMessage(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data ?? <String, dynamic>{};
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 700 ? 16.0 : 28.0;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 26, pad, 36),
        children: [
          CxPageHeader(
            eyebrow: 'Hospital command center',
            title: 'The hospital, in one calm view.',
            subtitle: 'Live patient flow, operations and attention signals — designed for decisions, not dashboard decoration.',
            actions: [IconButton(onPressed: loading ? null : load, icon: const Icon(Icons.refresh_rounded))],
          ),
          const SizedBox(height: 18),
          _AdminHero(queueCount: queue.length, notificationCount: notifications.where((x) => x['is_read'] != true).length, patientCount: d['patients']?.toString() ?? '—'),
          if (error != null) ...[const SizedBox(height: 14), CxErrorBanner(message: error!, onRetry: load)],
          const SizedBox(height: 14),
          LayoutBuilder(builder: (_, c) {
            final cols = c.maxWidth >= 950 ? 4 : c.maxWidth >= 560 ? 2 : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: cols == 1 ? 2.55 : 1.55,
              children: [
                CxMetricCard(label: 'Patients', value: d['patients']?.toString() ?? '—', caption: 'Registered patient profiles', icon: Icons.people_alt_outlined),
                CxMetricCard(label: 'Doctors', value: d['doctors']?.toString() ?? '—', caption: 'Active clinical staff', icon: Icons.medical_services_outlined, tone: const Color(0xFF4567C6)),
                CxMetricCard(label: 'Appointments', value: d['appointments']?.toString() ?? '—', caption: 'Scheduled visit records', icon: Icons.calendar_month_outlined, tone: ClinexaTheme.success),
                CxMetricCard(label: 'Collected', value: _money(d['paid_invoice_total']), caption: 'Paid invoice total', icon: Icons.payments_outlined, tone: ClinexaTheme.warning),
              ],
            );
          }),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (_, c) {
            final split = c.maxWidth >= 900;
            final q = CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CxSectionHeader(title: 'Live patient flow', subtitle: 'Checked-in, waiting and in-consultation visits.'),
              const SizedBox(height: 12),
              if (loading) ...List.generate(4, (_) => const Padding(padding: EdgeInsets.only(bottom: 8), child: CxSkeleton(height: 58))),
              if (!loading && queue.isEmpty) const CxEmptyState(icon: Icons.groups_2_outlined, title: 'Queue is clear', message: 'No active waiting-room items right now.'),
              if (!loading) ...queue.take(8).map((x) => _QueueRow(item: Map<String, dynamic>.from(x as Map))),
            ]));
            final n = CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CxSectionHeader(title: 'Attention center', subtitle: 'Unread system and workflow notifications.'),
              const SizedBox(height: 12),
              if (loading) ...List.generate(4, (_) => const Padding(padding: EdgeInsets.only(bottom: 8), child: CxSkeleton(height: 58))),
              if (!loading && notifications.isEmpty) const CxEmptyState(icon: Icons.notifications_none_rounded, title: 'No alerts', message: 'There are no notifications waiting for review.'),
              if (!loading) ...notifications.take(8).map((x) => _NotificationRow(item: Map<String, dynamic>.from(x as Map))),
            ]));
            if (!split) return Column(children: [q, const SizedBox(height: 12), n]);
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 11, child: q), const SizedBox(width: 12), Expanded(flex: 9, child: n)]);
          }),
          const SizedBox(height: 14),
          CxSurface(color: const Color(0xFFF7FAFC), child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.insights_outlined, color: ClinexaTheme.primary), SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('A dashboard that earns its space', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 3), Text('Clinexa V6 prioritizes queues and action states over decorative charts. Deeper analytics remain in operational views where they are useful.', style: TextStyle(color: ClinexaTheme.muted, fontSize: 11.5, height: 1.45))]))
          ])),
        ],
      ),
    );
  }

  String _money(dynamic raw) {
    final value = num.tryParse(raw?.toString() ?? '');
    return value == null ? '—' : '₹${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
  }
}

class _AdminHero extends StatelessWidget {
  final int queueCount;
  final int notificationCount;
  final String patientCount;
  const _AdminHero({required this.queueCount, required this.notificationCount, required this.patientCount});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B1424), Color(0xFF17384D), Color(0xFF006D68)]), borderRadius: BorderRadius.circular(29), boxShadow: const [BoxShadow(color: Color(0x1E0B1424), blurRadius: 34, offset: Offset(0, 16))]),
        child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 18, children: [
          SizedBox(width: 580, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CxStatusChip(label: 'LIVE OPERATIONS', color: Color(0xFF8CE5DD), icon: Icons.bolt_rounded),
            const SizedBox(height: 14),
            Text('See what needs attention now.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 31)),
            const SizedBox(height: 8),
            const Text('Patient flow, unread alerts and core operational totals are surfaced first. Everything else stays one click away.', style: TextStyle(color: Color(0xFFD5E5E7), fontSize: 12.5, height: 1.5)),
          ])),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _HeroValue(label: 'queue', value: '$queueCount', icon: Icons.groups_2_outlined),
            _HeroValue(label: 'unread', value: '$notificationCount', icon: Icons.notifications_none_rounded),
            _HeroValue(label: 'patients', value: patientCount, icon: Icons.people_alt_outlined),
          ]),
        ]),
      );
}

class _HeroValue extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _HeroValue({required this.label, required this.value, required this.icon});
  @override
  Widget build(BuildContext context) => Container(width: 102, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0x17FFFFFF), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0x22FFFFFF))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(height: 10), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(color: Color(0xFFC8DCDD), fontSize: 9.5))]));
}

class _QueueRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _QueueRow({required this.item});
  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'waiting';
    final tone = status == 'in_consultation' ? ClinexaTheme.success : ClinexaTheme.warning;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.line)), child: Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: tone.withAlpha(16), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.person_outline_rounded, color: tone, size: 19)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['reason']?.toString().isNotEmpty == true ? item['reason'].toString() : 'Patient visit', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text('${item['queue_token'] ?? 'No token'} • ${item['start_at'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5))])),
      CxStatusChip(label: status.replaceAll('_', ' '), color: tone),
    ]));
  }
}

class _NotificationRow extends StatelessWidget {
  final Map<String, dynamic> item;
  const _NotificationRow({required this.item});
  @override
  Widget build(BuildContext context) {
    final unread = item['is_read'] != true;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: unread ? const Color(0xFFF7FCFB) : ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: unread ? const Color(0xFFCFEAE6) : ClinexaTheme.line)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: unread ? ClinexaTheme.mint : const Color(0xFFEEF2F6), borderRadius: BorderRadius.circular(11)), child: Icon(Icons.notifications_none_rounded, color: unread ? ClinexaTheme.primary : ClinexaTheme.muted, size: 18)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['title']?.toString() ?? 'Notification', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)), const SizedBox(height: 2), Text(item['body']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5, height: 1.35))])),
      if (unread) Container(width: 7, height: 7, decoration: const BoxDecoration(color: ClinexaTheme.primaryBright, shape: BoxShape.circle)),
    ]));
  }
}
