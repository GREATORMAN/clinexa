import 'package:flutter/material.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';
import '../auth/login_page.dart';

class PatientPortalPage extends StatefulWidget {
  const PatientPortalPage({super.key});
  @override
  State<PatientPortalPage> createState() => _PatientPortalPageState();
}

class _PatientPortalPageState extends State<PatientPortalPage> {
  int index = 0;
  bool loading = true;
  bool pharmacyLoading = false;
  String? error;
  Map<String, dynamic>? data;
  List<dynamic> doctors = [];
  List<dynamic> catalog = [];
  List<dynamic> pharmacyRequests = [];
  final Map<String, _CartEntry> cart = {};

  @override
  void initState() { super.initState(); load(); }

  List<dynamic> list(String key) => List<dynamic>.from((data?[key] as List?) ?? const []);

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final responses = await Future.wait([
        Api.dio.get('/api/v1/portal/home'),
        Api.dio.get('/api/v1/portal/doctors'),
      ]);
      data = Map<String, dynamic>.from(responses[0].data as Map);
      doctors = List<dynamic>.from(responses[1].data as List);
    } catch (e) {
      error = Api.errorMessage(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadPharmacy() async {
    setState(() => pharmacyLoading = true);
    try {
      final responses = await Future.wait([
        Api.dio.get('/api/v1/portal/pharmacy/catalog'),
        Api.dio.get('/api/v1/portal/pharmacy/requests'),
      ]);
      catalog = List<dynamic>.from(responses[0].data as List);
      pharmacyRequests = List<dynamic>.from(responses[1].data as List);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    } finally {
      if (mounted) setState(() => pharmacyLoading = false);
    }
  }

  Future<void> logout() async {
    await Api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  Future<void> requestAppointment() async {
    if (doctors.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No doctors are currently available in this workspace.')));
      return;
    }
    String? doctorId = doctors.first['id']?.toString();
    String type = 'in_person';
    DateTime selected = DateTime.now().add(const Duration(days: 1));
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: const Text('Request appointment'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: doctorId,
              decoration: const InputDecoration(labelText: 'Doctor'),
              items: doctors.map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text('${d['full_name']} • ${d['specialty']}'))).toList(),
              onChanged: (v) => update(() => doctorId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Appointment type'),
              items: const [DropdownMenuItem(value: 'in_person', child: Text('In person')), DropdownMenuItem(value: 'teleconsultation', child: Text('Teleconsultation')), DropdownMenuItem(value: 'follow_up', child: Text('Follow-up'))],
              onChanged: (v) => update(() => type = v ?? 'in_person'),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Preferred date & time'),
              subtitle: Text(selected.toLocal().toString().substring(0, 16)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final date = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180)), initialDate: selected);
                if (date == null || !ctx.mounted) return;
                final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(selected));
                if (time == null) return;
                update(() => selected = DateTime(date.year, date.month, date.day, time.hour, time.minute));
              },
            ),
            TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason for visit', hintText: 'Briefly describe what the appointment is for')),
            const SizedBox(height: 12),
            const _PatientNote(icon: Icons.info_outline_rounded, text: 'Clinexa sends a request. The selected time is only confirmed after the scheduling workflow accepts it.'),
          ])),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send request'))],
      )),
    );
    if (ok != true || doctorId == null) return;
    try {
      await Api.dio.post('/api/v1/portal/appointments', data: {'doctor_id': doctorId, 'start_at': selected.toIso8601String(), 'appointment_type': type, 'reason': reason.text.trim().isEmpty ? null : reason.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment request created.')));
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  Future<void> cancelAppointment(Map<String, dynamic> appointment) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Cancel appointment?'),
      content: const Text('The appointment status will be changed to cancelled.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel appointment'))],
    ));
    if (ok != true) return;
    try {
      await Api.dio.post('/api/v1/portal/appointments/${appointment['id']}/cancel');
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  Future<void> logDose(Map<String, dynamic> schedule, String status) async {
    try {
      await Api.dio.post('/api/v1/portal/medications/${schedule['id']}/dose-logs', data: {'scheduled_for': DateTime.now().toIso8601String(), 'status': status, 'note': null});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Medicine marked $status.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  void addToCart(Map<String, dynamic> item) {
    if (item['request_eligible'] != true || item['matched_patient_medication_id'] == null) return;
    setState(() {
      final id = item['id'].toString();
      final existing = cart[id];
      if (existing == null) {
        cart[id] = _CartEntry(item: item, quantity: 1);
      } else if (existing.quantity < 30) {
        existing.quantity += 1;
      }
    });
  }

  Future<void> showCart() async {
    if (cart.isEmpty) return;
    final send = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Pharmacy request', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Only medicines linked to your verified Clinexa medication record can be submitted.', style: TextStyle(color: ClinexaTheme.muted, fontSize: 11.5)),
            const SizedBox(height: 14),
            ...cart.values.map((entry) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.line)),
              child: Row(children: [
                CxMedicineVisual(imageKey: entry.item['image_key']?.toString() ?? 'capsule'),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.item['display_name']?.toString() ?? 'Medicine', style: const TextStyle(fontWeight: FontWeight.w800)), Text([entry.item['strength'], entry.item['form']].where((x) => x != null).join(' • '), style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5))])),
                IconButton(onPressed: () { if (entry.quantity > 1) { update(() => entry.quantity--); } }, icon: const Icon(Icons.remove_circle_outline_rounded)),
                Text('${entry.quantity}', style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(onPressed: () { if (entry.quantity < 30) { update(() => entry.quantity++); } }, icon: const Icon(Icons.add_circle_outline_rounded)),
              ]),
            )),
            const _PatientNote(icon: Icons.shield_outlined, text: 'This sends a fulfillment request to the hospital pharmacy. It does not create or change a prescription.'),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.local_pharmacy_outlined), label: const Text('Send to pharmacy'))),
          ]),
        ),
      )),
    );
    if (send != true) return;
    try {
      await Api.dio.post('/api/v1/portal/pharmacy/requests', data: {
        'items': cart.values.map((e) => {'catalog_item_id': e.item['id'], 'patient_medication_id': e.item['matched_patient_medication_id'], 'quantity': e.quantity}).toList(),
        'note': 'Requested from Clinexa patient portal',
      });
      setState(() => cart.clear());
      await loadPharmacy();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to the hospital pharmacy.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  void selectTab(int value) {
    setState(() => index = value);
    if (value == 4 && catalog.isEmpty && !pharmacyLoading) loadPharmacy();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 940;
    final pages = [
      _homeTab(),
      _medicinesTab(),
      _appointmentsTab(),
      _recordsTab(),
      _pharmacyTab(),
    ];
    return Scaffold(
      backgroundColor: ClinexaTheme.canvas,
      body: SafeArea(
        child: Row(children: [
          if (desktop) _PatientRail(index: index, onSelected: selectTab, onLogout: logout),
          Expanded(child: Column(children: [
            _PatientTopBar(index: index, cartCount: cart.values.fold<int>(0, (a, b) => a + b.quantity), onCart: showCart, onLogout: logout),
            Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: KeyedSubtree(key: ValueKey(index), child: pages[index]))),
          ])),
        ]),
      ),
      bottomNavigationBar: desktop ? null : NavigationBar(
        selectedIndex: index,
        onDestinationSelected: selectTab,
        destinations: const [
          NavigationDestination(selectedIcon: Icon(Icons.home_rounded), icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(selectedIcon: Icon(Icons.medication_rounded), icon: Icon(Icons.medication_outlined), label: 'Medicines'),
          NavigationDestination(selectedIcon: Icon(Icons.calendar_month_rounded), icon: Icon(Icons.calendar_month_outlined), label: 'Visits'),
          NavigationDestination(selectedIcon: Icon(Icons.folder_rounded), icon: Icon(Icons.folder_outlined), label: 'Records'),
          NavigationDestination(selectedIcon: Icon(Icons.local_pharmacy_rounded), icon: Icon(Icons.local_pharmacy_outlined), label: 'Pharmacy'),
        ],
      ),
    );
  }

  Widget _base(List<Widget> children) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 640 ? 16.0 : 26.0;
    return RefreshIndicator(onRefresh: load, child: ListView(padding: EdgeInsets.fromLTRB(pad, 24, pad, 34), children: [
      if (error != null) ...[CxErrorBanner(message: error!, onRetry: load), const SizedBox(height: 14)],
      if (loading) ...[const CxSkeleton(height: 180, radius: 26), const SizedBox(height: 14), const CxSkeleton(height: 120, radius: 22)],
      if (!loading) ...children,
    ]));
  }

  Widget _homeTab() {
    final patient = data?['patient'] as Map?;
    final appointments = list('appointments');
    final medications = list('medications');
    final labs = list('labs');
    final next = appointments.where((x) => !{'completed', 'cancelled', 'no_show'}.contains(x['status'])).toList();
    return _base([
      CxPageHeader(eyebrow: 'My Clinexa', title: 'Hi, ${patient?['full_name']?.toString().split(' ').first ?? 'there'}', subtitle: 'The few things that matter now — appointments, verified medicines, results and records.', actions: [FilledButton.icon(onPressed: requestAppointment, icon: const Icon(Icons.add_rounded), label: const Text('Book visit'))]),
      const SizedBox(height: 18),
      _PatientHero(patient: patient, nextAppointment: next.isEmpty ? null : Map<String, dynamic>.from(next.first as Map), medicationCount: medications.where((x) => x['status'] == 'active').length, labCount: labs.length),
      const SizedBox(height: 14),
      LayoutBuilder(builder: (_, c) {
        final cols = c.maxWidth > 900 ? 3 : c.maxWidth > 520 ? 2 : 1;
        return GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: cols == 1 ? 2.6 : 1.5, children: [
          CxQuickAction(label: 'My medicines', caption: '${medications.length} verified medication records', icon: Icons.medication_outlined, onTap: () => selectTab(1)),
          CxQuickAction(label: 'Upcoming visits', caption: '${next.length} appointments needing attention', icon: Icons.calendar_month_outlined, onTap: () => selectTab(2), tone: const Color(0xFF4567C6)),
          CxQuickAction(label: 'Health records', caption: '${labs.length} recent lab results', icon: Icons.folder_shared_outlined, onTap: () => selectTab(3), tone: ClinexaTheme.success),
        ]);
      }),
      const SizedBox(height: 14),
      CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CxSectionHeader(title: 'Recent care activity', subtitle: 'Your newest verified health information.'),
        const SizedBox(height: 12),
        if (medications.isEmpty && labs.isEmpty) const CxEmptyState(icon: Icons.timeline_rounded, title: 'No recent activity', message: 'Verified medicines and laboratory results will appear here.'),
        ...medications.take(3).map((x) => _ActivityRow(icon: Icons.medication_outlined, title: x['medication_name']?.toString() ?? 'Medicine', subtitle: [x['strength'], x['frequency']].where((v) => v != null).join(' • '), tone: ClinexaTheme.primary)),
        ...labs.take(3).map((x) => _ActivityRow(icon: Icons.science_outlined, title: x['test_name']?.toString() ?? 'Lab result', subtitle: '${x['result_value'] ?? ''} ${x['unit'] ?? ''}', tone: const Color(0xFF4567C6))),
      ])),
    ]);
  }

  Widget _medicinesTab() {
    final meds = list('medications');
    final schedules = list('medication_schedules').where((x) => x['active'] == true).toList();
    return _base([
      CxPageHeader(eyebrow: 'Medication centre', title: 'Your medicines, clearly organized.', subtitle: 'Only clinician-verified or explicitly confirmed medication records are shown as permanent medicines.'),
      const SizedBox(height: 18),
      if (schedules.isNotEmpty) CxSurface(color: ClinexaTheme.mint, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CxSectionHeader(title: 'Today’s reminders', subtitle: 'Log what happened without changing the prescribed schedule.'),
        const SizedBox(height: 10),
        ...schedules.take(6).map((x) => _ReminderRow(schedule: Map<String, dynamic>.from(x as Map), onLog: logDose)),
      ])),
      if (schedules.isNotEmpty) const SizedBox(height: 14),
      CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CxSectionHeader(title: 'Verified medicines', subtitle: '${meds.length} records in your medication history'),
        const SizedBox(height: 12),
        if (meds.isEmpty) const CxEmptyState(icon: Icons.medication_outlined, title: 'No verified medicines', message: 'Confirmed prescriptions and clinician-entered medicines will appear here.'),
        LayoutBuilder(builder: (_, c) {
          final cols = c.maxWidth >= 820 ? 2 : 1;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: meds.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: cols == 1 ? 2.6 : 1.8),
            itemBuilder: (_, i) => _PatientMedicineCard(med: Map<String, dynamic>.from(meds[i] as Map)),
          );
        }),
      ])),
    ]);
  }

  Widget _appointmentsTab() {
    final appointments = list('appointments');
    return _base([
      CxPageHeader(eyebrow: 'Appointments', title: 'Your care calendar.', subtitle: 'Request visits and keep track of upcoming and previous appointments.', actions: [FilledButton.icon(onPressed: requestAppointment, icon: const Icon(Icons.add_rounded), label: const Text('Request visit'))]),
      const SizedBox(height: 18),
      CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CxSectionHeader(title: 'Appointments'),
        const SizedBox(height: 12),
        if (appointments.isEmpty) const CxEmptyState(icon: Icons.event_busy_outlined, title: 'No appointments yet', message: 'Your appointment history and upcoming visits will appear here.'),
        ...appointments.map((raw) {
          final a = Map<String, dynamic>.from(raw as Map);
          final status = a['status']?.toString() ?? 'requested';
          final cancellable = !{'completed', 'cancelled', 'no_show'}.contains(status);
          final tone = status == 'completed' ? ClinexaTheme.success : status == 'cancelled' ? ClinexaTheme.emergency : ClinexaTheme.primary;
          return Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: ClinexaTheme.line)),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: tone.withAlpha(17), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.event_outlined, color: tone)),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a['reason']?.toString().isNotEmpty == true ? a['reason'].toString() : 'Appointment', style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 2), Text('${a['start_at'] ?? ''} • ${a['appointment_type'] ?? 'visit'}', style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5))])),
              CxStatusChip(label: status.replaceAll('_', ' '), color: tone),
              if (cancellable) IconButton(tooltip: 'Cancel appointment', onPressed: () => cancelAppointment(a), icon: const Icon(Icons.close_rounded, size: 19)),
            ]),
          );
        }),
      ])),
    ]);
  }

  Widget _recordsTab() {
    final labs = list('labs');
    final documents = list('documents');
    return _base([
      const CxPageHeader(eyebrow: 'Records vault', title: 'Your health record, in one place.', subtitle: 'Verified results and uploaded documents stay connected to your Clinexa profile.'),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (_, c) {
        final split = c.maxWidth >= 850;
        final lab = CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CxSectionHeader(title: 'Lab results', subtitle: 'Recent verified laboratory records'),
          const SizedBox(height: 10),
          if (labs.isEmpty) const CxEmptyState(icon: Icons.science_outlined, title: 'No lab results', message: 'Verified laboratory results will appear here.'),
          ...labs.take(12).map((x) => _ActivityRow(icon: Icons.biotech_outlined, title: x['test_name']?.toString() ?? 'Lab test', subtitle: '${x['result_value'] ?? ''} ${x['unit'] ?? ''} • ref ${x['reference_range'] ?? 'not recorded'}', tone: const Color(0xFF4567C6))),
        ]));
        final docs = CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CxSectionHeader(title: 'Documents', subtitle: 'Reports, prescriptions and uploaded files'),
          const SizedBox(height: 10),
          if (documents.isEmpty) const CxEmptyState(icon: Icons.folder_outlined, title: 'No documents', message: 'Documents attached to your record will appear here.'),
          ...documents.take(12).map((x) => _ActivityRow(icon: Icons.description_outlined, title: x['original_name']?.toString() ?? 'Document', subtitle: '${x['category'] ?? 'other'} • ${x['created_at'] ?? ''}', tone: ClinexaTheme.primary)),
        ]));
        if (!split) return Column(children: [lab, const SizedBox(height: 12), docs]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: lab), const SizedBox(width: 12), Expanded(child: docs)]);
      }),
    ]);
  }

  Widget _pharmacyTab() {
    return ListView(
      padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 640 ? 16 : 26, 24, MediaQuery.sizeOf(context).width < 640 ? 16 : 26, 36),
      children: [
        CxPageHeader(
          eyebrow: 'Hospital pharmacy',
          title: 'Prescription fulfillment, not guesswork.',
          subtitle: 'Browse the local formulary. A medicine can be added to your pharmacy request only when Clinexa can link it to an active verified medication in your record.',
          actions: [
            OutlinedButton.icon(onPressed: loadPharmacy, icon: const Icon(Icons.refresh_rounded), label: const Text('Refresh')),
            FilledButton.icon(onPressed: cart.isEmpty ? null : showCart, icon: const Icon(Icons.shopping_bag_outlined), label: Text('Request bag (${cart.values.fold<int>(0, (a, b) => a + b.quantity)})')),
          ],
        ),
        const SizedBox(height: 16),
        const _PatientNote(icon: Icons.medical_information_outlined, text: 'The catalog is a hospital formulary interface, not a recommendation list. Clinexa will not create a new medication or dosage from this screen.'),
        const SizedBox(height: 14),
        if (pharmacyLoading) const CxSkeleton(height: 180, radius: 22),
        if (!pharmacyLoading && catalog.isEmpty) CxSurface(child: CxEmptyState(icon: Icons.local_pharmacy_outlined, title: 'Catalog not loaded', message: 'Refresh to load the hospital medicine catalog.', action: FilledButton(onPressed: loadPharmacy, child: const Text('Load catalog')))),
        if (!pharmacyLoading && catalog.isNotEmpty) CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CxSectionHeader(title: 'Clinexa formulary', subtitle: '${catalog.length} common catalog items available for record matching'),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (_, c) {
            final cols = c.maxWidth >= 980 ? 4 : c.maxWidth >= 650 ? 3 : c.maxWidth >= 430 ? 2 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: catalog.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: cols == 1 ? 2.45 : .78),
              itemBuilder: (_, i) => _PatientCatalogCard(item: Map<String, dynamic>.from(catalog[i] as Map), inCart: cart.containsKey(catalog[i]['id'].toString()), onAdd: () => addToCart(Map<String, dynamic>.from(catalog[i] as Map))),
            );
          }),
        ])),
        const SizedBox(height: 14),
        if (pharmacyRequests.isNotEmpty) CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CxSectionHeader(title: 'My pharmacy requests', subtitle: 'Track requests sent to the hospital pharmacy.'),
          const SizedBox(height: 10),
          ...pharmacyRequests.take(10).map((x) => _PharmacyRequestRow(request: Map<String, dynamic>.from(x as Map))),
        ])),
      ],
    );
  }
}

