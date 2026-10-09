import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityGate extends StatefulWidget {
  final Widget child;
  const SecurityGate({super.key, required this.child});

  @override
  State<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends State<SecurityGate> {
  final _auth = LocalAuthentication();
  bool _checking = true;
  bool _locked = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('clinexa_biometric_lock') ?? false;
    if (!enabled) {
      if (mounted) setState(() => _checking = false);
      return;
    }
    if (mounted) setState(() { _checking = false; _locked = true; });
    await _unlock();
  }

  Future<void> _unlock() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        if (mounted) setState(() { _locked = true; _message = 'Device authentication is not available. Unlock requires a supported device.'; });
        return;
      }
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock Clinexa',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
      if (mounted) setState(() { _locked = !ok; _message = ok ? null : 'Authentication required to unlock Clinexa.'; });
    } catch (_) {
      if (mounted) setState(() { _locked = true; _message = 'Could not start device authentication.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_locked) return widget.child;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_person_outlined, size: 54),
                const SizedBox(height: 18),
                const Text('Clinexa is locked', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(_message ?? 'Use your device lock to continue.', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(onPressed: _unlock, icon: const Icon(Icons.fingerprint), label: const Text('Unlock')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
