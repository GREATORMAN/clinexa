import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<dynamic> rows = [];
  bool loading = true;
  bool saving = false;
  bool unreadOnly = false;
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final r = await Api.dio.get('/api/v1/notifications');
      if (mounted) setState(() => rows = List<dynamic>.from(r.data));
    } catch (e) { if (mounted) setState(() => error = Api.errorMessage(e)); }
    finally { if (mounted) setState(() => loading = false); }
  }
  Future<void> read([dynamic row]) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      if (row == null) { await Api.dio.post('/api/v1/notifications/read-all'); }
      else { await Api.dio.patch('/api/v1/notifications/${row['id']}/read'); }
      await load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e)))); }
    finally { if (mounted) setState(() => saving = false); }
  }
  @override
  Widget build(BuildContext context) {
    final unread = rows.where((r) => r['is_read'] != true).length;
    final visible = rows.where((r) => !unreadOnly || r['is_read'] != true).toList();
    return RefreshIndicator(onRefresh: load, child: ListView(padding: EdgeInsets.all(20), children: [
      CxPageHeader(eyebrow: 'Your inbox', title: 'Stay in the loop.', subtitle: loading ? 'Loading notifications…' : '$unread unread notifications in your account.', actions: [OutlinedButton.icon(onPressed: saving || loading || unread == 0 ? null : () => read(), icon: Icon(Icons.done_all_rounded), label: Text('Mark all read'))]),
      SizedBox(height: 20),
      Wrap(spacing: 8, children: [ChoiceChip(label: Text('All'), selected: !unreadOnly, onSelected: (_) => setState(() => unreadOnly = false)), ChoiceChip(label: Text('Unread ($unread)'), selected: unreadOnly, onSelected: (_) => setState(() => unreadOnly = true))]),
      SizedBox(height: 16),
      if (error != null) CxErrorBanner(message: error!, onRetry: load),
      if (loading) ...List.generate(4, (_) => Padding(padding: EdgeInsets.only(bottom: 12), child: CxSkeleton(height: 100))),
      if (!loading && error == null && visible.isEmpty) CxEmptyState(icon: Icons.notifications_none_rounded, title: 'You’re all caught up', message: 'New workflow notifications will appear here.'),
      if (!loading) ...visible.map((r) => Padding(padding: EdgeInsets.only(bottom: 12), child: CxSurface(onTap: saving || r['is_read'] == true ? null : () => read(r), color: r['is_read'] == true ? Colors.white : Color(0xFFF0FAF7), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.notifications_outlined, color: ClinexaTheme.primary)),
        SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${r['title']}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)), SizedBox(height: 6), Text('${r['body'] ?? ''}', style: TextStyle(fontSize: 13, height: 1.5, color: Theme.of(context).colorScheme.onSurfaceVariant)), SizedBox(height: 10), Text(r['is_read'] == true ? 'Read' : 'Tap to mark read', style: TextStyle(fontSize: 11, color: ClinexaTheme.primary))])),
        if (r['is_read'] != true) Icon(Icons.circle, size: 8, color: ClinexaTheme.primary),
      ])))),
    ]));
  }
}
