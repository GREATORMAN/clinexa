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
    if (loading) return;
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
      final profileAccountType = profile['account_type']?.toString();
      final Widget destination;
      if (approval == 'pending' || approval == 'rejected') {
        destination = const PendingApprovalPage();
      } else if (profileAccountType == 'patient') {
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
    final size = MediaQuery.sizeOf(context);
    final wide = size.width >= 980 && size.height >= 750;
    final compact = size.width < 520;

    final form = Container(
      padding: EdgeInsets.all(compact ? 20 : 30),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .97),
        borderRadius: BorderRadius.circular(compact ? 24 : 30),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(color: Color(0x1710182B), blurRadius: 42, offset: Offset(0, 18)),
          BoxShadow(color: Color(0x0A0B776E), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (wide) ...[
          Row(children: [
            Container(width: 38, height: 38, decoration: BoxDecoration(gradient: ClinexaTheme.accentGradient, borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 10),
            const Text('Secure workspace', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
          ]),
          const SizedBox(height: 24),
        ],
        Text('Care starts here.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: compact ? 27 : 31, letterSpacing: -1.0)),
        const SizedBox(height: 8),
        const Text('Sign into the workspace assigned to your account. Clinical access stays role-protected.', style: TextStyle(color: ClinexaTheme.muted, fontSize: 11.8, height: 1.5)),
        const SizedBox(height: 24),
        DropdownButtonFormField<String>(isExpanded: true, 
          initialValue: accountType,
          decoration: const InputDecoration(labelText: 'Workspace', prefixIcon: Icon(Icons.grid_view_rounded)),
          items: accountTypes.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
          onChanged: loading ? null : (value) => setState(() => accountType = value ?? accountType),
        ),
        const SizedBox(height: 12),
        TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded))),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: obscure,
          onSubmitted: (_) => signIn(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(onPressed: () => setState(() => obscure = !obscure), icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: ClinexaTheme.rose, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.emergency.withValues(alpha: .12))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.error_outline_rounded, color: ClinexaTheme.emergency, size: 19), const SizedBox(width: 9), Expanded(child: Text(error!, style: const TextStyle(fontSize: 10.8, height: 1.4)))]),
          ),
        ],
        const SizedBox(height: 17),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: loading ? null : signIn,
            icon: loading ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward_rounded),
            label: Text(loading ? 'Opening workspace…' : 'Sign in'),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: loading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
          icon: const Icon(Icons.person_add_alt_rounded, size: 18),
          label: const Text('Create an account'),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.lock_rounded, size: 13, color: ClinexaTheme.muted), SizedBox(width: 5), Flexible(child: Text('Use fictional/demo patient data during development.', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.8, color: ClinexaTheme.muted)))]),
      ]),
    );

    return Scaffold(
      backgroundColor: ClinexaTheme.canvas,
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF3F7F8), Color(0xFFF7F7FC), Color(0xFFEEF7F5)])),
        child: SafeArea(
          child: wide
              ? Row(children: [
                  Expanded(flex: 11, child: _LoginShowcase(accountType: accountType)),
                  Expanded(
                    flex: 9,
                    child: Center(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 30), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 450), child: form))),
                  ),
                ])
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(compact ? 14 : 24, 14, compact ? 14 : 24, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(children: [
                        _MobileLoginHero(accountType: accountType),
                        const SizedBox(height: 12),
                        form,
                      ]),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

}

class _LoginShowcase extends StatelessWidget {
  final String accountType;
  const _LoginShowcase({required this.accountType});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(42),
        decoration: BoxDecoration(
          gradient: ClinexaTheme.heroGradient,
          borderRadius: BorderRadius.circular(34),
          boxShadow: const [BoxShadow(color: Color(0x2410182B), blurRadius: 40, offset: Offset(0, 18))],
        ),
        child: Stack(children: [
          Positioned(right: -90, top: -70, child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .045)))),
          Positioned(left: 130, bottom: -180, child: Container(width: 380, height: 380, decoration: BoxDecoration(shape: BoxShape.circle, color: ClinexaTheme.primaryBright.withValues(alpha: .10)))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Brand(light: true),
            const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .09), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white.withValues(alpha: .10))), child: const Text('CLINEXA • HEALTHCARE OS', style: TextStyle(color: Color(0xFF9DE7E0), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.2))),
            const SizedBox(height: 18),
            const Text('A better day,\nfor everyone in care.', style: TextStyle(color: Colors.white, fontSize: 50, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -2.0)),
            const SizedBox(height: 18),
            const SizedBox(width: 560, child: Text('Patient 360°, prescription OCR, medicines, hospital operations, emergency access and private local AI — connected around the same clinical record.', style: TextStyle(color: Color(0xFFD4E1E7), fontSize: 14.5, height: 1.55))),
            const SizedBox(height: 26),
            Wrap(spacing: 9, runSpacing: 9, children: const [
              _FeaturePill(icon: Icons.blur_circular_rounded, label: 'Patient 360°'),
              _FeaturePill(icon: Icons.document_scanner_outlined, label: 'Verified OCR'),
              _FeaturePill(icon: Icons.local_pharmacy_outlined, label: 'Pharmacy flow'),
              _FeaturePill(icon: Icons.auto_awesome_outlined, label: 'Local AI'),
            ]),
            const Spacer(),
            Row(children: [const Icon(Icons.verified_user_outlined, color: Color(0xFF9DE7E0), size: 17), const SizedBox(width: 7), Text('Opening ${_prettyAccount(accountType)} workspace', style: const TextStyle(color: Color(0xFFC9D8DE), fontSize: 10.8, fontWeight: FontWeight.w700))]),
          ]),
        ]),
      );
}

class _MobileLoginHero extends StatelessWidget {
  final String accountType;
  const _MobileLoginHero({required this.accountType});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        decoration: BoxDecoration(gradient: ClinexaTheme.heroGradient, borderRadius: BorderRadius.circular(27), boxShadow: const [BoxShadow(color: Color(0x2510182B), blurRadius: 28, offset: Offset(0, 12))]),
        child: Stack(children: [
          Positioned(right: -36, top: -42, child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .055)))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Brand(light: true),
            const SizedBox(height: 22),
            const Text('Your care.\nConnected.', style: TextStyle(color: Colors.white, fontSize: 27, height: 1.05, fontWeight: FontWeight.w800, letterSpacing: -1.1)),
            const SizedBox(height: 9),
            const Text('Secure, role-aware care workflows built around one patient record.', style: TextStyle(color: Color(0xFFD4E1E7), fontSize: 11.3, height: 1.45)),
            const SizedBox(height: 15),
            Wrap(spacing: 7, runSpacing: 7, children: [
              const _FeaturePill(icon: Icons.document_scanner_outlined, label: 'OCR'),
              const _FeaturePill(icon: Icons.medication_outlined, label: 'Medicines'),
              _FeaturePill(icon: Icons.badge_outlined, label: _prettyAccount(accountType)),
            ]),
          ]),
        ]),
      );
}

String _prettyAccount(String value) => value.replaceAll('_', ' ').split(' ').map((x) => x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}').join(' ');

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
                ? Colors.white.withValues(alpha: .13)
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
        color: Colors.white.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
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
