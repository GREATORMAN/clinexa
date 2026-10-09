import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../shell/app_shell.dart';
import '../portal/patient_portal_page.dart';
import '../portal/pending_approval_page.dart';
import 'register_page.dart';
import 'recovery_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final mfaCode = TextEditingController();

  bool loading = false;
  bool obscure = true;
  String? error;
  String accountType = 'patient';

  static final accountTypes = <String, String>{
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
    mfaCode.dispose();
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
          if (mfaCode.text.trim().isNotEmpty) 'mfa_code': mfaCode.text.trim(),
        },
      );

      await Api.saveTokens(Map<String, dynamic>.from(response.data));
      final profile = await Api.loadProfile();

      if (!mounted) return;
      final approval = profile['approval_status']?.toString();
      final profileAccountType = profile['account_type']?.toString();
      final Widget destination;
      if (approval == 'pending' || approval == 'rejected') {
        destination = PendingApprovalPage();
      } else if (profileAccountType == 'patient') {
        destination = PatientPortalPage();
      } else {
        destination = AppShell();
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
    final wide = size.width >= 980 && size.height >= 680;
    final compact = size.width < 430;
    final short = size.height < 720;
    final scheme = Theme.of(context).colorScheme;

    final form = Container(
      padding: EdgeInsets.all(compact ? 20 : 30),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .985),
        borderRadius: BorderRadius.circular(compact ? 24 : 30),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .9)),
        boxShadow: const [
          BoxShadow(color: Color(0x1210232D), blurRadius: 44, offset: Offset(0, 20)),
          BoxShadow(color: Color(0x07159A8F), blurRadius: 14, offset: Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(gradient: ClinexaTheme.accentGradient, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Secure workspace', style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w800, fontSize: 12.2)),
              const SizedBox(height: 1),
              Text(_prettyAccount(accountType), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 9.8, fontWeight: FontWeight.w600)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(color: ClinexaTheme.mint, borderRadius: BorderRadius.circular(999)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_rounded, size: 12, color: ClinexaTheme.primary),
              SizedBox(width: 4),
              Text('Protected', style: TextStyle(color: ClinexaTheme.primary, fontSize: 9.2, fontWeight: FontWeight.w800)),
            ]),
          ),
        ]),
        SizedBox(height: compact ? 22 : 28),
        Text(
          'Welcome back.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: compact ? 28 : 32, letterSpacing: -1.0),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to the workspace assigned to your account. Clinical access remains role-protected.',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.8, height: 1.5),
        ),
        const SizedBox(height: 23),
        DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: accountType,
          decoration: const InputDecoration(labelText: 'Workspace', prefixIcon: Icon(Icons.grid_view_rounded)),
          items: accountTypes.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
          onChanged: loading ? null : (value) => setState(() => accountType = value ?? accountType),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: password,
          obscureText: obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => signIn(),
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              onPressed: () => setState(() => obscure = !obscure),
              icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: mfaCode,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Authenticator code (optional)',
            prefixIcon: Icon(Icons.shield_outlined),
            helperText: 'Only required when MFA is enabled for your account.',
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: loading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecoveryPage())),
            child: const Text('Forgot password?'),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ClinexaTheme.rose,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: ClinexaTheme.emergency.withValues(alpha: .14)),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.error_outline_rounded, color: ClinexaTheme.emergency, size: 19),
              const SizedBox(width: 9),
              Expanded(child: Text(error!, style: const TextStyle(fontSize: 10.8, height: 1.4))),
            ]),
          ),
        ],
        const SizedBox(height: 17),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: loading ? null : signIn,
            icon: loading
                ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.arrow_forward_rounded),
            label: Text(loading ? 'Opening workspace…' : 'Sign in'),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: loading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
          icon: const Icon(Icons.person_add_alt_rounded, size: 18),
          label: const Text('Create an account'),
        ),
        const SizedBox(height: 15),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.verified_user_outlined, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              'Encrypted session • role-aware access',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9.8, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ]),
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [Color(0xFF0E1518), Color(0xFF102328), Color(0xFF11171B)]
                : const [Color(0xFFF4F8F8), Color(0xFFF8FAFC), Color(0xFFF2F4FB)],
          ),
        ),
        child: SafeArea(
          child: wide
              ? Row(children: [
                  Expanded(flex: 11, child: _LoginShowcase(accountType: accountType)),
                  Expanded(
                    flex: 9,
                    child: Center(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(horizontal: 46, vertical: 28),
                        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 450), child: form),
                      ),
                    ),
                  ),
                ])
              : SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(compact ? 12 : 20, short ? 10 : 14, compact ? 12 : 20, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(children: [
                        _MobileLoginHero(accountType: accountType, compact: compact || short),
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
          boxShadow: const [BoxShadow(color: Color(0x2810232D), blurRadius: 46, offset: Offset(0, 20))],
        ),
        child: Stack(children: [
          Positioned(
            right: -88,
            top: -72,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .08), width: 34)),
            ),
          ),
          Positioned(
            left: 120,
            bottom: -180,
            child: Container(width: 380, height: 380, decoration: BoxDecoration(shape: BoxShape.circle, color: ClinexaTheme.primaryBright.withValues(alpha: .09))),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Brand(light: true),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: .10)),
              ),
              child: const Text('CLINEXA • CONNECTED CARE', style: TextStyle(color: Color(0xFFAEE8E2), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ),
            const SizedBox(height: 18),
            const Text(
              'Care, beautifully\nconnected.',
              style: TextStyle(color: Colors.white, fontSize: 52, height: 1.01, fontWeight: FontWeight.w800, letterSpacing: -2.2),
            ),
            const SizedBox(height: 18),
            const SizedBox(
              width: 560,
              child: Text(
                'One calm workspace for Patient 360°, verified prescriptions, medicines, appointments, hospital operations, emergency access and private local AI.',
                style: TextStyle(color: Color(0xFFD3E1E3), fontSize: 14.2, height: 1.55),
              ),
            ),
            const SizedBox(height: 27),
            const Wrap(spacing: 9, runSpacing: 9, children: [
              _FeaturePill(icon: Icons.blur_circular_rounded, label: 'Patient 360°'),
              _FeaturePill(icon: Icons.document_scanner_outlined, label: 'Verified OCR'),
              _FeaturePill(icon: Icons.local_pharmacy_outlined, label: 'Pharmacy flow'),
              _FeaturePill(icon: Icons.auto_awesome_outlined, label: 'Local AI'),
            ]),
            const Spacer(),
            Row(children: [
              const Icon(Icons.verified_user_outlined, color: Color(0xFFAEE8E2), size: 17),
              const SizedBox(width: 7),
              Text('Opening ${_prettyAccount(accountType)} workspace', style: const TextStyle(color: Color(0xFFC8D7DA), fontSize: 10.8, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ]),
      );
}

class _MobileLoginHero extends StatelessWidget {
  final String accountType;
  final bool compact;
  const _MobileLoginHero({required this.accountType, required this.compact});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(18, compact ? 16 : 19, 18, compact ? 17 : 21),
        decoration: BoxDecoration(
          gradient: ClinexaTheme.heroGradient,
          borderRadius: BorderRadius.circular(25),
          boxShadow: const [BoxShadow(color: Color(0x2410232D), blurRadius: 30, offset: Offset(0, 12))],
        ),
        child: Stack(children: [
          Positioned(
            right: -35,
            top: -45,
            child: Container(width: 140, height: 140, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .08), width: 18))),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _Brand(light: true),
            SizedBox(height: compact ? 15 : 22),
            Text(
              compact ? 'Care. Connected.' : 'Your care.\nConnected.',
              style: TextStyle(color: Colors.white, fontSize: compact ? 23 : 28, height: 1.04, fontWeight: FontWeight.w800, letterSpacing: -1.05),
            ),
            const SizedBox(height: 8),
            const Text('A secure role-aware healthcare workspace built around one patient record.', style: TextStyle(color: Color(0xFFD3E1E3), fontSize: 11.2, height: 1.45)),
            if (!compact) ...[
              const SizedBox(height: 14),
              Wrap(spacing: 7, runSpacing: 7, children: [
                const _FeaturePill(icon: Icons.document_scanner_outlined, label: 'OCR'),
                const _FeaturePill(icon: Icons.medication_outlined, label: 'Medicines'),
                _FeaturePill(icon: Icons.badge_outlined, label: _prettyAccount(accountType)),
              ]),
            ],
          ]),
        ]),
      );
}

String _prettyAccount(String value) => value
    .replaceAll('_', ' ')
    .split(' ')
    .map((x) => x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}')
    .join(' ');

class _Brand extends StatelessWidget {
  final bool light;
  const _Brand({this.light = false});

  @override
  Widget build(BuildContext context) {
    final foreground = light ? Colors.white : Theme.of(context).colorScheme.primary;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: light ? null : ClinexaTheme.accentGradient,
          color: light ? Colors.white.withValues(alpha: .11) : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: light ? Colors.white.withValues(alpha: .10) : Colors.transparent),
        ),
        child: Icon(Icons.health_and_safety_rounded, color: light ? foreground : Colors.white, size: 23),
      ),
      const SizedBox(width: 11),
      Text('Clinexa', style: TextStyle(color: foreground, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.8)),
    ]);
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: .11)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: const Color(0xFFDAF6F2), size: 16),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ]),
      );
}
