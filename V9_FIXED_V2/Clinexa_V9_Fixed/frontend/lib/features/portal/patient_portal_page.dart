import 'package:flutter/material.dart';
import '../workspace/account_page.dart';
import '../workspace/privacy_page.dart';
import '../../core/notifications/reminders.dart';

import '../../core/network/api.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/clinexa_ui.dart';
import '../auth/login_page.dart';
import '../notifications/notifications_page.dart';

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
  String pharmacyQuery = '';
  String pharmacyCategory = 'All';

  @override
  void initState() { super.initState(); load(); }

  List<dynamic> list(String key) => List<dynamic>.from((data?[key] as List?) ?? []);

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final responses = await Future.wait([
        Api.dio.get('/api/v1/portal/home'),
        Api.dio.get('/api/v1/portal/doctors'),
      ]);
      data = Map<String, dynamic>.from(responses[0].data as Map);
      doctors = List<dynamic>.from(responses[1].data as List);
      try { await MedicationReminders.sync(list("medication_schedules").map((s)=>Map<String,dynamic>.from(s as Map)).toList()); } catch (_) { MedicationReminders.status.value="Reminder refresh failed · try enabling again"; }
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
    await MedicationReminders.disable();
    await Api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginPage()), (_) => false);
  }

  Future<void> requestAppointment() async {
    if (doctors.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No doctors are currently available in this workspace.')));
      return;
    }
    String? doctorId = doctors.first['id']?.toString();
    String type = 'in_person';
    DateTime selected = DateTime.now().add(Duration(days: 1));
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, update) => AlertDialog(
        title: Text('Request appointment'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(isExpanded: true, 
              initialValue: doctorId,
              decoration: InputDecoration(labelText: 'Doctor'),
              items: doctors.map((d) => DropdownMenuItem<String>(value: d['id'].toString(), child: Text('${d['full_name']} • ${d['specialty']}'))).toList(),
              onChanged: (v) => update(() => doctorId = v),
            ),
            SizedBox(height: 10),
            DropdownButtonFormField<String>(isExpanded: true, 
              initialValue: type,
              decoration: InputDecoration(labelText: 'Appointment type'),
              items: [DropdownMenuItem(value: 'in_person', child: Text('In person')), DropdownMenuItem(value: 'teleconsultation', child: Text('Teleconsultation')), DropdownMenuItem(value: 'follow_up', child: Text('Follow-up'))],
              onChanged: (v) => update(() => type = v ?? 'in_person'),
            ),
            SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.schedule_rounded),
              title: Text('Preferred date & time'),
              subtitle: Text(selected.toLocal().toString().substring(0, 16)),
              trailing: Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final date = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime.now().add(Duration(days: 180)), initialDate: selected);
                if (date == null || !ctx.mounted) return;
                final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(selected));
                if (time == null) return;
                update(() => selected = DateTime(date.year, date.month, date.day, time.hour, time.minute));
              },
            ),
            TextField(controller: reason, maxLines: 3, decoration: InputDecoration(labelText: 'Reason for visit', hintText: 'Briefly describe what the appointment is for')),
            SizedBox(height: 12),
            _PatientNote(icon: Icons.info_outline_rounded, text: 'Clinexa sends a request. The selected time is only confirmed after the scheduling workflow accepts it.'),
          ])),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Send request'))],
      )),
    );
    if (ok != true || doctorId == null) return;
    try {
      await Api.dio.post('/api/v1/portal/appointments', data: {'doctor_id': doctorId, 'start_at': selected.toIso8601String(), 'appointment_type': type, 'reason': reason.text.trim().isEmpty ? null : reason.text.trim()});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Appointment request created.')));
      await load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Api.errorMessage(e))));
    }
  }

  Future<void> cancelAppointment(Map<String, dynamic> appointment) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text('Cancel appointment?'),
      content: Text('The appointment status will be changed to cancelled.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep it')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Cancel appointment'))],
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
          padding: EdgeInsets.fromLTRB(18, 2, 18, 22),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pharmacy request', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            SizedBox(height: 4),
            Text('Only medicines linked to your verified Clinexa medication record can be submitted.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11.5)),
            SizedBox(height: 14),
            ...cart.values.map((entry) => Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(11),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
              child: Row(children: [
                CxMedicineVisual(imageKey: entry.item['image_key']?.toString() ?? 'capsule'),
                SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.item['display_name']?.toString() ?? 'Medicine', style: TextStyle(fontWeight: FontWeight.w800)), Text([entry.item['strength'], entry.item['form']].where((x) => x != null).join(' • '), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5))])),
                IconButton(onPressed: () { if (entry.quantity > 1) { update(() => entry.quantity--); } }, icon: Icon(Icons.remove_circle_outline_rounded)),
                Text('${entry.quantity}', style: TextStyle(fontWeight: FontWeight.w800)),
                IconButton(onPressed: () { if (entry.quantity < 30) { update(() => entry.quantity++); } }, icon: Icon(Icons.add_circle_outline_rounded)),
              ]),
            )),
            _PatientNote(icon: Icons.shield_outlined, text: 'This sends a fulfillment request to the hospital pharmacy. It does not create or change a prescription.'),
            SizedBox(height: 14),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: Icon(Icons.local_pharmacy_outlined), label: Text('Send to pharmacy'))),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request sent to the hospital pharmacy.')));
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Row(children: [
          if (desktop) _PatientRail(index: index, onSelected: selectTab, onLogout: logout),
          Expanded(child: Column(children: [
            _PatientTopBar(index: index, cartCount: cart.values.fold<int>(0, (a, b) => a + b.quantity), onCart: showCart, onLogout: logout),
            Expanded(child: AnimatedSwitcher(duration: Duration(milliseconds: 260), child: KeyedSubtree(key: ValueKey(index), child: pages[index]))),
          ])),
        ]),
      ),
      bottomNavigationBar: desktop ? null : _PatientDock(index: index, onSelected: selectTab),
    );
  }

  Widget _base(List<Widget> children) {
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 640 ? 16.0 : 26.0;
    return RefreshIndicator(onRefresh: load, child: ListView(padding: EdgeInsets.fromLTRB(pad, 24, pad, 34), children: [
      if (error != null) ...[CxErrorBanner(message: error!, onRetry: load), SizedBox(height: 14)],
      if (loading) ...[CxSkeleton(height: 180, radius: 26), SizedBox(height: 14), CxSkeleton(height: 120, radius: 22)],
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
      CxPageHeader(eyebrow: 'My Clinexa', title: 'Hi, ${patient?['full_name']?.toString().split(' ').first ?? 'there'}', subtitle: 'The few things that matter now — appointments, verified medicines, results and records.', icon: Icons.favorite_rounded, actions: [FilledButton.icon(onPressed: requestAppointment, icon: Icon(Icons.add_rounded), label: Text('Book visit'))]),
      SizedBox(height: 18),
      CxSpotlightHero(
        eyebrow: 'Your health, organized',
        title: next.isEmpty ? 'You’re all caught up.' : 'Your next care moment is ready.',
        subtitle: next.isEmpty ? 'When something needs attention, Clinexa will surface it here.' : '${next.first['start_at'] ?? ''} • ${next.first['reason'] ?? 'Appointment'}',
        icon: Icons.health_and_safety_rounded,
        stats: [
          CxHeroStat(value: '${medications.where((x) => x['status'] == 'active').length}', label: 'active meds', icon: Icons.medication_outlined),
          CxHeroStat(value: '${labs.length}', label: 'lab records', icon: Icons.science_outlined),
          CxHeroStat(value: patient?['blood_group']?.toString() ?? '—', label: 'blood group', icon: Icons.bloodtype_outlined),
        ],
      ),
      SizedBox(height: 14),
      CxAdaptiveGrid(minItemWidth: 240, maxColumns: 3, children: [
        CxQuickAction(label: 'My medicines', caption: '${medications.length} verified medication records', icon: Icons.medication_outlined, onTap: () => selectTab(1)),
        CxQuickAction(label: 'Upcoming visits', caption: '${next.length} appointments needing attention', icon: Icons.calendar_month_outlined, onTap: () => selectTab(2), tone: ClinexaTheme.accent),
        CxQuickAction(label: 'Health records', caption: '${labs.length} recent lab results', icon: Icons.folder_shared_outlined, onTap: () => selectTab(3), tone: ClinexaTheme.success),
      ]),
      SizedBox(height: 14),
      CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CxSectionHeader(title: 'Recent care activity', subtitle: 'Your newest verified health information.'),
        SizedBox(height: 12),
        if (medications.isEmpty && labs.isEmpty) CxEmptyState(icon: Icons.timeline_rounded, title: 'No recent activity', message: 'Verified medicines and laboratory results will appear here.'),
        ...medications.take(3).map((x) => _ActivityRow(icon: Icons.medication_outlined, title: x['medication_name']?.toString() ?? 'Medicine', subtitle: [x['strength'], x['frequency']].where((v) => v != null).join(' • '), tone: ClinexaTheme.primary)),
        ...labs.take(3).map((x) => _ActivityRow(icon: Icons.science_outlined, title: x['test_name']?.toString() ?? 'Lab result', subtitle: '${x['result_value'] ?? ''} ${x['unit'] ?? ''}', tone: Color(0xFF4567C6))),
      ])),
    ]);
  }

  Widget _medicinesTab() {
    final meds = list('medications');
    final schedules = list('medication_schedules').where((x) => x['active'] == true).toList();
    return _base([
      CxPageHeader(eyebrow: 'Medication centre', title: 'Your medicines, clearly organized.', subtitle: 'Verified medicines, reminders and prescription provenance — without mixing drafts into your permanent record.', icon: Icons.medication_rounded, actions: [OutlinedButton.icon(onPressed: () => selectTab(4), icon: Icon(Icons.local_pharmacy_outlined), label: Text('Open pharmacy'))]),
      SizedBox(height: 18),
      if (schedules.isNotEmpty) CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Device reminders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 10), ValueListenableBuilder<String>(valueListenable: MedicationReminders.status, builder: (_, value, __) => Text(value)), SizedBox(height: 12), Wrap(spacing: 10, runSpacing: 8, children: [FilledButton.icon(onPressed: () async { try { await MedicationReminders.enable(schedules.map((s) => Map<String,dynamic>.from(s as Map)).toList()); } catch (e) { MedicationReminders.status.value=Api.errorMessage(e); } }, icon: Icon(Icons.notifications_active_outlined), label: Text('Enable / refresh reminders')), TextButton(onPressed: MedicationReminders.disable, child: Text('Turn off')), TextButton(onPressed: MedicationReminders.flush, child: Text('Retry dose sync'))]), SizedBox(height: 8), Text('Schedules the next seven days, up to 60 notifications. Delivery follows device permission and battery settings.', style: Theme.of(context).textTheme.bodySmall)])),
      if (schedules.isNotEmpty) SizedBox(height: 14),
      if (schedules.isNotEmpty) CxSurface(color: Theme.of(context).colorScheme.primaryContainer, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CxSectionHeader(title: 'Today’s reminders', subtitle: 'Log what happened without changing the prescribed schedule.'),
        SizedBox(height: 10),
        ...schedules.take(6).map((x) => _ReminderRow(schedule: Map<String, dynamic>.from(x), onLog: logDose)),
      ])),
      if (schedules.isNotEmpty) SizedBox(height: 14),
      CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CxSectionHeader(title: 'Verified medicines', subtitle: '${meds.length} records in your medication history'),
        SizedBox(height: 12),
        if (meds.isEmpty) CxEmptyState(icon: Icons.medication_outlined, title: 'No verified medicines', message: 'Confirmed prescriptions and clinician-entered medicines will appear here.'),
        CxAdaptiveGrid(minItemWidth: 330, maxColumns: 2, children: [
          for (final raw in meds) _PatientMedicineCard(med: Map<String, dynamic>.from(raw)),
        ]),
      ])),
    ]);
  }

  Widget _appointmentsTab() {
    final appointments = list('appointments');
    return _base([
      CxPageHeader(eyebrow: 'Appointments', title: 'Your care calendar.', subtitle: 'Request visits and keep track of upcoming and previous appointments.', icon: Icons.calendar_month_rounded, actions: [FilledButton.icon(onPressed: requestAppointment, icon: Icon(Icons.add_rounded), label: Text('Request visit'))]),
      SizedBox(height: 18),
      CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CxSectionHeader(title: 'Appointments'),
        SizedBox(height: 12),
        if (appointments.isEmpty) CxEmptyState(icon: Icons.event_busy_outlined, title: 'No appointments yet', message: 'Your appointment history and upcoming visits will appear here.'),
        ...appointments.map((raw) {
          final a = Map<String, dynamic>.from(raw);
          final status = a['status']?.toString() ?? 'requested';
          final cancellable = !{'completed', 'cancelled', 'no_show'}.contains(status);
          final tone = status == 'completed' ? ClinexaTheme.success : status == 'cancelled' ? ClinexaTheme.emergency : ClinexaTheme.primary;
          return Container(
            margin: EdgeInsets.only(bottom: 9),
            padding: EdgeInsets.all(13),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: tone.withAlpha(17), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.event_outlined, color: tone)),
              SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(a['reason']?.toString().isNotEmpty == true ? a['reason'].toString() : 'Appointment', style: TextStyle(fontWeight: FontWeight.w800)), SizedBox(height: 2), Text('${a['start_at'] ?? ''} • ${a['appointment_type'] ?? 'visit'}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5))])),
              CxStatusChip(label: status.replaceAll('_', ' '), color: tone),
              if (cancellable) IconButton(tooltip: 'Cancel appointment', onPressed: () => cancelAppointment(a), icon: Icon(Icons.close_rounded, size: 19)),
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
      CxPageHeader(eyebrow: 'Records vault', title: 'Your health record, in one place.', subtitle: 'Verified results and uploaded documents stay connected to your Clinexa profile.', icon: Icons.folder_copy_rounded),
      SizedBox(height: 18),
      LayoutBuilder(builder: (_, c) {
        final split = c.maxWidth >= 850;
        final lab = CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CxSectionHeader(title: 'Lab results', subtitle: 'Recent verified laboratory records'),
          SizedBox(height: 10),
          if (labs.isEmpty) CxEmptyState(icon: Icons.science_outlined, title: 'No lab results', message: 'Verified laboratory results will appear here.'),
          ...labs.take(12).map((x) => _ActivityRow(icon: Icons.biotech_outlined, title: x['test_name']?.toString() ?? 'Lab test', subtitle: '${x['result_value'] ?? ''} ${x['unit'] ?? ''} • ref ${x['reference_range'] ?? 'not recorded'}', tone: Color(0xFF4567C6))),
        ]));
        final docs = CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CxSectionHeader(title: 'Documents', subtitle: 'Reports, prescriptions and uploaded files'),
          SizedBox(height: 10),
          if (documents.isEmpty) CxEmptyState(icon: Icons.folder_outlined, title: 'No documents', message: 'Documents attached to your record will appear here.'),
          ...documents.take(12).map((x) => _ActivityRow(icon: Icons.description_outlined, title: x['original_name']?.toString() ?? 'Document', subtitle: '${x['category'] ?? 'other'} • ${x['created_at'] ?? ''}', tone: ClinexaTheme.primary)),
        ]));
        if (!split) return Column(children: [lab, SizedBox(height: 12), docs]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: lab), SizedBox(width: 12), Expanded(child: docs)]);
      }),
    ]);
  }

  Widget _pharmacyTab() {
    final filteredCatalog = catalog.where((x) {
      final categoryOk = pharmacyCategory == 'All' || x['category']?.toString() == pharmacyCategory;
      if (!categoryOk) return false;
      if (pharmacyQuery.trim().isEmpty) return true;
      final q = pharmacyQuery.toLowerCase();
      return '${x['display_name']} ${x['generic_name']} ${x['category']} ${x['form']} ${x['strength']}'.toLowerCase().contains(q);
    }).toList();
    return ListView(
      padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 640 ? 16 : 26, 24, MediaQuery.sizeOf(context).width < 640 ? 16 : 26, 36),
      children: [
        CxPageHeader(
          eyebrow: 'Hospital pharmacy',
          title: 'Prescription fulfillment, not guesswork.',
          subtitle: 'Browse the hospital formulary with images and descriptions. Requesting stays locked to medicines already verified in your record.',
          icon: Icons.local_pharmacy_rounded,
          actions: [
            OutlinedButton.icon(onPressed: loadPharmacy, icon: Icon(Icons.refresh_rounded), label: Text('Refresh')),
            FilledButton.icon(onPressed: cart.isEmpty ? null : showCart, icon: Icon(Icons.shopping_bag_outlined), label: Text('Request bag (${cart.values.fold<int>(0, (a, b) => a + b.quantity)})')),
          ],
        ),
        SizedBox(height: 16),
        _PatientNote(icon: Icons.medical_information_outlined, text: 'The catalog is a hospital formulary interface, not a recommendation list. Clinexa will not create a new medication or dosage from this screen.'),
        SizedBox(height: 14),
        if (pharmacyLoading) CxSkeleton(height: 180, radius: 22),
        if (!pharmacyLoading && catalog.isEmpty) CxSurface(child: CxEmptyState(icon: Icons.local_pharmacy_outlined, title: 'Catalog not loaded', message: 'Refresh to load the hospital medicine catalog.', action: FilledButton(onPressed: loadPharmacy, child: Text('Load catalog')))),
        if (!pharmacyLoading && catalog.isNotEmpty) CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CxSectionHeader(title: 'Clinexa formulary', subtitle: '${catalog.length} common catalog items • ${filteredCatalog.length} shown'),
          SizedBox(height: 12),
          TextField(onChanged: (v) => setState(() => pharmacyQuery = v), decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search medicine, category, form or strength…')),
          SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final category in <String>{'All', ...catalog.map((x) => x['category']?.toString()).whereType<String>()})
                Padding(padding: EdgeInsets.only(right: 7), child: ChoiceChip(label: Text(category), selected: pharmacyCategory == category, onSelected: (_) => setState(() => pharmacyCategory = category))),
            ]),
          ),
          SizedBox(height: 14),
          CxAdaptiveGrid(minItemWidth: 230, maxColumns: 4, children: [
            for (final raw in filteredCatalog)
              _PatientCatalogCard(item: Map<String, dynamic>.from(raw), inCart: cart.containsKey(raw['id'].toString()), onAdd: () => addToCart(Map<String, dynamic>.from(raw))),
          ]),
        ])),
        SizedBox(height: 14),
        if (pharmacyRequests.isNotEmpty) CxSurface(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CxSectionHeader(title: 'My pharmacy requests', subtitle: 'Track requests sent to the hospital pharmacy.'),
          SizedBox(height: 10),
          ...pharmacyRequests.take(10).map((x) => _PharmacyRequestRow(request: Map<String, dynamic>.from(x))),
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
    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.medication_rounded, 'Medicines'),
      (Icons.calendar_month_rounded, 'Appointments'),
      (Icons.folder_copy_rounded, 'Records'),
      (Icons.local_pharmacy_rounded, 'Pharmacy'),
    ];
    return Container(
      width: 252,
      decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF111A30), Color(0xFF0E2530)])),
      child: Column(children: [
        Padding(padding: EdgeInsets.fromLTRB(18, 20, 18, 14), child: Row(children: [
          _PortalBrand(), SizedBox(width: 11), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Clinexa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -.7)), Text('PERSONAL HEALTH', style: TextStyle(color: Color(0xFF83A3AD), fontSize: 8.2, fontWeight: FontWeight.w800, letterSpacing: 1.05))]),
        ])),
        Container(height: 1, color: Colors.white10),
        Expanded(child: ListView.builder(
          padding: EdgeInsets.all(11),
          itemCount: items.length,
          itemBuilder: (_, i) => Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Material(color: index == i ? Colors.white.withValues(alpha: .095) : Colors.transparent, borderRadius: BorderRadius.circular(15), child: InkWell(borderRadius: BorderRadius.circular(15), onTap: () => onSelected(i), child: Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11), child: Row(children: [Icon(items[i].$1, color: index == i ? Color(0xFF6FE0D6) : Color(0xFF92A4B3), size: 20), SizedBox(width: 11), Text(items[i].$2, style: TextStyle(color: index == i ? Colors.white : Color(0xFFB6C3CE), fontWeight: index == i ? FontWeight.w800 : FontWeight.w600, fontSize: 11.8))])))),
          ),
        )),
        Padding(padding: EdgeInsets.all(12), child: OutlinedButton.icon(style: OutlinedButton.styleFrom(foregroundColor: Color(0xFFD7E0E6), side: BorderSide(color: Color(0xFF344253))), onPressed: onLogout, icon: Icon(Icons.logout_rounded), label: Text('Sign out'))),
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
      padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 22, vertical: 10),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface.withValues(alpha: .94), border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
      child: Row(children: [
        if (mobile) ...[_PortalBrand(), SizedBox(width: 9), Text('Clinexa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))],
        if (!mobile) Text('My health workspace', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 11.5)),
        Spacer(),
        IconButton(tooltip: 'Notifications', icon: Icon(Icons.notifications_none_rounded), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text('Notifications')), body: SafeArea(child: NotificationsPage()))))),
        if (cartCount > 0) Badge(label: Text('$cartCount'), child: IconButton(onPressed: onCart, icon: Icon(Icons.shopping_bag_outlined), tooltip: 'Pharmacy request bag')),
        PopupMenuButton<String>(
          onSelected: (v) { if (v == 'privacy') Navigator.push(context, MaterialPageRoute(builder: (_) => PrivacyPage())); if (v == 'logout') onLogout(); if (v == 'account') Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text('Appearance & account')), body: SafeArea(child: AccountPage())))); },
          itemBuilder: (_) => [PopupMenuItem(value: 'privacy', child: Text('Privacy & sharing')), PopupMenuItem(value: 'account', child: Text('Appearance & account')), PopupMenuItem(value: 'logout', child: Text('Sign out'))],
          child: CircleAvatar(radius: 16, backgroundColor: ClinexaTheme.navy, child: Text((Api.currentUser?['full_name']?.toString().isNotEmpty == true ? Api.currentUser!['full_name'].toString()[0] : 'P').toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11))),
        ),
      ]),
    );
  }
}

