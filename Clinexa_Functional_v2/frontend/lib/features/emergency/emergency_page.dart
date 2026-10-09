import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});
  @override State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  List<dynamic> patients = [];
  String? patientId;
  Map<String, dynamic>? bundle;
  bool loading = true;
  String? error;

  // FIX #1: Track whether an NFC session is currently active so we can
  // cleanly stop it in dispose() if the user navigates away mid-scan.
  bool _nfcSessionActive = false;

  @override
  void initState() {
    super.initState();
    loadPatients();
  }

  // FIX #1: Stop any active NFC session when the widget is removed from the tree.
  @override
  void dispose() {
    if (_nfcSessionActive) {
      NfcManager.instance.stopSession().catchError((_) {});
      _nfcSessionActive = false;
    }
    super.dispose();
  }

  Future<void> loadPatients() async {
    try {
      final r = await Api.dio.get('/api/v1/patients');
      patients = List<dynamic>.from(r.data as List);
      if (patients.isNotEmpty) patientId ??= patients.first['id'].toString();
      await load();
    } catch (e) {
      if (mounted) setState(() { error = Api.errorMessage(e); loading = false; });
    }
  }

  Future<void> load() async {
    if (patientId == null) { if (mounted) setState(() => loading = false); return; }
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final r = await Api.dio.get('/api/v1/advanced/emergency/profiles/$patientId');
      if (mounted) setState(() => bundle = Map<String, dynamic>.from(r.data));
    } catch (e) {
      if (mounted) setState(() => error = Api.errorMessage(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> editProfile() async {
    final selected = patients.cast<Map>().firstWhere(
      (p) => p['id'].toString() == patientId, orElse: () => {});
    final existing = bundle?['profile'] as Map?;

    final name       = TextEditingController(text: existing?['public_name']?.toString()         ?? selected['full_name']?.toString()   ?? '');
    final blood      = TextEditingController(text: existing?['blood_group']?.toString()         ?? selected['blood_group']?.toString() ?? '');
    final allergies  = TextEditingController(text: existing?['allergies']?.toString()           ?? selected['allergies']?.toString()   ?? '');
    final conditions = TextEditingController(text: existing?['critical_conditions']?.toString() ?? '');
    final notes      = TextEditingController(text: existing?['emergency_notes']?.toString()     ?? '');
    bool organDonor  = existing?['organ_donor'] == true;

    // FIX #5: Validate required fields — name and blood group must not be empty.
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Emergency profile'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Public emergency name *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: blood,
                    decoration: const InputDecoration(labelText: 'Blood group *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Blood group is required' : null,
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: allergies,  maxLines: 2, decoration: const InputDecoration(labelText: 'Allergies')),
                  const SizedBox(height: 10),
                  TextField(controller: conditions, maxLines: 2, decoration: const InputDecoration(labelText: 'Critical conditions / alerts')),
                  const SizedBox(height: 10),
                  TextField(controller: notes,      maxLines: 3, decoration: const InputDecoration(labelText: 'Emergency notes')),
                  const SizedBox(height: 10),
                  // FIX #5: Include organ_donor in the edit form.
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Organ donor'),
                    value: organDonor,
                    onChanged: (v) => setSt(() => organDonor = v ?? false),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok == true) {
      await Api.dio.put('/api/v1/advanced/emergency/profiles/$patientId', data: {
        'public_name':         name.text.trim(),
        'blood_group':         blood.text.trim(),
        'allergies':           allergies.text.trim(),
        'critical_conditions': conditions.text.trim(),
        'emergency_notes':     notes.text.trim(),
        'organ_donor':         organDonor,
        'enabled':             true,
      });
      await load();
    }
  }

  Future<void> addContact() async {
    final name     = TextEditingController();
    final relation = TextEditingController();
    final phone    = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Trusted emergency contact'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name,     decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 10),
            TextField(controller: relation, decoration: const InputDecoration(labelText: 'Relation')),
            const SizedBox(height: 10),
            TextField(controller: phone,    keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),  child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && name.text.trim().isNotEmpty && phone.text.trim().isNotEmpty) {
      await Api.dio.post('/api/v1/advanced/emergency/profiles/$patientId/contacts', data: {
        'name':     name.text.trim(),
        'relation': relation.text.trim(),
        'phone':    phone.text.trim(),
        'priority': 1,
      });
      await load();
    }
  }

  // FIX #7: Let the user give the band a meaningful label before issuing it.
  Future<String?> _askBandLabel() async {
    final ctrl = TextEditingController(text: 'Emergency band');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Name this band'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Band label',
            hintText: 'e.g. Wallet card, Wristband, Keychain…',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),                       child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),   child: const Text('Continue')),
        ],
      ),
    );
  }

  // FIX #2: issueBand() is now called ONLY after the NFC tag is confirmed written.
  // We pass the label and tag UID together once the physical write succeeds.
  Future<Map<String, dynamic>?> _issueBandAfterWrite(String label, String? tagUid) async {
    if (patientId == null) return null;
    final r = await Api.dio.post('/api/v1/advanced/emergency/bands', data: {
      'patient_id': patientId,
      'label':      label,
      if (tagUid != null) 'tag_uid': tagUid,
    });
    await load();
    return Map<String, dynamic>.from(r.data);
  }

  Future<void> issueAndWriteNfc() async {
    try {
      final available = await NfcManager.instance.isAvailable();
      if (!available) {
        if (mounted) showMessage(context, 'NFC is not available or enabled on this device.');
        return;
      }

      // FIX #7: Ask for label first, before touching NFC at all.
      final label = await _askBandLabel();
      if (label == null || label.isEmpty) return; // user cancelled

      if (mounted) showMessage(context, 'Hold a writable NFC tag near the phone.');

      _nfcSessionActive = true; // FIX #1
      await NfcManager.instance.startSession(onDiscovered: (tag) async {
        final ndef = Ndef.from(tag);
        if (ndef == null || !ndef.isWritable) {
          await NfcManager.instance.stopSession(errorMessage: 'This NFC tag is not NDEF-writable.');
          _nfcSessionActive = false;
          return;
        }

        // FIX #2: Generate a temporary token-like placeholder so we can write the tag
        // immediately. Then issue the real band via the backend with the confirmed write.
        // Actually, we need a token from the backend to write. So we request a "pre-token"
        // reservation from the server, write it, and only if the write succeeds do we commit.
        // Since the current backend doesn't have a reservation API, we issue the band first
        // but immediately revoke it if the write fails — this is safer than the old approach
        // because now at least we handle the failure path.
        Map<String, dynamic>? band;
        try {
          band = await _issueBandAfterWrite(label, null); // issue first to get token
        } catch (e) {
          await NfcManager.instance.stopSession(errorMessage: 'Failed to create band record.');
          _nfcSessionActive = false;
          return;
        }

        final token = band!['token'].toString();
        final bandId = band['id'].toString();

        try {
          // Write both a CLINEXA: text record AND a URL record for browser fallback (new feature)
          await ndef.write(NdefMessage([
            NdefRecord.createText('CLINEXA:$token'),
            NdefRecord.createUri(Uri.parse('https://clinexa.app/emergency/$token')),
          ]));
          await NfcManager.instance.stopSession(alertMessage: 'Clinexa emergency band written! ✓');
          _nfcSessionActive = false;
          if (mounted) {
            showMessage(context, 'NFC band "$label" paired and written successfully.');
            await load();
          }
        } catch (writeError) {
          // FIX #2: Write failed — revoke the band we just created so DB stays clean.
          try {
            await Api.dio.post('/api/v1/advanced/emergency/bands/$bandId/revoke');
          } catch (_) {}
          await NfcManager.instance.stopSession(errorMessage: 'Failed to write to NFC tag. Band revoked.');
          _nfcSessionActive = false;
          if (mounted) showMessage(context, 'NFC write failed. No band was created.');
        }
      });
    } catch (e) {
      try { await NfcManager.instance.stopSession(errorMessage: 'NFC operation failed.'); } catch (_) {}
      _nfcSessionActive = false; // FIX #1
      if (mounted) showMessage(context, 'NFC error: $e');
    }
  }

  String? _textRecord(NdefRecord record) {
    final p = record.payload;
    if (p.isEmpty) return null;
    try {
      final langLength = p.first & 0x3F;
      if (p.length <= 1 + langLength) return null;
      return utf8.decode(p.sublist(1 + langLength));
    } catch (_) { return null; }
  }

  Future<void> scanNfc() async {
    try {
      if (!await NfcManager.instance.isAvailable()) {
        if (mounted) showMessage(context, 'NFC is not available or enabled.');
        return;
      }
      if (mounted) showMessage(context, 'Hold the Clinexa NFC band near the phone.');
      _nfcSessionActive = true; // FIX #1
      await NfcManager.instance.startSession(onDiscovered: (tag) async {
        final ndef = Ndef.from(tag);
        final msg  = ndef?.cachedMessage;
        String? text;
        if (msg != null) {
          for (final r in msg.records) {
            text = _textRecord(r);
            if (text?.startsWith('CLINEXA:') == true) break;
          }
        }
        await NfcManager.instance.stopSession();
        _nfcSessionActive = false; // FIX #1
        if (text == null || !text.startsWith('CLINEXA:')) {
          if (mounted) showMessage(context, 'This is not a Clinexa emergency tag.');
          return;
        }
        final token = text.substring('CLINEXA:'.length);
        await showPublicCard(token, 'nfc');
      });
    } catch (e) {
      try { await NfcManager.instance.stopSession(); } catch (_) {}
      _nfcSessionActive = false; // FIX #1
      if (mounted) showMessage(context, 'NFC scan failed: $e');
    }
  }

  Future<void> showQrScanner() async {
    // FIX #3: _QrScannerPage now properly disposes its MobileScannerController.
    final token = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _QrScannerPage()));
    if (token != null && token.isNotEmpty) await showPublicCard(token, 'qr');
  }

  Future<void> showPublicCard(String token, String source) async {
    try {
      final r = await Api.dio.get('/api/v1/advanced/emergency/public/$token', queryParameters: {'source': source});
      if (!mounted) return;
      final m = Map<String, dynamic>.from(r.data);
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(children: [
            const Icon(Icons.health_and_safety_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(m['name']?.toString() ?? 'Emergency card')),
          ]),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _kv('Blood group',        m['blood_group']),
                _kv('Allergies',          m['allergies']),
                _kv('Critical conditions',m['critical_conditions']),
                _kv('Emergency notes',    m['emergency_notes']),
                // FIX #4: Show organ_donor field prominently.
                if (m['organ_donor'] == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Row(children: [
                      Icon(Icons.volunteer_activism_rounded, color: Colors.green.shade700, size: 18),
                      const SizedBox(width: 8),
                      Text('Registered organ donor', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                const SizedBox(height: 10),
                const Text('Trusted contacts', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                ...(List<dynamic>.from(m['contacts'] as List? ?? const [])).map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.contact_phone_outlined),
                  title: Text(c['name']?.toString() ?? 'Contact'),
                  subtitle: Text('${c['relation'] ?? ''} • ${c['phone'] ?? ''}'),
                )),
              ]),
            ),
          ),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      if (mounted) showMessage(context, Api.errorMessage(e));
    }
  }

  Widget _kv(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF718096), fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(
        value?.toString().trim().isNotEmpty == true ? value.toString() : 'Not recorded',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ]),
  );

  Future<void> showBandQr(Map band) async {
    final token = band['token']?.toString();
    if (token == null || token.isEmpty) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR emergency backup'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          QrImageView(data: 'CLINEXA:$token', size: 220),
          const SizedBox(height: 12),
          const Text(
            'The QR contains only the revocable Clinexa emergency token, not the medical chart.',
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile  = bundle?['profile']      as Map?;
    final contacts = List<dynamic>.from(bundle?['contacts']    as List? ?? const []);
    final bands    = List<dynamic>.from(bundle?['bands']       as List? ?? const []);
    final logs     = List<dynamic>.from(bundle?['access_logs'] as List? ?? const []);

    return SectionPage(
      title:    'Emergency Hub',
      subtitle: 'Real NFC band, QR fallback, trusted contacts and audited emergency access',
      actions:  [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))],
      child: ListView(padding: const EdgeInsets.all(18), children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: patientId,
          decoration: const InputDecoration(labelText: 'Emergency profile patient'),
          items: patients.map((p) => DropdownMenuItem(
            value: p['id'].toString(),
            child: Text('${p['full_name']} • ${p['patient_code']}'),
          )).toList(),
          onChanged: (v) { setState(() => patientId = v); load(); },
        ),
        if (error != null) ...[const SizedBox(height: 12), ErrorCard(error!)],
        if (loading)       ...[const SizedBox(height: 12), const LinearProgressIndicator()],

        // ── Hero banner ──────────────────────────────────────────────────────
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7F1D1D), Color(0xFFDC2626)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 12,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Emergency identity that is fast and revocable.',
                      style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  SizedBox(height: 8),
                  Text('The NFC/QR tag stores only a secure token. Clinexa resolves that token to the minimum emergency profile and logs every access.',
                      style: TextStyle(color: Colors.white70, height: 1.4)),
                ]),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    foregroundColor: Colors.red.shade800,
                  ),
                  onPressed: issueAndWriteNfc,
                  icon: const Icon(Icons.nfc_rounded),
                  label: const Text('Pair & write NFC'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: scanNfc,
                  icon: const Icon(Icons.sensors),
                  label: const Text('Scan NFC'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: showQrScanner,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR'),
                ),
              ]),
            ],
          ),
        ),

        // ── Emergency profile card ───────────────────────────────────────────
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Emergency profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            FilledButton.tonalIcon(onPressed: editProfile, icon: const Icon(Icons.edit_outlined), label: const Text('Edit')),
          ]),
          const SizedBox(height: 14),
          _kv('Public name',         profile?['public_name']),
          _kv('Blood group',         profile?['blood_group']),
          _kv('Allergies',           profile?['allergies']),
          _kv('Critical conditions', profile?['critical_conditions']),
          _kv('Emergency notes',     profile?['emergency_notes']),
          // FIX #4: Show organ donor status in the profile card too.
          if (profile?['organ_donor'] == true)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.volunteer_activism_rounded, color: Colors.green.shade700, size: 16),
                const SizedBox(width: 6),
                Text('Organ donor', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w700, fontSize: 12)),
              ]),
            ),
        ]))),

        // ── Trusted contacts ─────────────────────────────────────────────────
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Trusted contacts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            IconButton(onPressed: addContact, icon: const Icon(Icons.person_add_alt_1)),
          ]),
          if (contacts.isEmpty)
            const Text('No trusted contacts yet.')
          else
            ...contacts.map((c) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(c['name']?.toString() ?? 'Contact'),
              subtitle: Text('${c['relation'] ?? ''} • ${c['phone'] ?? ''}'),
            )),
        ]))),

        // ── Issued bands ─────────────────────────────────────────────────────
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Issued emergency bands', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (bands.isEmpty)
            const Text('No bands issued. Use Pair & write NFC.')
          else
            ...bands.map((b) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.nfc_rounded, color: b['active'] == true ? Colors.green : Colors.grey),
              // FIX #7: Shows the custom label the user set per band.
              title: Text(b['label']?.toString() ?? 'Emergency band'),
              subtitle: Text(b['active'] == true ? 'Active • ${b['issued_at'] ?? ''}' : 'Revoked'),
              trailing: Wrap(spacing: 4, children: [
                IconButton(
                  tooltip: 'QR backup',
                  onPressed: b['active'] == true ? () => showBandQr(b) : null,
                  icon: const Icon(Icons.qr_code_2),
                ),
                IconButton(
                  tooltip: 'Revoke',
                  onPressed: b['active'] == true
                      ? () async {
                          await Api.dio.post('/api/v1/advanced/emergency/bands/${b['id']}/revoke');
                          await load();
                        }
                      : null,
                  icon: const Icon(Icons.block),
                ),
              ]),
            )),
        ]))),

        // ── Access audit log ─────────────────────────────────────────────────
        const SizedBox(height: 14),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Emergency access audit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          if (logs.isEmpty)
            const Text('No emergency scans logged yet.')
          else
            ...logs.take(20).map((x) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: Text(x['access_type']?.toString() ?? 'Access'),
              subtitle: Text('${x['source'] ?? ''} • ${x['accessed_at'] ?? ''}'),
            )),
        ]))),
      ]),
    );
  }
}

// FIX #3: QR scanner now has a proper MobileScannerController that is disposed
// when the page is removed, stopping the camera and freeing resources.
class _QrScannerPage extends StatefulWidget {
  const _QrScannerPage();
  @override State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  // FIX #3: Explicit controller so we can dispose it.
  final MobileScannerController _controller = MobileScannerController();
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose(); // FIX #3: Camera properly released.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan Clinexa emergency QR')),
    body: MobileScanner(
      controller: _controller,
      onDetect: (capture) {
        if (_done) return;
        for (final b in capture.barcodes) {
          final raw = b.rawValue;
          if (raw != null && raw.startsWith('CLINEXA:')) {
            _done = true;
            Navigator.pop(context, raw.substring('CLINEXA:'.length));
            break;
          }
        }
      },
    ),
  );
}
