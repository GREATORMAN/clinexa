import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../auth/login_page.dart';

class PendingApprovalPage extends StatelessWidget {
  PendingApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Api.currentUser;
    final type = (user?['account_type']?.toString() ?? 'staff').replaceAll('_', ' ');
    final status = user?['approval_status']?.toString() ?? 'pending';
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(status == 'rejected' ? Icons.block_outlined : Icons.admin_panel_settings_outlined, size: 54),
                  SizedBox(height: 16),
                  Text(status == 'rejected' ? 'Account request not approved' : 'Staff approval required', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                  SizedBox(height: 10),
                  Text(status == 'rejected' ? 'Your $type account request is currently marked rejected.' : 'Your $type account exists, but clinical and hospital workspaces stay locked until an authorized Clinexa administrator approves the role.', textAlign: TextAlign.center),
                  SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await Api.loadProfile();
                        if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PendingApprovalPage()));
                      } catch (_) {}
                    },
                    icon: Icon(Icons.refresh_rounded),
                    label: Text('Check approval status'),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      await Api.logout();
                      if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginPage()), (_) => false);
                    },
                    child: Text('Sign out'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
