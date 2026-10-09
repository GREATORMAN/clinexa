import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/network/api.dart';
import '../../core/widgets/section_page.dart';

class EmergencyPage extends StatefulWidget {
  EmergencyPage({super.key});
  @override State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  List<dynamic> patients=[];
  String? patientId;
  Map<String,dynamic>? bundle;
  bool loading=true;
  String? error;

  @override void initState(){ super.initState(); loadPatients(); }

  Future<void> loadPatients() async {
    try {
      final r=await Api.dio.get('/api/v1/patients'); patients=List<dynamic>.from(r.data as List);
      if(patients.isNotEmpty) patientId ??= patients.first['id'].toString();
      await load();
    } catch(e){ if(mounted)setState((){error=Api.errorMessage(e);loading=false;}); }
  }

  Future<void> load() async {
    if(patientId==null){if(mounted)setState(()=>loading=false);return;}
    if(mounted)setState((){loading=true;error=null;});
    try{final r=await Api.dio.get('/api/v1/advanced/emergency/profiles/$patientId');if(mounted)setState(()=>bundle=Map<String,dynamic>.from(r.data));}
    catch(e){if(mounted)setState(()=>error=Api.errorMessage(e));}
    finally{if(mounted)setState(()=>loading=false);}
  }

  Future<void> editProfile() async {
    final selected=patients.cast<Map>().firstWhere((p)=>p['id'].toString()==patientId,orElse:()=>{});
    final existing=bundle?['profile'] as Map?;
    final name=TextEditingController(text: existing?['public_name']?.toString() ?? selected['full_name']?.toString() ?? '');
    final blood=TextEditingController(text: existing?['blood_group']?.toString() ?? selected['blood_group']?.toString() ?? '');
    final allergies=TextEditingController(text: existing?['allergies']?.toString() ?? selected['allergies']?.toString() ?? '');
    final conditions=TextEditingController(text: existing?['critical_conditions']?.toString() ?? '');
    final notes=TextEditingController(text: existing?['emergency_notes']?.toString() ?? '');
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('Emergency profile'),content:SizedBox(width:480,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:InputDecoration(labelText:'Public emergency name')),SizedBox(height:10),
      TextField(controller:blood,decoration:InputDecoration(labelText:'Blood group')),SizedBox(height:10),
      TextField(controller:allergies,maxLines:2,decoration:InputDecoration(labelText:'Allergies')),SizedBox(height:10),
      TextField(controller:conditions,maxLines:2,decoration:InputDecoration(labelText:'Critical conditions / alerts')),SizedBox(height:10),
      TextField(controller:notes,maxLines:3,decoration:InputDecoration(labelText:'Emergency notes')),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Save'))]));
    if(ok==true){await Api.dio.put('/api/v1/advanced/emergency/profiles/$patientId',data:{'public_name':name.text.trim(),'blood_group':blood.text.trim(),'allergies':allergies.text.trim(),'critical_conditions':conditions.text.trim(),'emergency_notes':notes.text.trim(),'enabled':true});await load();}
  }

