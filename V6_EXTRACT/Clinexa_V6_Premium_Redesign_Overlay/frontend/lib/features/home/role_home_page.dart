import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';

class RoleHomePage extends StatefulWidget {
  const RoleHomePage({super.key});
  @override
  State<RoleHomePage> createState() => _RoleHomePageState();
}

class _RoleHomePageState extends State<RoleHomePage> {
  bool loading = true;
  String? error;
  List<dynamic> primary = [];
  List<dynamic> secondary = [];

  String get role => Api.roles.isEmpty ? 'Staff' : Api.roles.first;
  String get normalized => role.toLowerCase();

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      if (normalized.contains('reception')) {
        final r = await Future.wait([Api.dio.get('/api/v1/appointments/queue/active'), Api.dio.get('/api/v1/appointments')]);
        primary = List<dynamic>.from(r[0].data as List);
        secondary = List<dynamic>.from(r[1].data as List);
      } else if (normalized.contains('nurse')) {
        final r = await Future.wait([Api.dio.get('/api/v1/appointments/queue/active'), Api.dio.get('/api/v1/patients')]);
        primary = List<dynamic>.from(r[0].data as List);
        secondary = List<dynamic>.from(r[1].data as List);
      } else if (normalized.contains('lab')) {
        final r = await Api.dio.get('/api/v1/advanced/lab-orders');
        primary = List<dynamic>.from(r.data as List);
      } else if (normalized.contains('billing')) {
        final r = await Api.dio.get('/api/v1/billing/invoices');
        primary = List<dynamic>.from(r.data as List);
      }
    } catch (e) {
      error = Api.errorMessage(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String get heroTitle {
    if (normalized.contains('reception')) return 'Front desk, without the chaos.';
    if (normalized.contains('nurse')) return 'The clinical floor at a glance.';
    if (normalized.contains('lab')) return 'Lab work, clearly prioritized.';
    if (normalized.contains('billing')) return 'Revenue operations, simplified.';
    return 'Your Clinexa workspace.';
  }

  String get heroSubtitle {
    if (normalized.contains('reception')) return 'Check-ins, waiting patients and appointments in one calm queue.';
    if (normalized.contains('nurse')) return 'See who is waiting and keep patient flow moving safely.';
    if (normalized.contains('lab')) return 'Track ordered, collected, processing and completed tests.';
    if (normalized.contains('billing')) return 'Review invoices and outstanding payment activity.';
    return 'Only the work relevant to your role is shown here.';
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 700 ? 16.0 : 28.0;
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 26, pad, 36),
        children: [
          CxPageHeader(
            eyebrow: role,
            title: 'Good day, ${Api.currentUser?['full_name']?.toString().split(' ').first ?? 'Clinexa'}',
            subtitle: heroSubtitle,
            actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh')],
          ),
          const SizedBox(height: 20),
          _Hero(title: heroTitle, role: role, primaryCount: primary.length),
          if (error != null) ...[const SizedBox(height: 14), CxErrorBanner(message: error!, onRetry: load)],
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 940 ? 3 : c.maxWidth >= 560 ? 2 : 1;
            final cards = _metrics();
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: cols == 1 ? 2.35 : 1.55),
              itemBuilder: (_, i) => cards[i],
            );
          }),
          const SizedBox(height: 16),
          CxSurface(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CxSectionHeader(title: _queueTitle(), subtitle: _queueSubtitle(), action: TextButton.icon(onPressed: load, icon: const Icon(Icons.refresh_rounded, size: 16), label: const Text('Refresh'))),
              const SizedBox(height: 12),
              if (loading) ...List.generate(4, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: CxSkeleton(height: 58))),
              if (!loading && primary.isEmpty) CxEmptyState(icon: Icons.inbox_outlined, title: 'All clear', message: _emptyMessage()),
              if (!loading) ...primary.take(8).map((x) => _WorkRow(item: Map<String, dynamic>.from(x as Map), kind: normalized)),
            ]),
          ),
          const SizedBox(height: 16),
          _FocusTips(role: normalized),
        ],
      ),
    );
  }

  List<Widget> _metrics() {
    if (normalized.contains('reception')) {
      final waiting = primary.where((x) => ['checked_in', 'waiting'].contains(x['status'])).length;
      return [
        CxMetricCard(label: 'Active queue', value: '${primary.length}', caption: 'Patients currently in front-desk flow', icon: Icons.groups_2_outlined),
        CxMetricCard(label: 'Waiting', value: '$waiting', caption: 'Checked in and waiting', icon: Icons.hourglass_top_rounded, tone: ClinexaTheme.warning),
        CxMetricCard(label: 'Appointments', value: '${secondary.length}', caption: 'Loaded appointment records', icon: Icons.calendar_month_outlined, tone: const Color(0xFF4567C6)),
      ];
    }
    if (normalized.contains('nurse')) {
      return [
        CxMetricCard(label: 'Clinical queue', value: '${primary.length}', caption: 'Patients requiring floor attention', icon: Icons.monitor_heart_outlined),
        CxMetricCard(label: 'Patient directory', value: '${secondary.length}', caption: 'Accessible patient profiles', icon: Icons.people_alt_outlined, tone: const Color(0xFF4567C6)),
        const CxMetricCard(label: 'Workspace', value: 'Live', caption: 'Role-protected nursing view', icon: Icons.verified_user_outlined, tone: ClinexaTheme.success),
      ];
    }
    if (normalized.contains('lab')) {
      final processing = primary.where((x) => x['status'] == 'processing').length;
      final ordered = primary.where((x) => x['status'] == 'ordered').length;
      return [
        CxMetricCard(label: 'Lab orders', value: '${primary.length}', caption: 'Total active/recent orders', icon: Icons.science_outlined),
        CxMetricCard(label: 'Processing', value: '$processing', caption: 'Currently in processing', icon: Icons.biotech_outlined, tone: const Color(0xFF4567C6)),
        CxMetricCard(label: 'Awaiting collection', value: '$ordered', caption: 'Ordered tests not yet collected', icon: Icons.water_drop_outlined, tone: ClinexaTheme.warning),
      ];
    }
    if (normalized.contains('billing')) {
      final unpaid = primary.where((x) => x['status'] != 'paid').length;
      return [
        CxMetricCard(label: 'Invoices', value: '${primary.length}', caption: 'Recent billing records', icon: Icons.receipt_long_outlined),
        CxMetricCard(label: 'Outstanding', value: '$unpaid', caption: 'Invoices not marked paid', icon: Icons.pending_actions_outlined, tone: ClinexaTheme.warning),
        const CxMetricCard(label: 'Billing workspace', value: 'Secure', caption: 'Access is role protected', icon: Icons.lock_outline_rounded, tone: ClinexaTheme.success),
      ];
    }
    return const [CxMetricCard(label: 'Workspace', value: 'Ready', caption: 'Role-aware Clinexa session', icon: Icons.dashboard_customize_outlined)];
  }

  String _queueTitle() {
    if (normalized.contains('lab')) return 'Lab pipeline';
    if (normalized.contains('billing')) return 'Invoice activity';
    return 'Priority work queue';
  }

  String _queueSubtitle() {
    if (normalized.contains('lab')) return 'Most recent orders, with status visible at a glance.';
    if (normalized.contains('billing')) return 'Recent invoices that need attention.';
    return 'The next items that deserve attention.';
  }

  String _emptyMessage() {
    if (normalized.contains('lab')) return 'No lab orders are waiting in the current pipeline.';
    if (normalized.contains('billing')) return 'No billing records are waiting in this view.';
    return 'There are no active queue items right now.';
  }
}

