import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';
import '../../core/widgets/clinexa_ui.dart';
import '../../core/theme/theme.dart';

class AdvancedHubPage extends StatefulWidget {
  const AdvancedHubPage({super.key});
  @override State<AdvancedHubPage> createState()=>_AdvancedHubPageState();
}

class _AdvancedHubPageState extends State<AdvancedHubPage>{
  Map<String,dynamic>? analytics;
  List<dynamic> beds=[],labOrders=[],tele=[],shifts=[];
  bool loading=true;String? error;
  @override void initState(){super.initState();load();}
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    final errors = <String>[];
    Future<void> get(String permission, String path, void Function(dynamic) apply) async {
      if (!Api.can(permission)) return;
      try { final r = await Api.dio.get('/api/v1/advanced/$path'); if (mounted) apply(r.data); }
      catch(e) { errors.add(Api.errorMessage(e)); }
    }
    await Future.wait([
      get('admin.dashboard', 'analytics/overview', (v) => analytics = Map<String,dynamic>.from(v)),
      get('admissions.read', 'bed-board', (v) => beds = List<dynamic>.from(v)),
      get('lab.orders.read', 'lab-orders', (v) => labOrders = List<dynamic>.from(v)),
      get('appointments.read', 'teleconsultations', (v) => tele = List<dynamic>.from(v)),
      get('users.manage', 'staff/shifts', (v) => shifts = List<dynamic>.from(v)),
    ]);
    if (mounted) setState(() { loading = false; error = errors.isEmpty ? null : errors.toSet().join('\n'); });
  }

  Future<void> createLabOrder() async{
    final ps=List<dynamic>.from((await Api.dio.get('/api/v1/patients')).data as List);
    final ds=Api.can('doctors.read') ? List<dynamic>.from((await Api.dio.get('/api/v1/doctors')).data as List) : <dynamic>[];
    if(ps.isEmpty){if(mounted)showMessage(context,'Create a patient first.');return;}
    String patient=ps.first['id'].toString();String? doctor=ds.isEmpty?null:ds.first['id'].toString();final test=TextEditingController();String priority='routine';
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(title:const Text('Create lab order'),content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<String>(isExpanded: true, initialValue:patient,decoration:const InputDecoration(labelText:'Patient'),items:ps.map((p)=>DropdownMenuItem(value:p['id'].toString(),child:Text(p['full_name'].toString()))).toList(),onChanged:(v)=>setLocal(()=>patient=v!)),const SizedBox(height:10),
      if(ds.isNotEmpty)DropdownButtonFormField<String>(isExpanded: true, initialValue:doctor,decoration:const InputDecoration(labelText:'Ordering doctor'),items:ds.map((d)=>DropdownMenuItem(value:d['id'].toString(),child:Text(d['full_name'].toString()))).toList(),onChanged:(v)=>setLocal(()=>doctor=v)),if(ds.isNotEmpty)const SizedBox(height:10),
      TextField(controller:test,decoration:const InputDecoration(labelText:'Test name')),const SizedBox(height:10),DropdownButtonFormField<String>(isExpanded: true, initialValue:priority,decoration:const InputDecoration(labelText:'Priority'),items:const [DropdownMenuItem(value:'routine',child:Text('Routine')),DropdownMenuItem(value:'urgent',child:Text('Urgent'))],onChanged:(v)=>setLocal(()=>priority=v!)),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Create'))])));
    if(ok==true&&test.text.trim().isNotEmpty){await Api.dio.post('/api/v1/advanced/lab-orders',data:{'patient_id':patient,'doctor_id':doctor,'test_name':test.text.trim(),'priority':priority});await load();}
  }

  Future<void> createTele() async{
    final a=List<dynamic>.from((await Api.dio.get('/api/v1/appointments')).data as List);if(a.isEmpty){if(mounted)showMessage(context,'No appointments are available.');return;}
    String appt=a.first['id'].toString();bool consent=false;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(title:const Text('Create teleconsultation room'),content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(isExpanded: true, initialValue:appt,decoration:const InputDecoration(labelText:'Appointment'),items:a.take(100).map((x)=>DropdownMenuItem(value:x['id'].toString(),child:Text('${x['start_at']} • ${x['reason']??'Appointment'}'))).toList(),onChanged:(v)=>setLocal(()=>appt=v!)),CheckboxListTile(contentPadding:EdgeInsets.zero,value:consent,title:const Text('Consent recorded'),onChanged:(v)=>setLocal(()=>consent=v??false))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Create record'))])));
    if(ok==true){await Api.dio.post('/api/v1/advanced/teleconsultations',data:{'appointment_id':appt,'consent_recorded':consent});await load();}
  }

  Future<void> updateLab(String id,String status) async{await Api.dio.patch('/api/v1/advanced/lab-orders/$id/status',data:{'status':status});await load();}
  Future<void> updateTele(String id,String status) async{await Api.dio.patch('/api/v1/advanced/teleconsultations/$id',data:{'status':status});await load();}

  @override
  Widget build(BuildContext context) {
    final a = analytics ?? <String, dynamic>{};
    final occ = a['bed_occupancy'] is Map ? Map<String, dynamic>.from(a['bed_occupancy'] as Map) : <String, dynamic>{};
    final width = MediaQuery.sizeOf(context).width;
    final pad = width < 700 ? 16.0 : 28.0;

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad, 26, pad, 42),
        children: [
          CxPageHeader(
            icon: Icons.monitor_heart_rounded,
            eyebrow: 'Hospital command centre',
            title: 'Care operations',
            subtitle: 'See clinical flow, capacity, laboratory work and virtual care without jumping between disconnected dashboards.',
            actions: [OutlinedButton.icon(onPressed: load, icon: const Icon(Icons.refresh_rounded), label: const Text('Refresh'))],
          ),
          if (error != null) ...[const SizedBox(height: 14), CxErrorBanner(message: error!, onRetry: load)],
          if (loading) ...[const SizedBox(height: 14), const LinearProgressIndicator(minHeight: 2)],
          const SizedBox(height: 18),
          if (Api.can('admin.dashboard')) CxAdaptiveGrid(
            minItemWidth: 205,
            children: [
              CxMetricCard(label: 'Patients', value: '${a['patients'] ?? '—'}', caption: 'Patient records in scope', icon: Icons.people_outline_rounded),
              CxMetricCard(label: '7-day visits', value: '${a['appointments_last_7_days'] ?? '—'}', caption: 'Recent appointment activity', icon: Icons.event_available_outlined, tone: ClinexaTheme.accent),
              CxMetricCard(label: 'Bed occupancy', value: '${occ['occupied'] ?? 0}/${occ['total'] ?? 0}', caption: 'Occupied / total beds', icon: Icons.bed_outlined, tone: ClinexaTheme.emergency),
              CxMetricCard(label: 'Pending labs', value: '${a['pending_lab_orders'] ?? '—'}', caption: 'Orders awaiting completion', icon: Icons.science_outlined, tone: ClinexaTheme.warning),
              CxMetricCard(label: 'Low stock', value: '${a['low_stock_items'] ?? '—'}', caption: 'Pharmacy reorder signals', icon: Icons.inventory_2_outlined, tone: ClinexaTheme.warning),
              CxMetricCard(label: 'Admissions', value: '${a['active_admissions'] ?? '—'}', caption: 'Active inpatient admissions', icon: Icons.local_hospital_outlined, tone: ClinexaTheme.primary),
              CxMetricCard(label: 'Doctors', value: '${a['active_doctors'] ?? '—'}', caption: 'Active clinical staff', icon: Icons.medical_services_outlined, tone: ClinexaTheme.success),
              CxMetricCard(label: 'Outstanding', value: '₹${a['unpaid_invoice_total'] ?? 0}', caption: 'Open invoice value', icon: Icons.receipt_long_outlined, tone: ClinexaTheme.accent),
            ],
          ),
          const SizedBox(height: 18),
          if (Api.can('lab.orders.read')) CxSurface(
            elevated: true,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CxSectionHeader(
                title: 'Laboratory workflow',
                subtitle: 'Order, collect, process and close tests from a single queue.',
                action: FilledButton.icon(onPressed: Api.can('lab.orders.manage') ? createLabOrder : null, icon: const Icon(Icons.add_rounded), label: const Text('Order lab')),
              ),
              const SizedBox(height: 12),
              if (labOrders.isEmpty) const CxEmptyState(icon: Icons.science_outlined, title: 'No lab orders', message: 'New laboratory orders will appear here.'),
              ...labOrders.take(20).map((x) => _OpsRow(
                    icon: Icons.science_outlined,
                    tone: ClinexaTheme.accent,
                    title: x['test_name']?.toString() ?? 'Lab order',
                    subtitle: '${x['priority'] ?? 'routine'} • ${x['ordered_at'] ?? ''}',
                    status: x['status']?.toString() ?? 'ordered',
                    menu: PopupMenuButton<String>(
                      onSelected: (v) => updateLab(x['id'].toString(), v),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'collected', child: Text('Collected')),
                        PopupMenuItem(value: 'processing', child: Text('Processing')),
                        PopupMenuItem(value: 'completed', child: Text('Completed')),
                        PopupMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                    ),
                  )),
            ]),
          ),
          const SizedBox(height: 16),
          if (Api.can('appointments.read')) CxSurface(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CxSectionHeader(
                title: 'Virtual visit records',
                subtitle: 'Track consent and visit status. Video calling is not included.',
                action: OutlinedButton.icon(onPressed: Api.can('appointments.modify') ? createTele : null, icon: const Icon(Icons.video_call_outlined), label: const Text('Create record')),
              ),
              const SizedBox(height: 12),
              if (tele.isEmpty) const CxEmptyState(icon: Icons.video_camera_front_outlined, title: 'No virtual visit records', message: 'Create a room from an eligible appointment.'),
              ...tele.take(20).map((x) => _OpsRow(
                    icon: Icons.video_camera_front_outlined,
                    tone: ClinexaTheme.primary,
                    title: x['room_code']?.toString() ?? 'Teleconsultation room',
                    subtitle: 'Consent ${x['consent_recorded'] == true ? 'recorded' : 'not recorded'}',
                    status: x['status']?.toString() ?? 'created',
                    menu: PopupMenuButton<String>(
                      onSelected: (v) => updateTele(x['id'].toString(), v),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'live', child: Text('Start')),
                        PopupMenuItem(value: 'ended', child: Text('End')),
                        PopupMenuItem(value: 'cancelled', child: Text('Cancel')),
                      ],
                    ),
                  )),
            ]),
          ),
          const SizedBox(height: 16),
          if (Api.can('admissions.read')) CxSurface(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CxSectionHeader(title: 'Live bed board', subtitle: 'Compact ward capacity view with patient occupancy context.'),
              const SizedBox(height: 12),
              if (beds.isEmpty) const CxEmptyState(icon: Icons.bed_outlined, title: 'No bed data', message: 'Configured ward beds will appear here.'),
              if (beds.isNotEmpty)
                CxAdaptiveGrid(
                  minItemWidth: 170,
                  maxColumns: 5,
                  children: beds.map((raw) {
                    final b = Map<String, dynamic>.from(raw as Map);
                    final occupied = b['status'] == 'occupied';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: occupied ? ClinexaTheme.rose : ClinexaTheme.mint,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: occupied ? ClinexaTheme.emergency.withValues(alpha: .14) : ClinexaTheme.primary.withValues(alpha: .12)),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Icon(Icons.bed_rounded, size: 18, color: occupied ? ClinexaTheme.emergency : ClinexaTheme.primary), const Spacer(), CxStatusChip(label: b['status']?.toString() ?? 'available', color: occupied ? ClinexaTheme.emergency : ClinexaTheme.success)]),
                        const SizedBox(height: 12),
                        Text('${b['ward'] ?? 'Ward'} • ${b['room'] ?? 'Room'}', style: const TextStyle(fontSize: 10.2, color: ClinexaTheme.muted)),
                        const SizedBox(height: 3),
                        Text(b['bed']?.toString() ?? 'Bed', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(b['patient_name']?.toString() ?? (occupied ? 'Patient assigned' : 'Ready for assignment'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, height: 1.35)),
                      ]),
                    );
                  }).toList(),
                ),
            ]),
          ),
          const SizedBox(height: 16),
          if (Api.can('users.manage')) CxSurface(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const CxSectionHeader(title: 'Staff shifts', subtitle: 'Current staffing windows and operational coverage.'),
              const SizedBox(height: 12),
              if (shifts.isEmpty) const CxEmptyState(icon: Icons.badge_outlined, title: 'No shifts scheduled', message: 'Staff shift records will appear here.'),
              ...shifts.take(20).map((x) => _OpsRow(
                    icon: Icons.badge_outlined,
                    tone: ClinexaTheme.accent,
                    title: x['shift_type']?.toString() ?? 'Shift',
                    subtitle: '${x['starts_at'] ?? ''} → ${x['ends_at'] ?? ''}',
                    status: x['status']?.toString() ?? 'scheduled',
                  )),
            ]),
          ),
        ],
      ),
    );
  }

}
class _OpsRow extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final String status;
  final Widget? menu;
  const _OpsRow({required this.icon, required this.tone, required this.title, required this.subtitle, required this.status, this.menu});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: ClinexaTheme.surfaceSoft, borderRadius: BorderRadius.circular(16), border: Border.all(color: ClinexaTheme.line)),
        child: Row(children: [
          Container(width: 39, height: 39, decoration: BoxDecoration(color: tone.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: tone, size: 19)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.8)), const SizedBox(height: 2), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: ClinexaTheme.muted, fontSize: 9.8, height: 1.35))])),
          const SizedBox(width: 8),
          CxStatusChip(label: status, color: tone),
          if (menu != null) ...[const SizedBox(width: 3), menu!],
        ]),
      );
}