  Future<void> addContact() async {
    final name=TextEditingController(), relation=TextEditingController(), phone=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:Text('Trusted emergency contact'),content:SizedBox(width:430,child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextField(controller:name,decoration:InputDecoration(labelText:'Name')),SizedBox(height:10),TextField(controller:relation,decoration:InputDecoration(labelText:'Relation')),SizedBox(height:10),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:InputDecoration(labelText:'Phone')),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text('Add'))]));
    if(ok==true&&name.text.trim().isNotEmpty&&phone.text.trim().isNotEmpty){await Api.dio.post('/api/v1/advanced/emergency/profiles/$patientId/contacts',data:{'name':name.text.trim(),'relation':relation.text.trim(),'phone':phone.text.trim(),'priority':1});await load();}
  }

  Future<Map<String,dynamic>?> issueBand() async {
    if(patientId==null)return null;
    final r=await Api.dio.post('/api/v1/advanced/emergency/bands',data:{'patient_id':patientId,'label':'Clinexa NFC Band'});
    await load(); return Map<String,dynamic>.from(r.data);
  }

  Future<void> issueAndWriteNfc() async {
    try{
      final available=await NfcManager.instance.isAvailable();
      if(!available){if(mounted)showMessage(context,'NFC is not available or enabled on this device.');return;}
      final band=await issueBand(); if(band==null)return;
      final token=band['token'].toString();
      if(mounted)showMessage(context,'Hold a writable NFC tag near the phone.');
      await NfcManager.instance.startSession(onDiscovered:(tag) async {
        final ndef=Ndef.from(tag);
        if(ndef==null||!ndef.isWritable){await NfcManager.instance.stopSession(errorMessage:'This NFC tag is not NDEF-writable.');return;}
        await ndef.write(NdefMessage([NdefRecord.createText('CLINEXA:$token')]));
        await NfcManager.instance.stopSession(alertMessage:'Clinexa emergency band written.');
        if(mounted){showMessage(context,'NFC band paired and written successfully.');await load();}
      });
    }catch(e){try{await NfcManager.instance.stopSession(errorMessage:'NFC operation failed.');}catch(_){ } if(mounted)showMessage(context,'NFC error: $e');}
  }

  String? _textRecord(NdefRecord record){
    final p=record.payload; if(p.isEmpty)return null;
    try{final langLength=p.first & 0x3F; if(p.length<=1+langLength)return null; return utf8.decode(p.sublist(1+langLength));}catch(_){return null;}
  }

  Future<void> scanNfc() async {
    try{
      if(!await NfcManager.instance.isAvailable()){if(mounted)showMessage(context,'NFC is not available or enabled.');return;}
      if(mounted)showMessage(context,'Hold the Clinexa NFC band near the phone.');
      await NfcManager.instance.startSession(onDiscovered:(tag) async {
        final ndef=Ndef.from(tag); final msg=ndef?.cachedMessage;
        String? text;
        if(msg!=null){for(final r in msg.records){text=_textRecord(r);if(text?.startsWith('CLINEXA:')==true)break;}}
        await NfcManager.instance.stopSession();
        if(text==null||!text!.startsWith('CLINEXA:')){if(mounted)showMessage(context,'This is not a Clinexa emergency tag.');return;}
        final token=text!.substring('CLINEXA:'.length); await showPublicCard(token,'nfc');
      });
    }catch(e){try{await NfcManager.instance.stopSession();}catch(_){ } if(mounted)showMessage(context,'NFC scan failed: $e');}
  }

  Future<void> showQrScanner() async {
    final token=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>_QrScannerPage()));
    if(token!=null&&token.isNotEmpty)await showPublicCard(token,'qr');
  }

  Future<void> showPublicCard(String token,String source) async {
    try{
      final r=await Api.dio.get('/api/v1/advanced/emergency/public/$token',queryParameters:{'source':source});
      if(!mounted)return; final m=Map<String,dynamic>.from(r.data);
      await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Row(children:[Icon(Icons.health_and_safety_rounded,color:Colors.red),SizedBox(width:8),Expanded(child:Text(m['name']?.toString()??'Emergency card'))]),content:SizedBox(width:470,child:SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _kv('Blood group',m['blood_group']),_kv('Allergies',m['allergies']),_kv('Critical conditions',m['critical_conditions']),_kv('Emergency notes',m['emergency_notes']),SizedBox(height:10),Text('Trusted contacts',style:TextStyle(fontWeight:FontWeight.w800)),SizedBox(height:6),...(List<dynamic>.from(m['contacts'] as List? ?? const[])).map((c)=>ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.contact_phone_outlined),title:Text(c['name']?.toString()??'Contact'),subtitle:Text('${c['relation']??''} • ${c['phone']??''}')))
      ]))),actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:Text('Close'))]));
    }catch(e){if(mounted)showMessage(context,Api.errorMessage(e));}
  }

  Widget _kv(String label,dynamic value)=>Padding(padding:EdgeInsets.only(bottom:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:TextStyle(fontSize:11,color:Color(0xFF718096),fontWeight:FontWeight.w700)),SizedBox(height:2),Text(value?.toString().trim().isNotEmpty==true?value.toString():'Not recorded',style:TextStyle(fontWeight:FontWeight.w700))]));

  Future<void> showBandQr(Map band) async {
    final token=band['token']?.toString(); if(token==null||token.isEmpty)return;
    await showDialog(context:context,builder:(ctx)=>AlertDialog(title:Text('QR emergency backup'),content:Column(mainAxisSize:MainAxisSize.min,children:[QrImageView(data:'CLINEXA:$token',size:220),SizedBox(height:12),Text('The QR contains only the revocable Clinexa emergency token, not the medical chart.',textAlign:TextAlign.center)]),actions:[FilledButton(onPressed:()=>Navigator.pop(ctx),child:Text('Done'))]));
  }

  @override Widget build(BuildContext context){
    final profile=bundle?['profile'] as Map?; final contacts=List<dynamic>.from(bundle?['contacts'] as List? ?? const[]); final bands=List<dynamic>.from(bundle?['bands'] as List? ?? const[]); final logs=List<dynamic>.from(bundle?['access_logs'] as List? ?? const[]);
    return SectionPage(title:'Emergency Hub',subtitle:'Real NFC band, QR fallback, trusted contacts and audited emergency access',actions:[IconButton(onPressed:load,icon:Icon(Icons.refresh_rounded))],child:ListView(padding:EdgeInsets.all(18),children:[
      DropdownButtonFormField<String>(isExpanded: true, initialValue:patientId,decoration:InputDecoration(labelText:'Emergency profile patient'),items:patients.map((p)=>DropdownMenuItem(value:p['id'].toString(),child:Text('${p['full_name']} • ${p['patient_code']}'))).toList(),onChanged:(v){setState(()=>patientId=v);load();}),
      if(error!=null)...[SizedBox(height:12),ErrorCard(error!)],if(loading)...[SizedBox(height:12),LinearProgressIndicator()],
      SizedBox(height:16),Container(padding:EdgeInsets.all(20),decoration:BoxDecoration(gradient:LinearGradient(colors:[Color(0xFF7F1D1D),Color(0xFFDC2626)]),borderRadius:BorderRadius.circular(24)),child:Wrap(alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,runSpacing:12,children:[
        SizedBox(width:520,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Emergency identity that is fast and revocable.',style:TextStyle(color:Colors.white,fontSize:24,fontWeight:FontWeight.w800)),SizedBox(height:8),Text('The NFC/QR tag stores only a secure token. Clinexa resolves that token to the minimum emergency profile and logs access.',style:TextStyle(color:Colors.white70,height:1.4))])),
        Wrap(spacing:8,runSpacing:8,children:[FilledButton.icon(style:FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.surface,foregroundColor:Colors.red.shade800),onPressed:issueAndWriteNfc,icon:Icon(Icons.nfc_rounded),label:Text('Pair & write NFC')),OutlinedButton.icon(style:OutlinedButton.styleFrom(foregroundColor:Colors.white,side:BorderSide(color:Colors.white54)),onPressed:scanNfc,icon:Icon(Icons.sensors),label:Text('Scan NFC')),OutlinedButton.icon(style:OutlinedButton.styleFrom(foregroundColor:Colors.white,side:BorderSide(color:Colors.white54)),onPressed:showQrScanner,icon:Icon(Icons.qr_code_scanner),label:Text('Scan QR'))])
      ])),
      SizedBox(height:14),Card(child:Padding(padding:EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('Emergency profile',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800))),FilledButton.tonalIcon(onPressed:editProfile,icon:Icon(Icons.edit_outlined),label:Text('Edit'))]),SizedBox(height:14),_kv('Public name',profile?['public_name']),_kv('Blood group',profile?['blood_group']),_kv('Allergies',profile?['allergies']),_kv('Critical conditions',profile?['critical_conditions']),_kv('Emergency notes',profile?['emergency_notes'])]))),
      SizedBox(height:14),Card(child:Padding(padding:EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text('Trusted contacts',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800))),IconButton(onPressed:addContact,icon:Icon(Icons.person_add_alt_1))]),if(contacts.isEmpty)Text('No trusted contacts yet.') else ...contacts.map((c)=>ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(child:Icon(Icons.person_outline)),title:Text(c['name']?.toString()??'Contact'),subtitle:Text('${c['relation']??''} • ${c['phone']??''}')))]))),
      SizedBox(height:14),Card(child:Padding(padding:EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Issued emergency bands',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),SizedBox(height:10),if(bands.isEmpty)Text('No bands issued. Use Pair & write NFC.') else ...bands.map((b)=>ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.nfc_rounded,color:b['active']==true?Colors.green:Colors.grey),title:Text(b['label']?.toString()??'Emergency band'),subtitle:Text(b['active']==true?'Active • ${b['issued_at']??''}':'Revoked'),trailing:Wrap(spacing:4,children:[IconButton(tooltip:'QR backup',onPressed:b['active']==true?()=>showBandQr(b):null,icon:Icon(Icons.qr_code_2)),IconButton(tooltip:'Revoke',onPressed:b['active']==true?()async{await Api.dio.post('/api/v1/advanced/emergency/bands/${b['id']}/revoke');await load();}:null,icon:Icon(Icons.block))])))]))),
      SizedBox(height:14),Card(child:Padding(padding:EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Emergency access audit',style:TextStyle(fontSize:16,fontWeight:FontWeight.w800)),SizedBox(height:10),if(logs.isEmpty)Text('No emergency scans logged yet.') else ...logs.take(20).map((x)=>ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.history),title:Text(x['access_type']?.toString()??'Access'),subtitle:Text('${x['source']??''} • ${x['accessed_at']??''}')))]))),
    ]));
  }
}

class _QrScannerPage extends StatefulWidget{_QrScannerPage();@override State<_QrScannerPage> createState()=>_QrScannerPageState();}
class _QrScannerPageState extends State<_QrScannerPage>{bool done=false;@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text('Scan Clinexa emergency QR')),body:MobileScanner(onDetect:(capture){if(done)return;for(final b in capture.barcodes){final raw=b.rawValue;if(raw!=null&&raw.startsWith('CLINEXA:')){done=true;Navigator.pop(context,raw.substring('CLINEXA:'.length));break;}}}));}