class _Hero extends StatelessWidget {
  final String title;
  final String role;
  final int primaryCount;
  const _Hero({required this.title, required this.role, required this.primaryCount});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B1424), Color(0xFF113649), Color(0xFF006D68)]),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Color(0x1C0B1424), blurRadius: 32, offset: Offset(0, 16))],
        ),
        child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, runSpacing: 18, children: [
          SizedBox(width: 560, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CxStatusChip(label: role, color: const Color(0xFF7FE4DB), icon: Icons.shield_outlined),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 30)),
            const SizedBox(height: 8),
            const Text('Clinexa surfaces action before analytics, so the screen stays useful instead of decorative.', style: TextStyle(color: Color(0xFFD6E6E8), height: 1.5, fontSize: 12.5)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), decoration: BoxDecoration(color: const Color(0x18FFFFFF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x22FFFFFF))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ACTIVE ITEMS', style: TextStyle(color: Color(0xFFBFD6D8), fontWeight: FontWeight.w800, fontSize: 9.5, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text('$primaryCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28)),
          ])),
        ]),
      );
}

class _WorkRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final String kind;
  const _WorkRow({required this.item, required this.kind});

  @override
  Widget build(BuildContext context) {
    String title;
    String subtitle;
    String status = item['status']?.toString() ?? 'active';
    IconData icon;
    if (kind.contains('lab')) {
      title = item['test_name']?.toString() ?? 'Lab order';
      subtitle = 'Priority ${item['priority'] ?? 'routine'} • ${item['specimen'] ?? 'specimen not specified'}';
      icon = Icons.science_outlined;
    } else if (kind.contains('billing')) {
      title = item['description']?.toString() ?? 'Invoice';
      subtitle = '₹${item['total_amount'] ?? '0'} • ${item['created_at'] ?? ''}';
      icon = Icons.receipt_long_outlined;
    } else {
      title = item['reason']?.toString().isNotEmpty == true ? item['reason'].toString() : 'Patient visit';
      subtitle = '${item['start_at'] ?? ''} • ${item['appointment_type'] ?? 'visit'}';
      icon = Icons.event_available_outlined;
    }
    final color = status == 'completed' || status == 'paid' ? ClinexaTheme.success : status == 'cancelled' ? ClinexaTheme.emergency : ClinexaTheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.line)),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withAlpha(16), borderRadius: BorderRadius.circular(12)), child: Icon(icon, size: 19, color: color)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)), const SizedBox(height: 2), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5))])),
        CxStatusChip(label: status.replaceAll('_', ' '), color: color),
      ]),
    );
  }
}

class _FocusTips extends StatelessWidget {
  final String role;
  const _FocusTips({required this.role});
  @override
  Widget build(BuildContext context) => CxSurface(
        color: const Color(0xFFF7FAFC),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(color: ClinexaTheme.mint, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.auto_awesome_outlined, color: ClinexaTheme.primary, size: 20)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Built for focus', style: TextStyle(fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text('This workspace intentionally hides unrelated modules. Backend authorization still decides what each action can access.', style: TextStyle(color: ClinexaTheme.muted, fontSize: 11.5, height: 1.45)),
          ])),
        ]),
      );
}