class _PortalBrand extends StatelessWidget {
  const _PortalBrand();
  @override
  Widget build(BuildContext context) => Container(width: 38, height: 38, decoration: BoxDecoration(gradient: ClinexaTheme.accentGradient, borderRadius: BorderRadius.circular(13)), child: Icon(Icons.add_rounded, color: Colors.white, size: 26));
}

class _PatientDock extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelected;
  const _PatientDock({required this.index, required this.onSelected});
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded, 'Home'),
      (Icons.medication_rounded, 'Meds'),
      (Icons.calendar_month_rounded, 'Visits'),
      (Icons.folder_copy_rounded, 'Records'),
      (Icons.local_pharmacy_rounded, 'Pharmacy'),
    ];
    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(10, 0, 10, 8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(color: Color(0xFF121B2E), borderRadius: BorderRadius.circular(22), boxShadow: [BoxShadow(color: Color(0x3510182B), blurRadius: 26, offset: Offset(0, 10))]),
        child: Row(children: [
          for (var i = 0; i < items.length; i++) Expanded(child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 190),
              padding: EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              decoration: BoxDecoration(color: index == i ? Colors.white.withValues(alpha: .11) : Colors.transparent, borderRadius: BorderRadius.circular(16)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(items[i].$1, size: 20, color: index == i ? Color(0xFF73E3D9) : Color(0xFF8E9AAA)), SizedBox(height: 3), Text(items[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: index == i ? Colors.white : Color(0xFF95A1B0), fontSize: 8.5, fontWeight: index == i ? FontWeight.w800 : FontWeight.w600))]),
            ),
          )),
        ]),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  const _ActivityRow({required this.icon, required this.title, required this.subtitle, required this.tone});
  @override
  Widget build(BuildContext context) => Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(11), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)), child: Row(children: [Container(width: 38, height: 38, decoration: BoxDecoration(color: tone.withAlpha(16), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: tone, size: 18)), SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5))]))]));
}

