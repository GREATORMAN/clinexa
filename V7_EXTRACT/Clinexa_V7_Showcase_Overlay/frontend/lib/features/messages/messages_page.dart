import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class MessagesPage extends StatefulWidget { const MessagesPage({super.key}); @override State<MessagesPage> createState() => _MessagesPageState(); }
class _MessagesPageState extends State<MessagesPage> {
  List<dynamic> messages = []; List<dynamic> users = []; Map<String,dynamic>? me; String? error;
  @override void initState() { super.initState(); load(); }
  Future<void> load() async {
    try { final r = await Future.wait([Api.dio.get('/api/v1/messages'), Api.dio.get('/api/v1/admin/users'), Api.dio.get('/api/v1/auth/me')]); if (mounted) setState(() { messages = List.from(r[0].data); users = List.from(r[1].data); me = Map<String,dynamic>.from(r[2].data); error = null; }); } catch (e) { if (mounted) setState(() => error = Api.errorMessage(e)); }
  }
  String nameFor(String? id) { if (id == me?['id']) return '${me?['full_name'] ?? 'You'} (you)'; for (final u in users) { if (u['id'] == id) return u['full_name'].toString(); } return id ?? 'Unknown'; }
  Future<void> compose() async {
    if (users.isEmpty) { showMessage(context, 'No hospital users are available.'); return; }
    String recipient = users.first['id'].toString(); final body = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) => AlertDialog(
      title: const Text('New secure message'),
      content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: recipient, decoration: const InputDecoration(labelText: 'Recipient'), items: users.map((u) => DropdownMenuItem(value: u['id'].toString(), child: Text('${u['full_name']}${u['id'] == me?['id'] ? ' (you)' : ''}'))).toList(), onChanged: (v) => setLocal(() => recipient = v ?? recipient)),
        const SizedBox(height: 10), TextField(controller: body, minLines: 4, maxLines: 8, decoration: const InputDecoration(labelText: 'Message')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send'))],
    )));
    if (ok != true || body.text.trim().isEmpty) return;
    try { await Api.dio.post('/api/v1/messages', data: {'recipient_user_id': recipient, 'body': body.text.trim()}); if (mounted) showMessage(context, 'Message sent.'); await load(); } catch (e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }
  @override Widget build(BuildContext context) => SectionPage(
    title: 'Messages', subtitle: 'Secure internal patient/care-team communication foundation',
    actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh)), FilledButton.icon(onPressed: compose, icon: const Icon(Icons.edit), label: const Text('New'))],
    child: RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(18), children: [
      if (error != null) ErrorCard(error!),
      Card(child: Column(children: [for (final raw in messages) Builder(builder: (_) { final m = Map<String,dynamic>.from(raw); final sent = m['sender_user_id'] == me?['id']; return ListTile(leading: Icon(sent ? Icons.outbox_outlined : Icons.inbox_outlined), title: Text(m['body']?.toString() ?? ''), subtitle: Text('${sent ? 'To' : 'From'} ${nameFor(sent ? m['recipient_user_id']?.toString() : m['sender_user_id']?.toString())} • ${m['created_at'] ?? ''}')); }), if (messages.isEmpty) const Padding(padding: EdgeInsets.all(28), child: Text('No messages yet. Tap New to send one.'))])),
    ])),
  );
}

