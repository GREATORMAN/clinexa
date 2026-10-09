import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/widgets/clinexa_ui.dart';
class CaregiverPage extends StatefulWidget{
  const CaregiverPage({super.key});
  @override State<CaregiverPage> createState()=>_CaregiverPageState();
}
class _CaregiverPageState extends State<CaregiverPage>{
  List<Map<String,dynamic>> grants=[];String? error;
  @override void initState(){super.initState();load();}
  Future<void> load()async{try{final r=await Api.dio.get('/api/v1/caregiver/grants');if(mounted)setState((){grants=List<Map<String,dynamic>>.from(r.data);error=null;});}catch(e){if(mounted)setState(()=>error=Api.errorMessage(e));}}
  Future<void> download(Map<String,dynamic> grant,Map<String,dynamic> document)async{try{final r=await Api.dio.get('/api/v1/caregiver/grants/${grant['id']}/documents/${document['id']}/download',options:Options(responseType:ResponseType.bytes));await FilePicker.platform.saveFile(fileName:document['name'],bytes:Uint8List.fromList(List<int>.from(r.data)));}catch(e){if(mounted)setState(()=>error=Api.errorMessage(e));}}
  Future<void> open(Map<String,dynamic> grant,String scope)async{
    try{final r=await Api.dio.get('/api/v1/caregiver/grants/${grant['id']}/$scope');if(!mounted)return;
      final entries=scope=='emergency'?(r.data==null?[]:[r.data]):r.data as List;
      await showDialog(context:context,builder:(ctx)=>Dialog(child:SizedBox(width:600,child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(24),children:[Text('${grant['patient_name']} · ${scope.replaceAll('_',' ')}',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:16),if(entries.isEmpty)const Text('No shared information in this category.'),...entries.map((e){if(scope=='appointments')return ListTile(leading:const Icon(Icons.calendar_today_outlined),title:Text(e['start_at']),subtitle:Text('${e['status']} · ${e['reason']??'Visit'}'));if(scope=='reminders')return ListTile(leading:const Icon(Icons.medication_outlined),title:Text(e['medication_name']),subtitle:Text('${e['dose_label']??''} · ${e['times_csv']}\n${e['instructions']??''}'));if(scope=='selected_documents')return ListTile(leading:const Icon(Icons.description_outlined),title:Text(e['name']),subtitle:Text(e['category']),trailing:IconButton(tooltip:'Download shared document',onPressed:()=>download(grant,Map<String,dynamic>.from(e)),icon:const Icon(Icons.download)));return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[for(final key in ['public_name','blood_group','allergies','critical_conditions','emergency_notes'])Padding(padding:const EdgeInsets.only(bottom:14),child:Text('${key.replaceAll('_',' ')}: ${e[key]??'Not recorded'}'))]);}),TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]))));
    }catch(e){if(mounted)setState(()=>error=Api.errorMessage(e));}
  }
  @override Widget build(BuildContext context)=>SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CxPageHeader(eyebrow:'Family & caregivers',title:'Support, with permission.',subtitle:'Read only the information each patient has chosen to share with you.',actions:[IconButton(onPressed:load,tooltip:'Refresh grants',icon:const Icon(Icons.refresh))]),const SizedBox(height:24),if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),if(grants.isEmpty)CxSurface(child:const Text('No active sharing grants. Ask the patient to share access through Privacy & sharing.')),CxAdaptiveGrid(children:grants.map((g)=>CxSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(g['patient_name'],style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:16),Wrap(spacing:8,runSpacing:8,children:(g['scopes']as List).map((s)=>OutlinedButton(onPressed:()=>open(g,s),child:Text(s.toString().replaceAll('_',' ')))).toList())]))).toList())]));
}