class _PatientRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  const _PatientRail({required this.index, required this.onSelected, required this.onLogout});
  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, 'Home'),
      (Icons.medication_outlined, 'Medicines'),
      (Icons.calendar_month_outlined, 'Appointments'),
      (Icons.folder_outlined, 'Records'),
      (Icons.local_pharmacy_outlined, 'Pharmacy'),
    ];
    return Container(
      width: 244,
      decoration: const BoxDecoration(color: Colors.white, border: Border(right: BorderSide(color: ClinexaTheme.line))),
      child: Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, 14), child: Row(children: [
          _PortalBrand(), SizedBox(width: 10), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Clinexa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -.6)), Text('Patient', style: TextStyle(color: ClinexaTheme.muted, fontSize: 10, fontWeight: FontWeight.w700))]),
        ])),
        const Divider(),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Material(color: index == i ? ClinexaTheme.mint : Colors.transparent, borderRadius: BorderRadius.circular(15), child: InkWell(borderRadius: BorderRadius.circular(15), onTap: () => onSelected(i), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), child: Row(children: [Icon(items[i].$1, color: index == i ? ClinexaTheme.primary : ClinexaTheme.muted, size: 20), const SizedBox(width: 11), Text(items[i].$2, style: TextStyle(fontWeight: index == i ? FontWeight.w800 : FontWeight.w700, fontSize: 12.5))])))),
          ),
        )),
        Padding(padding: const EdgeInsets.all(12), child: OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout_rounded), label: const Text('Sign out'))),
      ]),
    );
  }
}

