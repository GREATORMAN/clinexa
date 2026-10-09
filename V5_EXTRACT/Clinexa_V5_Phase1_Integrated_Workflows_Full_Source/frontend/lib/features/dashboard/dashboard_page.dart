import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/section_page.dart';

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
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final responses = await Future.wait([
        Api.dio.get('/api/v1/admin/dashboard'),
        Api.dio.get('/api/v1/appointments/queue/active'),
        Api.dio.get('/api/v1/notifications'),
      ]);

      if (!mounted) return;

      setState(() {
        data = Map<String, dynamic>.from(responses[0].data as Map);
        queue = List<dynamic>.from(responses[1].data as List);
        notifications = List<dynamic>.from(responses[2].data as List);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error =
            'Some dashboard data could not be loaded. Check backend availability and account permissions.';
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data ?? <String, dynamic>{};
    final mobile = MediaQuery.sizeOf(context).width < 720;

    final metrics = <_MetricData>[
      _MetricData(
        label: 'Patients',
        value: d['patients']?.toString() ?? '—',
        icon: Icons.people_alt_outlined,
        caption: 'Registered profiles',
      ),
      _MetricData(
        label: 'Doctors',
        value: d['doctors']?.toString() ?? '—',
        icon: Icons.medical_services_outlined,
        caption: 'Clinical staff',
      ),
      _MetricData(
        label: 'Appointments',
        value: d['appointments']?.toString() ?? '—',
        icon: Icons.calendar_month_outlined,
        caption: 'All scheduled visits',
      ),
      _MetricData(
        label: 'Paid invoices',
        value: _formatMoney(d['paid_invoice_total']),
        icon: Icons.payments_outlined,
        caption: 'Collected revenue',
      ),
    ];

    return SectionPage(
      title: 'Good morning',
      subtitle: 'Your hospital workspace at a glance',
      actions: [
        IconButton(
          tooltip: 'Refresh dashboard',
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: EdgeInsets.all(mobile ? 16 : 24),
          children: [
            if (error != null) ...[
              ErrorCard(error!),
              const SizedBox(height: 14),
            ],
            _HeroCard(
              patientCount: d['patients']?.toString() ?? '—',
              queueCount: queue.length,
              notificationCount: notifications.length,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final count = constraints.maxWidth >= 1180
                    ? 4
                    : constraints.maxWidth >= 620
                        ? 2
                        : 1;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: metrics.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: count,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: count == 1 ? 2.75 : 1.85,
                  ),
                  itemBuilder: (_, i) => _MetricCard(metric: metrics[i]),
                );
              },
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final split = constraints.maxWidth >= 920;

                if (!split) {
                  return Column(
                    children: [
                      _QueueCard(queue: queue, loading: loading),
                      const SizedBox(height: 14),
                      _NotificationsCard(
                        notifications: notifications,
                        loading: loading,
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 11,
                      child: _QueueCard(queue: queue, loading: loading),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 9,
                      child: _NotificationsCard(
                        notifications: notifications,
                        loading: loading,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            const _QuickActions(),
          ],
        ),
      ),
    );
  }

  String _formatMoney(dynamic raw) {
    final value = num.tryParse(raw?.toString() ?? '');
    if (value == null) return '—';
    return '₹${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
  }
}

class _HeroCard extends StatelessWidget {
  final String patientCount;
  final int queueCount;
  final int notificationCount;

  const _HeroCard({
    required this.patientCount,
    required this.queueCount,
    required this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 650;

    return Container(
      padding: EdgeInsets.all(compact ? 20 : 26),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ClinexaTheme.navy,
            Color(0xFF164D5B),
            ClinexaTheme.primary,
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18132238),
            blurRadius: 30,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 20,
        children: [
          SizedBox(
            width: compact ? double.infinity : 560,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CLINEXA COMMAND CENTER',
                  style: TextStyle(
                    color: Color(0xFFBFD8DA),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Everything important,\nwithout the clutter.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.8,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Live clinical activity, queue status, records and hospital operations from one workspace.',
                  style: TextStyle(
                    color: Color(0xFFD9E7E8),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _HeroStat(
                icon: Icons.people_alt_outlined,
                value: patientCount,
                label: 'patients',
              ),
              _HeroStat(
                icon: Icons.hourglass_top_rounded,
                value: '$queueCount',
                label: 'in queue',
              ),
              _HeroStat(
                icon: Icons.notifications_none_rounded,
                value: '$notificationCount',
                label: 'alerts',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeroStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(height: 11),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC9DCDE),
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  final String label;
  final String value;
  final IconData icon;
  final String caption;

  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.caption,
  });
}

class _MetricCard extends StatelessWidget {
  final _MetricData metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 47,
              height: 47,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5F4),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(metric.icon, color: ClinexaTheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metric.label,
                    style: const TextStyle(
                      color: Color(0xFF6A778A),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metric.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    metric.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF98A2B3),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final List<dynamic> queue;
  final bool loading;

  const _QueueCard({
    required this.queue,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 19, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeading(
              icon: Icons.groups_2_outlined,
              title: 'Active queue',
              subtitle: 'Patients currently moving through care',
            ),
            const SizedBox(height: 16),
            if (loading && queue.isEmpty)
              const LinearProgressIndicator()
            else if (queue.isEmpty)
              const ClinexaEmptyState(
                icon: Icons.event_available_outlined,
                title: 'Queue is clear',
                message: 'No patients are currently waiting.',
              )
            else
              ...queue.take(6).map((raw) {
                final q = Map<String, dynamic>.from(raw);
                final token = q['queue_token']?.toString() ?? 'Queue';
                final status = q['status']?.toString() ?? 'waiting';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xFFE8EDF3)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 19,
                          backgroundColor: const Color(0xFFE3F2F1),
                          child: Text(
                            token.replaceAll('Q-', ''),
                            style: const TextStyle(
                              color: ClinexaTheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                token,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                q['start_at']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Color(0xFF8491A3),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusPill(status: status),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _NotificationsCard extends StatelessWidget {
  final List<dynamic> notifications;
  final bool loading;

  const _NotificationsCard({
    required this.notifications,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 19, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CardHeading(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              subtitle: 'Latest activity that needs attention',
            ),
            const SizedBox(height: 16),
            if (loading && notifications.isEmpty)
              const LinearProgressIndicator()
            else if (notifications.isEmpty)
              const ClinexaEmptyState(
                icon: Icons.notifications_off_outlined,
                title: 'You are all caught up',
                message: 'No new notifications right now.',
              )
            else
              ...notifications.take(5).map((raw) {
                final n = Map<String, dynamic>.from(raw);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.notifications_none_rounded,
                          size: 18,
                          color: Color(0xFF5D6B7E),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n['title']?.toString() ?? 'Notification',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              n['body']?.toString() ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF788598),
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CardHeading extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _CardHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ClinexaTheme.primary, size: 21),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF8793A4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.replaceAll('_', ' ');
    final active = status == 'in_consultation';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFE6F6EF)
            : const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style: TextStyle(
          color: active
              ? const Color(0xFF257A58)
              : const Color(0xFF966A17),
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Workspace highlights',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Clinexa V3 surfaces the tools that matter most without turning the dashboard into a wall of buttons.',
              style: TextStyle(
                color: Color(0xFF7A8799),
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: const [
                _ActionChip(
                  icon: Icons.person_add_alt_1_outlined,
                  label: 'Patient intake',
                ),
                _ActionChip(
                  icon: Icons.calendar_month_outlined,
                  label: 'Book appointment',
                ),
                _ActionChip(
                  icon: Icons.document_scanner_outlined,
                  label: 'Scan document',
                ),
                _ActionChip(
                  icon: Icons.auto_awesome_outlined,
                  label: 'AI Copilot',
                ),
                _ActionChip(
                  icon: Icons.health_and_safety_outlined,
                  label: 'Emergency Hub',
                  emergency: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool emergency;

  const _ActionChip({
    required this.icon,
    required this.label,
    this.emergency = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: emergency
            ? const Color(0xFFFFF0F1)
            : const Color(0xFFF3F7F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: emergency
              ? const Color(0xFFF4CDD1)
              : const Color(0xFFE1E9EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: emergency
                ? ClinexaTheme.emergency
                : ClinexaTheme.primary,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
