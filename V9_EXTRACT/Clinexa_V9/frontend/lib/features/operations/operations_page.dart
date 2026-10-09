import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class OperationsPage extends StatefulWidget { OperationsPage({super.key}); @override State<OperationsPage> createState() => _OperationsPageState(); }
class _OperationsPageState extends State<OperationsPage> {
  List<dynamic> patients=[]; List<dynamic> pharmacy=[]; List<dynamic> invoices=[]; List<dynamic> beds=[]; List<dynamic> admissions=[]; List<dynamic> wards=[]; List<dynamic> rooms=[]; String? error;
  @override void initState(){super.initState();load();}
  Future<void> load() async {
    final errors = <String>[];
    Future<void> get(String permission, String path, void Function(List<dynamic>) apply) async {
      if (!Api.can(permission)) return;
      try { final r = await Api.dio.get('/api/v1/$path'); if (mounted) apply(List<dynamic>.from(r.data)); }
      catch (e) { errors.add(Api.errorMessage(e)); }
    }
    await Future.wait([
      get('patient.demographics.read', 'patients', (v) => patients = v),
      get('pharmacy.read', 'pharmacy/items', (v) => pharmacy = v),
      get('billing.manage', 'billing/invoices', (v) => invoices = v),
      get('admissions.read', 'beds', (v) => beds = v),
      get('admissions.read', 'admissions', (v) => admissions = v),
      get('admissions.read', 'wards', (v) => wards = v),
      get('admissions.read', 'rooms', (v) => rooms = v),
    ]);
    if (mounted) setState(() => error = errors.isEmpty ? null : errors.toSet().join('\n'));
  }