class _PatientTopBar extends StatelessWidget {
  final int index;
  final int cartCount;
  final VoidCallback onCart;
  final VoidCallback onLogout;
  const _PatientTopBar({required this.index, required this.cartCount, required this.onCart, required this.onLogout});
  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 940;
    return Container(
      height: 66,
      padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 22),
      decoration: const BoxDecoration(color: Color(0xF4FFFFFF), border: Border(bottom: BorderSide(color: ClinexaTheme.line))),
      child: Row(children: [
        if (mobile) ...[const _PortalBrand(), const SizedBox(width: 9), const Text('Clinexa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))],
        if (!mobile) const Text('My health workspace', style: TextStyle(color: ClinexaTheme.muted, fontWeight: FontWeight.w700, fontSize: 11.5)),
        const Spacer(),
        if (cartCount > 0) Badge(label: Text('$cartCount'), child: IconButton(onPressed: onCart, icon: const Icon(Icons.shopping_bag_outlined), tooltip: 'Pharmacy request bag')),
        PopupMenuButton<String>(
          onSelected: (v) { if (v == 'logout') onLogout(); },
          itemBuilder: (_) => const [PopupMenuItem(value: 'logout', child: Text('Sign out'))],
          child: CircleAvatar(radius: 16, backgroundColor: ClinexaTheme.navy, child: Text((Api.currentUser?['full_name']?.toString() ?? 'P').substring(0, 1).toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11))),
        ),
      ]),
    );
  }
}

