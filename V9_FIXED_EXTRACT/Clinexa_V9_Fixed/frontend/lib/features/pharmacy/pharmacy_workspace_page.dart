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
            icon: Icons.local_pharmacy_rounded,
            eyebrow: 'Pharmacy workspace',
            title: 'Dispensing, reimagined.',
            subtitle: 'Prescription-linked patient requests, a visual medicine catalog and inventory signals in one workspace.',
            actions: [IconButton(onPressed: load, icon: Icon(Icons.refresh_rounded))],
          ),
          SizedBox(height: 20),
          CxAdaptiveGrid(
            minItemWidth: 210,
            children: [
              CxMetricCard(label: 'Requests', value: '${requests.length}', caption: 'Patient pharmacy requests', icon: Icons.shopping_bag_outlined),
              CxMetricCard(label: 'Needs review', value: '$pending', caption: 'Submitted or under review', icon: Icons.pending_actions_outlined, tone: ClinexaTheme.warning),
              CxMetricCard(label: 'Ready', value: '$ready', caption: 'Prepared for fulfillment', icon: Icons.inventory_2_outlined, tone: ClinexaTheme.success),
              CxMetricCard(label: 'Low stock', value: '$low', caption: 'Inventory items at reorder level', icon: Icons.warning_amber_rounded, tone: ClinexaTheme.emergency),
            ],
          ),
          if (error != null) ...[SizedBox(height: 14), CxErrorBanner(message: error!, onRetry: load)],
          SizedBox(height: 16),
          CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CxSectionHeader(
              title: 'Patient request queue',
              subtitle: 'Requests are created only from medicines already verified in the patient record.',
              action: PopupMenuButton<String>(
                initialValue: filter,
                onSelected: (v) => setState(() => filter = v),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'all', child: Text('All requests')),
                  PopupMenuItem(value: 'submitted', child: Text('Submitted')),
                  PopupMenuItem(value: 'reviewing', child: Text('Reviewing')),
                  PopupMenuItem(value: 'ready', child: Text('Ready')),
                  PopupMenuItem(value: 'fulfilled', child: Text('Fulfilled')),
                ],
                child: CxStatusChip(label: filter == 'all' ? 'All status' : filter, icon: Icons.filter_list_rounded),
              ),
            ),
            SizedBox(height: 12),
            if (loading) ...List.generate(4, (_) => Padding(padding: EdgeInsets.only(bottom: 10), child: CxSkeleton(height: 72))),
            if (!loading && filtered.isEmpty) CxEmptyState(icon: Icons.local_pharmacy_outlined, title: 'No pharmacy requests', message: 'Patient prescription-fulfillment requests will appear here.'),
            if (!loading) ...filtered.take(20).map((x) => _RequestRow(request: Map<String, dynamic>.from(x as Map), onStatus: changeStatus)),
          ])),
          SizedBox(height: 16),
          CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            CxSectionHeader(title: 'Clinexa formulary', subtitle: 'A local catalog used for OCR matching and verified pharmacy fulfillment.'),
            SizedBox(height: 14),
            CxAdaptiveGrid(
              minItemWidth: 205,
              maxColumns: 4,
              children: catalog.map((raw) => _CatalogCard(item: Map<String, dynamic>.from(raw as Map))).toList(),
            ),
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
    final items = List<dynamic>.from((request['items'] as List?) ?? []);
    final status = request['status']?.toString() ?? 'submitted';
    final color = status == 'fulfilled' ? ClinexaTheme.success : status == 'ready' ? Color(0xFF4567C6) : status == 'declined' ? ClinexaTheme.emergency : ClinexaTheme.warning;
    return Container(
      margin: EdgeInsets.only(bottom: 9),
      padding: EdgeInsets.all(13),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Row(children: [
        CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, foregroundColor: ClinexaTheme.primary, child: Text((request['patient_name']?.toString() ?? 'P').substring(0, 1).toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800))),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(request['patient_name']?.toString() ?? 'Patient', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 2),
          Text('${items.length} medicine${items.length == 1 ? '' : 's'} • ${items.map((x) => x['display_name']).take(2).join(', ')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5)),
        ])),
        CxStatusChip(label: status, color: color),
        SizedBox(width: 4),
        PopupMenuButton<String>(
          onSelected: (v) => onStatus(request['id'].toString(), v),
          itemBuilder: (_) => [
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
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CxMedicineVisual(imageKey: item['image_key']?.toString() ?? 'capsule'),
          SizedBox(height: 14),
          Text(item['display_name']?.toString() ?? 'Medicine', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          SizedBox(height: 3),
          Text([item['strength'], item['form']].where((x) => x != null && x.toString().isNotEmpty).join(' • '), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5)),
          SizedBox(height: 7),
          Text(item['description']?.toString() ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10, height: 1.35)),
          SizedBox(height: 8),
          CxStatusChip(label: item['category']?.toString() ?? 'Formulary', color: Color(0xFF4567C6)),
        ]),
      );
}