class _PatientMedicineCard extends StatelessWidget {
  final Map<String, dynamic> med;
  const _PatientMedicineCard({required this.med});
  @override
  Widget build(BuildContext context) {
    final active = med['status'] == 'active';
    return Container(padding: EdgeInsets.all(13), decoration: BoxDecoration(color: active ? Theme.of(context).colorScheme.surfaceContainerLow : Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(18), border: Border.all(color: active ? Color(0xFFCFEDE8) : Theme.of(context).colorScheme.outlineVariant)), child: Row(children: [
      CxMedicineVisual(imageKey: 'capsule'),
      SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(med['medication_name']?.toString() ?? 'Medicine', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        SizedBox(height: 3),
        Text([med['strength'], med['form'], med['frequency']].where((x) => x != null && x.toString().isNotEmpty).join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5)),
        SizedBox(height: 7),
        Wrap(spacing: 6, runSpacing: 6, children: [CxStatusChip(label: med['status']?.toString() ?? 'active', color: active ? ClinexaTheme.success : Theme.of(context).colorScheme.onSurfaceVariant), if (med['verified'] == true) CxStatusChip(label: 'verified', color: ClinexaTheme.primary, icon: Icons.verified_rounded)]),
      ])),
    ]));
  }
}

class _ReminderRow extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final Future<void> Function(Map<String, dynamic>, String) onLog;
  const _ReminderRow({required this.schedule, required this.onLog});
  @override
  Widget build(BuildContext context) => Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(11), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: Color(0xFFCFEAE6))), child: Row(children: [
    Icon(Icons.alarm_rounded, color: ClinexaTheme.primary), SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(schedule['medication_name']?.toString() ?? 'Medicine', style: TextStyle(fontWeight: FontWeight.w800)), Text('${schedule['dose_label'] ?? ''} • ${schedule['times_csv'] ?? ''}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5))])),
    IconButton(tooltip: 'Taken', onPressed: () => onLog(schedule, 'taken'), icon: Icon(Icons.check_circle_outline_rounded, color: ClinexaTheme.success)),
    IconButton(tooltip: 'Skipped', onPressed: () => onLog(schedule, 'skipped'), icon: Icon(Icons.remove_circle_outline_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: eligible ? Color(0xFFCFEAE6) : Theme.of(context).colorScheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CxMedicineVisual(imageKey: item['image_key']?.toString() ?? 'capsule'), Spacer(), CxStatusChip(label: item['category']?.toString() ?? 'Formulary', color: Color(0xFF4567C6))]),
        SizedBox(height: 12),
        Text(item['display_name']?.toString() ?? 'Medicine', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
        SizedBox(height: 3),
        Text([item['strength'], item['form']].where((x) => x != null && x.toString().isNotEmpty).join(' • '), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5)),
        SizedBox(height: 8),
        Text(item['description']?.toString() ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5, height: 1.4)),
        SizedBox(height: 8),
        if (eligible) CxStatusChip(label: 'Matches your verified medicine', color: ClinexaTheme.success, icon: Icons.verified_rounded) else CxStatusChip(label: 'Verified medicine required', color: Theme.of(context).colorScheme.onSurfaceVariant, icon: Icons.lock_outline_rounded),
        SizedBox(height: 9),
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
    final items = List<dynamic>.from((request['items'] as List?) ?? []);
    final status = request['status']?.toString() ?? 'submitted';
    final tone = status == 'fulfilled' ? ClinexaTheme.success : status == 'declined' ? ClinexaTheme.emergency : status == 'ready' ? Color(0xFF4567C6) : ClinexaTheme.warning;
    return Container(margin: EdgeInsets.only(bottom: 8), padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)), child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: tone.withAlpha(16), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.local_pharmacy_outlined, color: tone, size: 19)),
      SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(items.map((x) => x['display_name']).take(2).join(', '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)), Text('${items.length} item${items.length == 1 ? '' : 's'} • ${request['created_at'] ?? ''}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5))])),
      CxStatusChip(label: status, color: tone),
    ]));
  }
}

class _PatientNote extends StatelessWidget {
  final IconData icon;
  final String text;
  const _PatientNote({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(15), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 18, color: ClinexaTheme.primary), SizedBox(width: 9), Expanded(child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10.5, height: 1.45)))]));
}

class _CartEntry {
  final Map<String, dynamic> item;
  int quantity;
  _CartEntry({required this.item, required this.quantity});
}