class _PortalBrand extends StatelessWidget {
  const _PortalBrand();
  @override
  Widget build(BuildContext context) => Container(width: 38, height: 38, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00B8AD), Color(0xFF006D68)]), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.add_rounded, color: Colors.white, size: 26));
}

class _PatientHero extends StatelessWidget {
  final Map? patient;
  final Map<String, dynamic>? nextAppointment;
  final int medicationCount;
  final int labCount;
  const _PatientHero({required this.patient, required this.nextAppointment, required this.medicationCount, required this.labCount});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(23),
        decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B1424), Color(0xFF0D3C49), Color(0xFF006D68)]), borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(color: Color(0x1D0B1424), blurRadius: 30, offset: Offset(0, 15))]),
        child: Wrap(spacing: 18, runSpacing: 18, alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 520, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('YOUR HEALTH, ORGANIZED', style: TextStyle(color: Color(0xFF8FE3DC), fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            const SizedBox(height: 10),
            Text(nextAppointment == null ? 'You’re all caught up.' : 'Next care moment, ready.', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 29)),
            const SizedBox(height: 8),
            Text(nextAppointment == null ? 'When something needs attention, Clinexa will surface it here.' : '${nextAppointment!['start_at'] ?? ''} • ${nextAppointment!['reason'] ?? 'Appointment'}', style: const TextStyle(color: Color(0xFFD4E6E7), fontSize: 12.5, height: 1.45)),
          ])),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _HeroMini(value: '$medicationCount', label: 'active meds', icon: Icons.medication_outlined),
            _HeroMini(value: '$labCount', label: 'lab records', icon: Icons.science_outlined),
            _HeroMini(value: patient?['blood_group']?.toString() ?? '—', label: 'blood group', icon: Icons.bloodtype_outlined),
          ]),
        ]),
      );
}

