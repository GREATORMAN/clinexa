import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class AdvancedHubPage extends StatefulWidget {
  const AdvancedHubPage({super.key});
  @override State<AdvancedHubPage> createState()=>_AdvancedHubPageState();
}

class _AdvancedHubPageState extends State<AdvancedHubPage>{
  Map<String,dynamic>? analytics;
  List<dynamic> beds=[],labOrders=[],tele=[],shifts=[];
  bool loading=true;String? error;
  @override void initState(){super.initState();load();}
  Future<void> load() async{
    if(mounted)setState((){loading=true;error=null;});
    try{final r=await Future.wait([
      Api.dio.get('/api/v1/advanced/analytics/overview'),Api.dio.get('/api/v1/advanced/bed-board'),Api.dio.get('/api/v1/advanced/lab-orders'),Api.dio.get('/api/v1/advanced/teleconsultations'),Api.dio.get('/api/v1/advanced/staff/shifts'),
    ]);if(mounted)setState((){analytics=Map<String,dynamic>.from(r[0].data);beds=List<dynamic>.from(r[1].data as List);labOrders=List<dynamic>.from(r[2].data as List);tele=List<dynamic>.from(r[3].data as List);shifts=List<dynamic>.from(r[4].data as List);});}
    catch(e){if(mounted)setState(()=>error=Api.errorMessage(e));}finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> createLabOrder() async{
    final ps=List<dynamic>.from((await Api.dio.get('/api/v1/patients')).data as List);
    final ds=List<dynamic>.from((await Api.dio.get('/api/v1/doctors')).data as List);
    if(ps.isEmpty){if(mounted)showMessage(context,'Create a patient first.');return;}
    String patient=ps.first['id'].toString();String? doctor=ds.isEmpty?null:ds.first['id'].toString();final test=TextEditingController();String priority='routine';
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(title:const Text('Create lab order'),content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<String>(value:patient,decoration:const InputDecoration(labelText:'Patient'),items:ps.map((p)=>DropdownMenuItem(value:p['id'].toString(),child:Text(p['full_name'].toString()))).toList(),onChanged:(v)=>setLocal(()=>patient=v!)),const SizedBox(height:10),
      if(ds.isNotEmpty)DropdownButtonFormField<String>(value:doctor,decoration:const InputDecoration(labelText:'Ordering doctor'),items:ds.map((d)=>DropdownMenuItem(value:d['id'].toString(),child:Text(d['full_name'].toString()))).toList(),onChanged:(v)=>setLocal(()=>doctor=v)),if(ds.isNotEmpty)const SizedBox(height:10),
      TextField(controller:test,decoration:const InputDecoration(labelText:'Test name')),const SizedBox(height:10),DropdownButtonFormField<String>(value:priority,decoration:const InputDecoration(labelText:'Priority'),items:const [DropdownMenuItem(value:'routine',child:Text('Routine')),DropdownMenuItem(value:'urgent',child:Text('Urgent'))],onChanged:(v)=>setLocal(()=>priority=v!)),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Create'))])));
    if(ok==true&&test.text.trim().isNotEmpty){await Api.dio.post('/api/v1/advanced/lab-orders',data:{'patient_id':patient,'doctor_id':doctor,'test_name':test.text.trim(),'priority':priority});await load();}
  }

  Future<void> createTele() async{
    final a=List<dynamic>.from((await Api.dio.get('/api/v1/appointments')).data as List);if(a.isEmpty){if(mounted)showMessage(context,'No appointments are available.');return;}
    String appt=a.first['id'].toString();bool consent=false;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setLocal)=>AlertDialog(title:const Text('Create teleconsultation room'),content:SizedBox(width:460,child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(value:appt,decoration:const InputDecoration(labelText:'Appointment'),items:a.take(100).map((x)=>DropdownMenuItem(value:x['id'].toString(),child:Text('${x['start_at']} • ${x['reason']??'Appointment'}'))).toList(),onChanged:(v)=>setLocal(()=>appt=v!)),CheckboxListTile(contentPadding:EdgeInsets.zero,value:consent,title:const Text('Consent recorded'),onChanged:(v)=>setLocal(()=>consent=v??false))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Create room'))])));
    if(ok==true){await Api.dio.post('/api/v1/advanced/teleconsultations',data:{'appointment_id':appt,'consent_recorded':consent});await load();}
  }

  Future<void> updateLab(String id,String status) async{await Api.dio.patch('/api/v1/advanced/lab-orders/$id/status',data:{'status':status});await load();}
  Future<void> updateTele(String id,String status) async{await Api.dio.patch('/api/v1/advanced/teleconsultations/$id',data:{'status':status});await load();}

  @override Widget build(BuildContext context){final a=analytics??{};final occ=a['bed_occupancy'] as Map? ??{};return SectionPage(title:'Advanced Operations',subtitle:'Labs, teleconsultation, bed command center, staffing and hospital analytics',actions:[IconButton(onPressed:load,icon:const Icon(Icons.refresh_rounded))],child:ListView(padding:const EdgeInsets.all(18),children:[
    if(error!=null)ErrorCard(error!),if(loading)const LinearProgressIndicator(),const SizedBox(height:14),
    LayoutBuilder(builder:(ctx,c){final n=c.maxWidth>1000?4:c.maxWidth>560?2:1;final cards=[('Patients','${a['patients']??'—'}',Icons.people_outline),('7-day visits','${a['appointments_last_7_days']??'—'}',Icons.event_available_outlined),('Bed occupancy','${occ['occupied']??0}/${occ['total']??0}',Icons.bed_outlined),('Pending labs','${a['pending_lab_orders']??'—'}',Icons.science_outlined),('Low stock','${a['low_stock_items']??'—'}',Icons.inventory_2_outlined),('Admissions','${a['active_admissions']??'—'}',Icons.local_hospital_outlined),('Doctors','${a['active_doctors']??'—'}',Icons.medical_services_outlined),('Outstanding','₹${a['unpaid_invoice_total']??0}',Icons.receipt_long_outlined)];return GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:cards.length,gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:n,crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:n==1?3.0:2.1),itemBuilder:(_,i)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[CircleAvatar(child:Icon(cards[i].$3)),const SizedBox(width:10),Expanded(child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(cards[i].$1,style:const TextStyle(fontSize:11,color:Color(0xFF718096))),Text(cards[i].$2,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w800))]))]))));}),
    const SizedBox(height:16),_Header(title:'Lab workflow',action:FilledButton.icon(onPressed:createLabOrder,icon:const Icon(Icons.add),label:const Text('Order lab'))),const SizedBox(height:8),Card(child:Column(children:[if(labOrders.isEmpty)const Padding(padding:EdgeInsets.all(18),child:Text('No lab orders.')),...labOrders.take(20).map((x)=>ListTile(title:Text(x['test_name']?.toString()??'Lab order'),subtitle:Text('${x['priority']??''} • ${x['status']??''} • ${x['ordered_at']??''}'),trailing:PopupMenuButton<String>(onSelected:(v)=>updateLab(x['id'].toString(),v),itemBuilder:(_)=>const [PopupMenuItem(value:'collected',child:Text('Collected')),PopupMenuItem(value:'processing',child:Text('Processing')),PopupMenuItem(value:'completed',child:Text('Completed')),PopupMenuItem(value:'cancelled',child:Text('Cancelled'))])))])),
    const SizedBox(height:16),_Header(title:'Teleconsultation rooms',action:FilledButton.icon(onPressed:createTele,icon:const Icon(Icons.video_call_outlined),label:const Text('Create room'))),const SizedBox(height:8),Card(child:Column(children:[if(tele.isEmpty)const Padding(padding:EdgeInsets.all(18),child:Text('No teleconsultation rooms.')),...tele.take(20).map((x)=>ListTile(leading:const Icon(Icons.video_camera_front_outlined),title:Text(x['room_code']?.toString()??'Room'),subtitle:Text('${x['status']??''} • consent ${x['consent_recorded']==true?'recorded':'not recorded'}'),trailing:PopupMenuButton<String>(onSelected:(v)=>updateTele(x['id'].toString(),v),itemBuilder:(_)=>const [PopupMenuItem(value:'live',child:Text('Start')),PopupMenuItem(value:'ended',child:Text('End')),PopupMenuItem(value:'cancelled',child:Text('Cancel'))])))])),
    const SizedBox(height:16),const _Header(title:'Visual bed board'),const SizedBox(height:8),Wrap(spacing:8,runSpacing:8,children:beds.map((b)=>Container(width:170,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:b['status']=='occupied'?const Color(0xFFFFF1F2):const Color(0xFFECFDF5),borderRadius:BorderRadius.circular(14),border:Border.all(color:const Color(0xFFE2E8F0))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${b['ward']} • ${b['room']}',style:const TextStyle(fontSize:10.5,color:Color(0xFF64748B))),const SizedBox(height:4),Text(b['bed']?.toString()??'Bed',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),Text(b['patient_name']?.toString()??b['status']?.toString()??'available',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11))]))).toList()),
    const SizedBox(height:16),const _Header(title:'Staff shifts'),const SizedBox(height:8),Card(child:Column(children:[if(shifts.isEmpty)const Padding(padding:EdgeInsets.all(18),child:Text('No staff shifts have been scheduled yet.')),...shifts.take(20).map((x)=>ListTile(leading:const Icon(Icons.badge_outlined),title:Text(x['shift_type']?.toString()??'Shift'),subtitle:Text('${x['starts_at']??''} → ${x['ends_at']??''} • ${x['status']??''}')))])),
  ]));}
}
class _Header extends StatelessWidget{final String title;final Widget? action;const _Header({required this.title,this.action});@override Widget build(BuildContext context)=>Row(children:[Expanded(child:Text(title,style:const TextStyle(fontSize:16,fontWeight:FontWeight.w800))),if(action!=null)action!]);}
