import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../shell/app_shell.dart';
import '../portal/patient_portal_page.dart';
import '../portal/pending_approval_page.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool loading = false;
  bool obscure = true;
  String? error;
  String accountType = 'patient';

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
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Enter your email and password.');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final response = await Api.dio.post(
        '/api/v1/auth/login',
        data: {
          'email': email.text.trim(),
          'password': password.text,
          'account_type': accountType,
        },
      );

      await Api.saveTokens(Map<String, dynamic>.from(response.data));
      final profile = await Api.loadProfile();

      if (!mounted) return;
      final approval = profile['approval_status']?.toString();
      final accountType = profile['account_type']?.toString();
      final Widget destination;
      if (approval == 'pending' || approval == 'rejected') {
        destination = const PendingApprovalPage();
      } else if (accountType == 'patient') {
        destination = const PatientPortalPage();
      } else {
        destination = const AppShell();
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => destination),
      );
    } on DioException catch (e) {
      if (mounted) {
        setState(() => error = Api.errorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 940;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              Expanded(
                flex: 11,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(42),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ClinexaTheme.navy,
                        Color(0xFF164C5A),
                        ClinexaTheme.primary,
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Brand(light: true),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(.16),
                          ),
                        ),
                        child: const Text(
                          'CLINICAL OPERATING SYSTEM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Healthcare,\nbeautifully connected.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 48,
                          height: 1.03,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.7,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const SizedBox(
                        width: 520,
                        child: Text(
                          'Patients, appointments, records, OCR, operations, emergency workflows and local AI in one secure workspace.',
                          style: TextStyle(
                            color: Color(0xFFD5E5E7),
                            fontSize: 16,
                            height: 1.55,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _FeaturePill(
                            icon: Icons.health_and_safety_outlined,
                            label: 'Emergency ready',
                          ),
                          _FeaturePill(
                            icon: Icons.auto_awesome_outlined,
                            label: 'Local AI',
                          ),
                          _FeaturePill(
                            icon: Icons.document_scanner_outlined,
                            label: 'OCR',
                          ),
                          _FeaturePill(
                            icon: Icons.lock_outline_rounded,
                            label: 'Role protected',
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        'Clinexa • private healthcare workspace',
                        style: TextStyle(
                          color: Color(0xFFB7CED1),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              flex: wide ? 9 : 1,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: width < 520 ? 20 : 42,
                    vertical: 28,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: EdgeInsets.all(width < 520 ? 22 : 30),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFE3E9F0)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0D132238),
                            blurRadius: 30,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!wide) ...[
                            const _Brand(),
                            const SizedBox(height: 28),
                          ],
                          Text(
                            'Welcome back',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontSize: 30),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose the workspace that matches your verified account, then sign in.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 28),
                          DropdownButtonFormField<String>(
                            value: accountType,
                            decoration: const InputDecoration(
                              labelText: 'Sign in to workspace',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            items: accountTypes.entries
                                .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value)))
                                .toList(),
                            onChanged: loading ? null : (value) => setState(() => accountType = value ?? accountType),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: password,
                            obscureText: obscure,
                            onSubmitted: (_) => signIn(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => obscure = !obscure),
                                icon: Icon(
                                  obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer
                                    .withOpacity(.45),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                error!,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed: loading ? null : signIn,
                            icon: loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              loading ? 'Signing in…' : 'Enter workspace',
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: loading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                            child: const Text('Create patient or staff account'),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'For development, use only fictional/demo patient data.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final bool light;

  const _Brand({this.light = false});

  @override
  Widget build(BuildContext context) {
    final foreground =
        light ? Colors.white : Theme.of(context).colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: light
                ? Colors.white.withOpacity(.13)
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.health_and_safety_rounded,
            color: foreground,
            size: 24,
          ),
        ),
        const SizedBox(width: 11),
        Text(
          'Clinexa',
          style: TextStyle(
            color: foreground,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
          ),
        ),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