class _HeroMini extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _HeroMini({required this.value, required this.label, required this.icon});
  @override
  Widget build(BuildContext context) => Container(width: 100, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0x17FFFFFF), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0x20FFFFFF))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Colors.white, size: 18), const SizedBox(height: 10), Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(color: Color(0xFFC9DDDE), fontSize: 9.5))]));
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  const _ActivityRow({required this.icon, required this.title, required this.subtitle, required this.tone});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.line)), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: tone.withAlpha(16), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: tone, size: 18)), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5))]))]));
}

class _PatientMedicineCard extends StatelessWidget {
  final Map<String, dynamic> med;
  const _PatientMedicineCard({required this.med});
  @override
  Widget build(BuildContext context) {
    final active = med['status'] == 'active';
    return Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: active ? const Color(0xFFF7FCFB) : ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(18), border: Border.all(color: active ? const Color(0xFFCFEDE8) : ClinexaTheme.line)), child: Row(children: [
      const CxMedicineVisual(imageKey: 'capsule'),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(med['medication_name']?.toString() ?? 'Medicine', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 3),
        Text([med['strength'], med['form'], med['frequency']].where((x) => x != null && x.toString().isNotEmpty).join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5)),
        const SizedBox(height: 7),
        Wrap(spacing: 6, runSpacing: 6, children: [CxStatusChip(label: med['status']?.toString() ?? 'active', color: active ? ClinexaTheme.success : ClinexaTheme.muted), if (med['verified'] == true) const CxStatusChip(label: 'verified', color: ClinexaTheme.primary, icon: Icons.verified_rounded)]),
      ])),
    ]));
  }
}

