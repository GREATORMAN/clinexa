import 'package:flutter/material.dart';

import '../../core/network/api.dart';
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
        Api.dio.get('/api/v1/appointments/queue/today'),
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
            'Some dashboard data could not be loaded. Check the backend and your account permissions.';
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data ?? <String, dynamic>{};

    final cards = <(String, String, IconData)>[
      (
        'Patients',
        d['patients']?.toString() ?? '—',
        Icons.people_outline,
      ),
      (
        'Doctors',
        d['doctors']?.toString() ?? '—',
        Icons.medical_services_outlined,
      ),
      (
        'Appointments',
        d['appointments']?.toString() ?? '—',
        Icons.calendar_month_outlined,
      ),
      (
        'Paid invoices',
        d['paid_invoice_total']?.toString() ?? '—',
        Icons.payments_outlined,
      ),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final cols = width > 1250
        ? 4
        : width > 700
            ? 2
            : 1;

    return SectionPage(
      title: 'Hospital Overview',
      subtitle: 'Live data from the Clinexa backend',
      actions: [
        IconButton(
          onPressed: loading ? null : load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
        ),
      ],
      child: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (error != null) ...[
              ErrorCard(error!),
              const SizedBox(height: 12),
            ],
            if (loading && data == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.15,
              ),
              itemCount: cards.length,
              itemBuilder: (context, index) {
                final card = cards[index];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        CircleAvatar(
                          child: Icon(card.$3),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(card.$1),
                              const SizedBox(height: 6),
                              Text(
                                card.$2,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Active queue',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Card(
              child: Column(
                children: [
                  for (final q in queue)
                    ListTile(
                      leading: const Icon(Icons.hourglass_top),
                      title: Text(
                        q['queue_token']?.toString() ?? 'Queue',
                      ),
                      subtitle: Text(
                        '${q['status'] ?? ''} • ${q['start_at'] ?? ''}',
                      ),
                    ),
                  if (queue.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'No patients currently waiting.',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Notifications',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Card(
              child: Column(
                children: [
                  for (final n in notifications.take(5))
                    ListTile(
                      leading: const Icon(Icons.notifications_none),
                      title: Text(
                        n['title']?.toString() ?? 'Notification',
                      ),
                      subtitle: Text(
                        n['body']?.toString() ?? '',
                      ),
                    ),
                  if (notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No notifications.'),
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
