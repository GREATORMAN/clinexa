import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';

class PharmacyWorkspacePage extends StatefulWidget {
  const PharmacyWorkspacePage({super.key});
  @override
  State<PharmacyWorkspacePage> createState() => _PharmacyWorkspacePageState();
}

class _PharmacyWorkspacePageState extends State<PharmacyWorkspacePage> {
  bool loading = true;
  String? error;
  List<dynamic> requests = [];
  List<dynamic> catalog = [];
  List<dynamic> inventory = [];
  String filter = 'all';

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await Future.wait([
        Api.dio.get('/api/v1/pharmacy/requests'),
        Api.dio.get('/api/v1/pharmacy/catalog'),
        Api.dio.get('/api/v1/pharmacy/items'),
      ]);
      requests = List<dynamic>.from(result[0].data as List);
      catalog = List<dynamic>.from(result[1].data as List);
      inventory = List<dynamic>.from(result[2].data as List);
    } catch (e) {
      error = Api.errorMessage(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> changeStatus(String id, String status) async {
    try {
      await Api.dio.patch('/api/v1/pharmacy/requests/$id/status', data: {'status': status});
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 700 ? 16.0 : 28.0;
    final filtered = filter == 'all' ? requests : requests.where((x) => x['status'] == filter).toList();
    final pending = requests.where((x) => ['submitted', 'reviewing'].contains(x['status'])).length;
    final ready = requests.where((x) => x['status'] == 'ready').length;
    final low = inventory.where((x) => x['low_stock'] == true).length;

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 26, pad, 36),
        children: [
          CxPageHeader(
            eyebrow: 'Pharmacy workspace',
            title: 'Dispensing, reimagined.',
            subtitle: 'Prescription-linked patient requests, a visual medicine catalog and inventory signals in one workspace.',
            actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (_, c) {
            final cols = c.maxWidth > 900 ? 4 : c.maxWidth > 520 ? 2 : 1;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cols == 1 ? 2.4 : 1.55,
              children: [
                CxMetricCard(label: 'Requests', value: '${requests.length}', caption: 'Patient pharmacy requests', icon: Icons.shopping_bag_outlined),
                CxMetricCard(label: 'Needs review', value: '$pending', caption: 'Submitted or under review', icon: Icons.pending_actions_outlined, tone: ClinexaTheme.warning),
                CxMetricCard(label: 'Ready', value: '$ready', caption: 'Prepared for fulfillment', icon: Icons.inventory_2_outlined, tone: ClinexaTheme.success),
                CxMetricCard(label: 'Low stock', value: '$low', caption: 'Inventory items at reorder level', icon: Icons.warning_amber_rounded, tone: ClinexaTheme.emergency),
              ],
            );
          }),
          if (error != null) ...[const SizedBox(height: 14), CxErrorBanner(message: error!, onRetry: load)],
          const SizedBox(height: 16),
          CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CxSectionHeader(
              title: 'Patient request queue',
              subtitle: 'Requests are created only from medicines already verified in the patient record.',
              action: PopupMenuButton<String>(
                initialValue: filter,
                onSelected: (v) => setState(() => filter = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'all', child: Text('All requests')),
                  PopupMenuItem(value: 'submitted', child: Text('Submitted')),
                  PopupMenuItem(value: 'reviewing', child: Text('Reviewing')),
                  PopupMenuItem(value: 'ready', child: Text('Ready')),
                  PopupMenuItem(value: 'fulfilled', child: Text('Fulfilled')),
                ],
                child: CxStatusChip(label: filter == 'all' ? 'All status' : filter, icon: Icons.filter_list_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (loading) ...List.generate(4, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: CxSkeleton(height: 72))),
            if (!loading && filtered.isEmpty) const CxEmptyState(icon: Icons.local_pharmacy_outlined, title: 'No pharmacy requests', message: 'Patient prescription-fulfillment requests will appear here.'),
            if (!loading) ...filtered.take(20).map((x) => _RequestRow(request: Map<String, dynamic>.from(x as Map), onStatus: changeStatus)),
          ])),
          const SizedBox(height: 16),
          CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const CxSectionHeader(title: 'Clinexa formulary', subtitle: 'A local catalog used for OCR matching and verified pharmacy fulfillment.'),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (_, c) {
              final cols = c.maxWidth >= 980 ? 4 : c.maxWidth >= 650 ? 3 : c.maxWidth >= 430 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: catalog.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: cols == 1 ? 2.6 : .98),
                itemBuilder: (_, i) => _CatalogCard(item: Map<String, dynamic>.from(catalog[i] as Map)),
              );
            }),
          ])),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final Map<String, dynamic> request;
  final Future<void> Function(String, String) onStatus;
  const _RequestRow({required this.request, required this.onStatus});
  @override
  Widget build(BuildContext context) {
    final items = List<dynamic>.from((request['items'] as List?) ?? const []);
    final status = request['status']?.toString() ?? 'submitted';
    final color = status == 'fulfilled' ? ClinexaTheme.success : status == 'ready' ? const Color(0xFF4567C6) : status == 'declined' ? ClinexaTheme.emergency : ClinexaTheme.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: ClinexaTheme.line)),
      child: Row(children: [
        CircleAvatar(backgroundColor: ClinexaTheme.mint, foregroundColor: ClinexaTheme.primary, child: Text((request['patient_name']?.toString() ?? 'P').substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(request['patient_name']?.toString() ?? 'Patient', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('${items.length} medicine${items.length == 1 ? '' : 's'} • ${items.map((x) => x['display_name']).take(2).join(', ')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5)),
        ])),
        CxStatusChip(label: status, color: color),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          onSelected: (v) => onStatus(request['id'].toString(), v),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'reviewing', child: Text('Mark reviewing')),
            PopupMenuItem(value: 'ready', child: Text('Mark ready')),
            PopupMenuItem(value: 'fulfilled', child: Text('Mark fulfilled')),
            PopupMenuItem(value: 'declined', child: Text('Decline')),
          ],
        ),
      ]),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _CatalogCard({required this.item});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: ClinexaTheme.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CxMedicineVisual(imageKey: item['image_key']?.toString() ?? 'capsule'),
          const Spacer(),
          Text(item['display_name']?.toString() ?? 'Medicine', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 3),
          Text([item['strength'], item['form']].where((x) => x != null && x.toString().isNotEmpty).join(' • '), style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5)),
          const SizedBox(height: 7),
          Text(item['description']?.toString() ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10, height: 1.35)),
          const SizedBox(height: 8),
          CxStatusChip(label: item['category']?.toString() ?? 'Formulary', color: const Color(0xFF4567C6)),
        ]),
      );
}
