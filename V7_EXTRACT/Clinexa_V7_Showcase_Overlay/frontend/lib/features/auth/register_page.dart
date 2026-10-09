import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final specialty = TextEditingController();
  String accountType = 'patient';
  bool loading = false;
  bool obscure = true;
  String? error;

  static const accountTypes = <String, String>{
    'patient': 'Patient',
    'doctor': 'Doctor',
    'nurse': 'Nurse',
    'receptionist': 'Receptionist',
    'lab_technician': 'Lab Technician',
    'pharmacist': 'Pharmacist',
    'hospital_administrator': 'Hospital Administrator',
    'billing_staff': 'Billing Staff',
    'support_staff': 'Support Staff',
    'caregiver': 'Caregiver / Family Member',
  };

  @override
  void dispose() {
    name.dispose(); email.dispose(); password.dispose(); confirm.dispose(); specialty.dispose();
    super.dispose();
  }

  Future<void> register() async {
    if (name.text.trim().length < 2 || email.text.trim().isEmpty) {
      setState(() => error = 'Enter your name and email.');
      return;
    }
    if (password.text.length < 10) {
      setState(() => error = 'Password must contain at least 10 characters.');
      return;
    }
    if (password.text != confirm.text) {
      setState(() => error = 'Passwords do not match.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final response = await Api.dio.post('/api/v1/auth/register', data: {
        'full_name': name.text.trim(),
        'email': email.text.trim(),
        'password': password.text,
        'account_type': accountType,
        if (accountType == 'doctor' && specialty.text.trim().isNotEmpty) 'specialty': specialty.text.trim(),
      });
      final result = Map<String, dynamic>.from(response.data as Map);
      if (!mounted) return;
      final staffPending = result['approval_status'] == 'pending';
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(staffPending ? 'Account request created' : 'Account created'),
          content: Text(staffPending
              ? 'Your ${accountTypes[accountType]} account must be approved by an authorized hospital administrator before clinical workspaces become available.'
              : 'Your ${accountTypes[accountType]} account is ready. Sign in to continue.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continue'))],
        ),
      );
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
    } on DioException catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Create Clinexa account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Choose your account type', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 7),
                  const Text('Clinexa creates permission-aware accounts. Staff roles require administrator approval; this is not a visual role switch.', style: TextStyle(color: Color(0xFF667085), height: 1.4)),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: accountType,
                    decoration: const InputDecoration(labelText: 'Account type'),
                    items: accountTypes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => accountType = v ?? accountType),
                  ),
                  if (accountType == 'doctor') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: specialty,
                      decoration: const InputDecoration(
                        labelText: 'Specialty',
                        hintText: 'e.g. Cardiology',
                        prefixIcon: Icon(Icons.medical_information_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded))),
                  const SizedBox(height: 12),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded))),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: obscure, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline_rounded), suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)))),
                  const SizedBox(height: 12),
                  TextField(controller: confirm, obscureText: obscure, onSubmitted: (_) => register(), decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.verified_user_outlined))),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: .45), borderRadius: BorderRadius.circular(14)), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600))),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(onPressed: loading ? null : register, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person_add_alt_1_rounded), label: Text(loading ? 'Creating…' : 'Create account')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