class _ReminderRow extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final Future<void> Function(Map<String, dynamic>, String) onLog;
  const _ReminderRow({required this.schedule, required this.onLog});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFCFEAE6))), child: Row(children: [
    const Icon(Icons.alarm_rounded, color: ClinexaTheme.primary), const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(schedule['medication_name']?.toString() ?? 'Medicine', style: const TextStyle(fontWeight: FontWeight.w800)), Text('${schedule['dose_label'] ?? ''} • ${schedule['times_csv'] ?? ''}', style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5))])),
    IconButton(tooltip: 'Taken', onPressed: () => onLog(schedule, 'taken'), icon: const Icon(Icons.check_circle_outline_rounded, color: ClinexaTheme.success)),
    IconButton(tooltip: 'Skipped', onPressed: () => onLog(schedule, 'skipped'), icon: const Icon(Icons.remove_circle_outline_rounded, color: ClinexaTheme.muted)),
  ]));
}

class _PatientCatalogCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool inCart;
  final VoidCallback onAdd;
  const _PatientCatalogCard({required this.item, required this.inCart, required this.onAdd});
  @override
  Widget build(BuildContext context) {
    final eligible = item['request_eligible'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: eligible ? const Color(0xFFCFEAE6) : ClinexaTheme.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CxMedicineVisual(imageKey: item['image_key']?.toString() ?? 'capsule'), const Spacer(), CxStatusChip(label: item['category']?.toString() ?? 'Formulary', color: const Color(0xFF4567C6))]),
        const SizedBox(height: 12),
        Text(item['display_name']?.toString() ?? 'Medicine', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        const SizedBox(height: 3),
        Text([item['strength'], item['form']].where((x) => x != null && x.toString().isNotEmpty).join(' • '), style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5)),
        const SizedBox(height: 8),
        Expanded(child: Text(item['description']?.toString() ?? '', maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5, height: 1.4))),
        const SizedBox(height: 8),
        if (eligible) const CxStatusChip(label: 'Matches your verified medicine', color: ClinexaTheme.success, icon: Icons.verified_rounded) else const CxStatusChip(label: 'Verified medicine required', color: ClinexaTheme.muted, icon: Icons.lock_outline_rounded),
        const SizedBox(height: 9),
        SizedBox(width: double.infinity, child: FilledButton.tonalIcon(onPressed: eligible ? onAdd : null, icon: Icon(inCart ? Icons.check_rounded : Icons.add_shopping_cart_rounded), label: Text(inCart ? 'Add another' : 'Add to request'))),
      ]),
    );
  }
}

class _PharmacyRequestRow extends StatelessWidget {
  final Map<String, dynamic> request;
  const _PharmacyRequestRow({required this.request});
  @override
  Widget build(BuildContext context) {
    final items = List<dynamic>.from((request['items'] as List?) ?? const []);
    final status = request['status']?.toString() ?? 'submitted';
    final tone = status == 'fulfilled' ? ClinexaTheme.success : status == 'declined' ? ClinexaTheme.emergency : status == 'ready' ? const Color(0xFF4567C6) : ClinexaTheme.warning;
    return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.line)), child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: tone.withAlpha(16), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.local_pharmacy_outlined, color: tone, size: 19)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(items.map((x) => x['display_name']).take(2).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text('${items.length} item${items.length == 1 ? '' : 's'} • ${request['created_at'] ?? ''}', style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5))])),
      CxStatusChip(label: status, color: tone),
    ]));
  }
}

class _PatientNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PatientNote({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(15), border: Border.all(color: ClinexaTheme.line)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: ClinexaTheme.primary), const SizedBox(width: 9), Expanded(child: Text(text, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 10.5, height: 1.45)))]));
}

class _CartEntry {
  final Map<String, dynamic> item;
  int quantity;
  _CartEntry({required this.item, required this.quantity});
}