  Future<void> addPharmacyItem() async {
    final name=TextEditingController(); final form=TextEditingController(); final strength=TextEditingController(); final reorder=TextEditingController(text:'10');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('Add pharmacy item'),content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:InputDecoration(labelText:'Medication name *')),SizedBox(height:8),TextField(controller:form,decoration:InputDecoration(labelText:'Form')),SizedBox(height:8),TextField(controller:strength,decoration:InputDecoration(labelText:'Strength')),SizedBox(height:8),TextField(controller:reorder,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Low-stock level'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Add'))]));
    if(ok!=true||name.text.trim().isEmpty)return; try{await Api.dio.post('/api/v1/pharmacy/items',data:{'name':name.text.trim(),'form':empty(form.text),'strength':empty(strength.text),'reorder_level':int.tryParse(reorder.text)??10});if(mounted)showMessage(context,'Pharmacy item added.');await load();}catch(e){if(mounted)showMessage(context,Api.errorMessage(e));}
  }
  String? empty(String x)=>x.trim().isEmpty?null:x.trim();

  Future<void> addBatch() async {
    if(pharmacy.isEmpty){showMessage(context,'Add a pharmacy item first.');return;} String itemId=pharmacy.first['id'].toString(); final batch=TextEditingController(); final qty=TextEditingController(text:'0');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(title:Text('Add inventory batch'),content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(isExpanded: true, initialValue:itemId,decoration:InputDecoration(labelText:'Item'),items:pharmacy.map((x)=>DropdownMenuItem(value:x['id'].toString(),child:Text(x['name'].toString()))).toList(),onChanged:(v)=>setLocal(()=>itemId=v??itemId)),SizedBox(height:8),TextField(controller:batch,decoration:InputDecoration(labelText:'Batch number *')),SizedBox(height:8),TextField(controller:qty,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Quantity'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Save'))])));
    if(ok!=true||batch.text.trim().isEmpty)return; try{await Api.dio.post('/api/v1/pharmacy/batches',data:{'pharmacy_item_id':itemId,'batch_number':batch.text.trim(),'quantity':int.tryParse(qty.text)??0});if(mounted)showMessage(context,'Inventory batch added.');await load();}catch(e){if(mounted)showMessage(context,Api.errorMessage(e));}
  }

  Future<void> createInvoice() async {
    if(patients.isEmpty){showMessage(context,'Add a patient first.');return;} String patientId=patients.first['id'].toString(); final desc=TextEditingController(); final amount=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(title:Text('Create invoice'),content:SizedBox(width:480,child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(isExpanded: true, initialValue:patientId,decoration:InputDecoration(labelText:'Patient'),items:patients.map((p)=>DropdownMenuItem(value:p['id'].toString(),child:Text(p['full_name'].toString()))).toList(),onChanged:(v)=>setLocal(()=>patientId=v??patientId)),SizedBox(height:8),TextField(controller:desc,decoration:InputDecoration(labelText:'Description *')),SizedBox(height:8),TextField(controller:amount,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Amount *'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Create'))])));
    if(ok!=true||desc.text.trim().isEmpty||double.tryParse(amount.text)==null)return; try{await Api.dio.post('/api/v1/billing/invoices',data:{'patient_id':patientId,'description':desc.text.trim(),'total_amount':double.parse(amount.text)});if(mounted)showMessage(context,'Invoice created.');await load();}catch(e){if(mounted)showMessage(context,Api.errorMessage(e));}
  }

  Future<void> recordPayment(Map<String,dynamic> inv) async {
    final amount=TextEditingController(text:inv['total_amount']?.toString()??''); final ref=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('Record payment'),content:SizedBox(width:440,child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:amount,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:'Amount')),SizedBox(height:8),TextField(controller:ref,decoration:InputDecoration(labelText:'Reference / receipt note'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Record'))]));
    if(ok!=true||double.tryParse(amount.text)==null)return; try{await Api.dio.post('/api/v1/billing/invoices/${inv['id']}/payments',data:{'amount':double.parse(amount.text),'provider':'manual','reference':empty(ref.text)});if(mounted)showMessage(context,'Payment recorded.');await load();}catch(e){if(mounted)showMessage(context,Api.errorMessage(e));}
  }

  Future<void> addWardRoomBed() async {
    String mode='ward'; final name=TextEditingController(); String? parentId;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(title:Text('Add ward / room / bed'),content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(isExpanded: true, initialValue:mode,decoration:InputDecoration(labelText:'Create'),items:[DropdownMenuItem(value:'ward',child:Text('Ward')),DropdownMenuItem(value:'room',child:Text('Room')),DropdownMenuItem(value:'bed',child:Text('Bed'))],onChanged:(v)=>setLocal((){mode=v??mode;parentId=null;})),SizedBox(height:8),if(mode=='room')DropdownButtonFormField<String>(isExpanded: true, initialValue:parentId,decoration:InputDecoration(labelText:'Ward'),items:wards.map((w)=>DropdownMenuItem(value:w['id'].toString(),child:Text(w['name'].toString()))).toList(),onChanged:(v)=>setLocal(()=>parentId=v)),if(mode=='bed')DropdownButtonFormField<String>(isExpanded: true, initialValue:parentId,decoration:InputDecoration(labelText:'Room'),items:rooms.map((r)=>DropdownMenuItem(value:r['id'].toString(),child:Text(r['name'].toString()))).toList(),onChanged:(v)=>setLocal(()=>parentId=v)),SizedBox(height:8),TextField(controller:name,decoration:InputDecoration(labelText:mode=='bed'?'Bed label *':'Name *'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Create'))])));
    if(ok!=true||name.text.trim().isEmpty)return; try{if(mode=='ward')await Api.dio.post('/api/v1/wards',data:{'name':name.text.trim()});if(mode=='room'){if(parentId==null){showMessage(context,'Choose a ward.');return;}await Api.dio.post('/api/v1/rooms',data:{'ward_id':parentId,'name':name.text.trim()});}if(mode=='bed'){if(parentId==null){showMessage(context,'Choose a room.');return;}await Api.dio.post('/api/v1/beds',data:{'room_id':parentId,'label':name.text.trim()});}if(mounted)showMessage(context,'$mode created.');await load();}catch(e){if(mounted)showMessage(context,Api.errorMessage(e));}
  }

  Future<void> admitPatient() async {
    if(patients.isEmpty){showMessage(context,'Add a patient first.');return;} final available=beds.where((b)=>b['status']=='available').toList(); String patientId=patients.first['id'].toString(); String? bedId=available.isNotEmpty?available.first['bed_id'].toString():null; final reason=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(title:Text('Admit patient'),content:SizedBox(width:500,child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(isExpanded: true, initialValue:patientId,decoration:InputDecoration(labelText:'Patient'),items:patients.map((p)=>DropdownMenuItem(value:p['id'].toString(),child:Text(p['full_name'].toString()))).toList(),onChanged:(v)=>setLocal(()=>patientId=v??patientId)),SizedBox(height:8),if(available.isNotEmpty)DropdownButtonFormField<String>(isExpanded: true, initialValue:bedId,decoration:InputDecoration(labelText:'Available bed'),items:available.map((b)=>DropdownMenuItem(value:b['bed_id'].toString(),child:Text('${b['ward']} / ${b['room']} / ${b['label']}'))).toList(),onChanged:(v)=>setLocal(()=>bedId=v)),SizedBox(height:8),TextField(controller:reason,maxLines:2,decoration:InputDecoration(labelText:'Reason'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Admit'))])));
    if(ok!=true)return; try{await Api.dio.post('/api/v1/admissions',data:{'patient_id':patientId,'bed_id':bedId,'reason':empty(reason.text)});if(mounted)showMessage(context,'Patient admitted.');await load();}catch(e){if(mounted)showMessage(context,Api.errorMessage(e));}
  }

  Future<void> discharge(Map<String,dynamic> a) async {try{await Api.dio.post('/api/v1/admissions/${a['id']}/discharge');if(mounted)showMessage(context,'Patient discharged; bed moved to cleaning.');await load();}catch(e){if(mounted)showMessage(context,Api.errorMessage(e));}}

  Future<void> readyBed(dynamic bed) async {
    try {
      await Api.dio.patch('/api/v1/beds/${bed['bed_id']}/status', data: {'status': 'available'});
      await load();
    } catch(e) { if (mounted) showMessage(context, Api.errorMessage(e)); }
  }

  @override Widget build(BuildContext context)=>DefaultTabController(length: [Api.can('pharmacy.read'), Api.can('billing.manage'), Api.can('admissions.read')].where((v) => v).length,child:SectionPage(title:'Hospital Operations',subtitle:'Pharmacy, billing, wards, beds and admissions',actions:[IconButton(onPressed:load,icon:Icon(Icons.refresh))],child:Column(children:[if(error!=null)Padding(padding:EdgeInsets.all(10),child:ErrorCard(error!)),TabBar(tabs:[if(Api.can('pharmacy.read')) Tab(text:'Pharmacy'),if(Api.can('billing.manage')) Tab(text:'Billing'),if(Api.can('admissions.read')) Tab(text:'Admissions')]),Expanded(child:TabBarView(children:[
    if(Api.can('pharmacy.read')) ListView(padding:EdgeInsets.all(14),children:[Wrap(alignment:WrapAlignment.end,spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:Api.can('pharmacy.manage')?addBatch:null,icon:Icon(Icons.inventory_2_outlined),label:Text('Add batch')),SizedBox(width:8),FilledButton.icon(onPressed:Api.can('pharmacy.manage')?addPharmacyItem:null,icon:Icon(Icons.add),label:Text('Item'))]),SizedBox(height:10),Card(child:Column(children:[for(final x in pharmacy)ListTile(leading:Icon((x['low_stock']??false)?Icons.warning_amber:Icons.medication_outlined),title:Text('${x['name']} ${x['strength']??''}'),subtitle:Text('Stock: ${x['quantity']??0} • Reorder at ${x['reorder_level']??0}${(x['low_stock']??false)?' • LOW STOCK':''}')),if(pharmacy.isEmpty)Padding(padding:EdgeInsets.all(24),child:Text('No pharmacy items.'))]))]),
    if(Api.can('billing.manage')) ListView(padding:EdgeInsets.all(14),children:[Align(alignment:Alignment.centerRight,child:FilledButton.icon(onPressed:createInvoice,icon:Icon(Icons.receipt_long_outlined),label:Text('Create invoice'))),SizedBox(height:10),Card(child:Column(children:[for(final raw in invoices)Builder(builder:(_){final x=Map<String,dynamic>.from(raw);return ListTile(title:Text(x['description']?.toString()??'Invoice'),subtitle:Text('Amount: ${x['total_amount']} • ${x['status']}'),trailing:x['status']=='paid'?Icon(Icons.check_circle_outline):TextButton(onPressed:()=>recordPayment(x),child:Text('Pay')));}),if(invoices.isEmpty)Padding(padding:EdgeInsets.all(24),child:Text('No invoices.'))]))]),
    if(Api.can('admissions.read')) ListView(padding:EdgeInsets.all(14),children:[Wrap(alignment:WrapAlignment.end,spacing:8,children:[OutlinedButton.icon(onPressed:Api.can('admissions.manage')?addWardRoomBed:null,icon:Icon(Icons.add_home_work_outlined),label:Text('Ward / room / bed')),FilledButton.icon(onPressed:Api.can('admissions.manage')?admitPatient:null,icon:Icon(Icons.local_hospital_outlined),label:Text('Admit'))]),SizedBox(height:10),Text('Beds',style:Theme.of(context).textTheme.titleMedium),SizedBox(height:6),Card(child:Column(children:[for(final b in beds)ListTile(leading:Icon(Icons.bed_outlined),title:Text('${b['ward']} / ${b['room']} / ${b['label']}'),trailing:b['status']=='cleaning' && Api.can('admissions.manage') ? TextButton(onPressed:()=>readyBed(b),child:Text('Mark ready')) : Text(b['status'].toString())),if(beds.isEmpty)Padding(padding:EdgeInsets.all(24),child:Text('No beds configured.'))])),SizedBox(height:14),Text('Admissions',style:Theme.of(context).textTheme.titleMedium),SizedBox(height:6),Card(child:Column(children:[for(final raw in admissions)Builder(builder:(_){final a=Map<String,dynamic>.from(raw);return ListTile(title:Text('Admission ${a['id'].toString().substring(0,6)}'),subtitle:Text('${a['reason']??''} • ${a['status']} • ${a['admitted_at']??''}'),trailing:a['status']=='admitted'?TextButton(onPressed:Api.can('admissions.manage')?()=>discharge(a):null,child:Text('Discharge')):null);}),if(admissions.isEmpty)Padding(padding:EdgeInsets.all(24),child:Text('No admissions.'))]))]),
  ]))])));
}

