import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({super.key});
  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  bool biometric = false;
  Map<String, dynamic>? me;
  Map<String, dynamic>? ai;
  List<dynamic> users = [];
  bool canManageUsers = false;
  String backend = 'Checking…';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    biometric = prefs.getBool('clinexa_biometric_lock') ?? false;
    try {
      final results = await Future.wait([
        Api.dio.get('/api/v1/auth/me'),
        Api.dio.get('/api/v1/ai/status'),
        Api.dio.get('/health'),
      ]);
      me = Map<String, dynamic>.from(results[0].data as Map);
      ai = Map<String, dynamic>.from(results[1].data as Map);
      backend = 'Online';
    } catch (_) {
      backend = 'Unavailable';
    }

    try {
      final response = await Api.dio.get('/api/v1/admin/users');
      users = List<dynamic>.from(response.data as List);
      canManageUsers = true;
    } catch (_) {
      users = [];
      canManageUsers = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> toggleBiometric(bool value) async {
    if (value) {
      try {
        final auth = LocalAuthentication();
        final supported = await auth.isDeviceSupported();
        if (!supported) {
          if (mounted) showMessage(context, 'Device authentication is not supported on this device.');
          return;
        }
        final ok = await auth.authenticate(
          localizedReason: 'Enable Clinexa app lock',
          options: AuthenticationOptions(biometricOnly: false),
        );
        if (!ok) return;
      } catch (e) {
        if (mounted) showMessage(context, 'Could not enable device authentication: $e');
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('clinexa_biometric_lock', value);
    if (mounted) setState(() => biometric = value);
  }

  Future<void> updateApproval(Map<String, dynamic> user, bool approve) async {
    final action = approve ? 'approve' : 'reject';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve staff account?' : 'Reject account request?'),
        content: Text('${user['full_name']} requested ${(user['account_type'] ?? 'staff').toString().replaceAll('_', ' ')} access.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(approve ? 'Approve' : 'Reject')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.dio.post('/api/v1/admin/users/${user['id']}/$action');
      if (mounted) showMessage(context, approve ? 'Account approved.' : 'Account rejected.');
      await load();
    } catch (e) {
      if (mounted) showMessage(context, Api.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = users.where((u) => u['approval_status'] == 'pending').toList();
    return SectionPage(
      title: 'Security & Settings',
      subtitle: 'Account permissions, staff approvals, device protection and local services',
      actions: [IconButton(onPressed: load, icon: Icon(Icons.refresh_rounded))],
      child: ListView(
        padding: EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Account', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 12),
                _line(Icons.person_outline, '${me?['full_name'] ?? '—'}', '${me?['email'] ?? ''}'),
                _line(Icons.badge_outlined, 'Roles', (me?['roles'] as List?)?.join(', ') ?? '—'),
                _line(Icons.account_tree_outlined, 'Account type', '${(me?['account_type'] ?? 'legacy').toString().replaceAll('_', ' ')} • ${me?['approval_status'] ?? 'approved'}'),
              ]),
            ),
          ),
          if (canManageUsers) ...[
            SizedBox(height: 12),
            Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('Staff access approvals', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    Container(padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: pending.isEmpty ? Color(0xFFE7F4EE) : Color(0xFFFFEDBF), borderRadius: BorderRadius.circular(999)), child: Text('${pending.length} pending', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700))),
                  ]),
                  SizedBox(height: 6),
                  Text('Staff accounts remain permission-locked until an authorized administrator approves their requested role.', style: TextStyle(fontSize: 11.5, color: Color(0xFF667085))),
                  SizedBox(height: 12),
                  if (pending.isEmpty)
                    Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('No pending staff requests.'))
                  else
                    ...pending.map((raw) {
                      final user = Map<String, dynamic>.from(raw as Map);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                        title: Text(user['full_name']?.toString() ?? 'User'),
                        subtitle: Text('${user['email']} • ${(user['account_type'] ?? 'staff').toString().replaceAll('_', ' ')}'),
                        trailing: Wrap(spacing: 4, children: [
                          IconButton(tooltip: 'Reject', onPressed: () => updateApproval(user, false), icon: Icon(Icons.close_rounded)),
                          FilledButton.tonalIcon(onPressed: () => updateApproval(user, true), icon: Icon(Icons.check_rounded), label: Text('Approve')),
                        ]),
                      );
                    }),
                ]),
              ),
            ),
          ],
          SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: biometric,
              onChanged: toggleBiometric,
              secondary: Icon(Icons.fingerprint_rounded),
              title: Text('Device / biometric lock', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('Require device authentication when Clinexa starts.'),
            ),
          ),
          SizedBox(height: 12),
          Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Environment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 12),
                _line(Icons.cloud_done_outlined, 'Backend', backend),
                _line(Icons.auto_awesome_outlined, 'Ollama', ai?['online'] == true ? 'Online • ${ai?['model']}' : 'Unavailable • ${ai?['model'] ?? 'model not reported'}'),
                _line(Icons.storage_outlined, 'API', Api.baseUrl),
              ]),
            ),
          ),
          SizedBox(height: 12),
          Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Privacy controls', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                SizedBox(height: 8),
                Text('Clinexa V5 keeps OCR medicine imports in a draft state until human confirmation, uses backend-enforced role permissions, provides administrator approval for staff accounts, and keeps patient portal access scoped to the linked patient record. Continue using fictional data until production security, hosting, backup and compliance reviews are completed.', style: TextStyle(height: 1.45, color: Color(0xFF64748B))),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String title, String sub) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(sub),
      );
}
