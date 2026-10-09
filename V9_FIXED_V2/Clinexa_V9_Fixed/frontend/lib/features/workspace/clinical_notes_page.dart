import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/theme/preferences.dart';
import '../../core/widgets/clinexa_ui.dart';

class ClinicalNotesPage extends StatefulWidget {
  const ClinicalNotesPage({super.key});
  @override
  State<ClinicalNotesPage> createState() => _ClinicalNotesPageState();
}
class _ClinicalNotesPageState extends State<ClinicalNotesPage> {
  List<Map<String,dynamic>> notes = [], patients = [];
  Map<String,dynamic>? selected;
  final title = TextEditingController(), body = TextEditingController();
  Timer? debounce;
  bool loading = true, saving = false, dirty = false;
  String? error;
  String saveStatus = 'Choose a note to begin';
  String? amendmentReason;
  int generation = 0;
  late final Future<bool> Function() leaveGuard;
  @override
  void initState() { super.initState(); leaveGuard=() async => !dirty || await save(action:amendmentReason==null?"save":"amend",reason:amendmentReason??""); AppPreferences.beforeNavigate=leaveGuard; load(); }
  @override
  void dispose() { if (identical(AppPreferences.beforeNavigate,leaveGuard)) AppPreferences.beforeNavigate=null; debounce?.cancel(); title.dispose(); body.dispose(); super.dispose(); }
  Future<void> load() async {
    try {
      final results = await Future.wait([Api.dio.get('/api/v1/clinical-notes'), Api.dio.get('/api/v1/patients')]);
      if (!mounted) return;
      setState(() { notes = List<Map<String,dynamic>>.from(results[0].data); patients = List<Map<String,dynamic>>.from(results[1].data); loading=false; error=null; });
    } catch (e) { if (mounted) setState(() {loading=false;error=Api.errorMessage(e);}); }
  }
  void select(Map<String,dynamic> note) {
    debounce?.cancel(); generation++;
    setState(() {selected=Map.from(note);title.text=note['title'];body.text=note['content'];dirty=false;amendmentReason=null;error=null;saveStatus=note['status']=='final'?'Final · locked':'All changes saved';});
  }
  void changed() {
    generation++; dirty=true;
    setState(() {saveStatus='Unsaved changes';});
    debounce?.cancel();
    if (selected?['status']=='draft') debounce=Timer(const Duration(milliseconds:900),()=>save());
  }
  Future<bool> save({String action='save',String reason=''}) async {
    if (selected==null || saving) return false;
    debounce?.cancel(); final id=selected!['id'];final editGeneration=generation;
    setState(() {saving=true;saveStatus='Saving…';error=null;});
    try {
      final response=await Api.dio.patch('/api/v1/clinical-notes/$id',data:{'version':selected!['version'],'title':title.text,'content':body.text,'action':action,'reason':reason});
      if (!mounted) return false;
      final updated=Map<String,dynamic>.from(response.data);
      setState(() {selected=updated;final i=notes.indexWhere((x)=>x['id']==id);if(i>=0)notes[i]=updated;saving=false;dirty=editGeneration!=generation;if(!dirty)amendmentReason=null;saveStatus=dirty?'Unsaved changes':action=='save'?'All changes saved':'Final · locked';});
      if (dirty && updated['status']=='draft') debounce=Timer(const Duration(milliseconds:500),()=>save());
      return true;
    } catch (e) {if(mounted)setState(() {saving=false;saveStatus='Save failed · text kept on this screen';error=Api.errorMessage(e);});return false;}
  }
  Future<void> create() async {
    if(dirty && !await leaveGuard()) return;
    if (!mounted) return;
    String? patientId;final name=TextEditingController();
    final result=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,set)=>AlertDialog(title:const Text('New clinical note'),content:SizedBox(width:420,child:Column(mainAxisSize:MainAxisSize.min,children:[DropdownButtonFormField<String>(isExpanded:true,decoration:const InputDecoration(labelText:'Patient'),items:patients.map((p)=>DropdownMenuItem(value:p['id'].toString(),child:Text(p['full_name'],overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>set(()=>patientId=v)),const SizedBox(height:14),TextField(controller:name,decoration:const InputDecoration(labelText:'Note title'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:patientId==null?null:()=>Navigator.pop(ctx,{'patient_id':patientId,'title':name.text}),child:const Text('Create draft'))])));
    name.dispose();if(result==null)return;
    try {final r=await Api.dio.post('/api/v1/clinical-notes',data:result);if(!mounted)return;final note=Map<String,dynamic>.from(r.data);setState(()=>notes.insert(0,note));select(note);}catch(e){if(mounted)setState(()=>error=Api.errorMessage(e));}
  }
  Future<void> finalize() async {
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Finalize this note?'),content:const Text('Final notes are locked. Future corrections require an amendment and preserve every previous version.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Continue editing')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Finalize'))]));
    if(confirmed==true) await save(action:'finalize');
  }
  Future<void> amend() async {
    final reason=TextEditingController();
    final text=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Reason for amendment'),content:TextField(controller:reason,maxLines:3,decoration:const InputDecoration(hintText:'Explain why this final note needs correction')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,reason.text.trim()),child:const Text('Continue'))]));reason.dispose();
    if(text==null||text.isEmpty||!mounted)return;
    final editor=TextEditingController(text:body.text);
    final content=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Amend final note'),content:SizedBox(width:640,child:TextField(controller:editor,minLines:8,maxLines:16)),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(ctx,editor.text),child:const Text('Save amendment'))]));editor.dispose();
    if(content!=null){body.text=content;dirty=true;amendmentReason=text;await save(action:'amend',reason:text);}
  }
  Future<void> history() async {
    try {final r=await Api.dio.get('/api/v1/clinical-notes/${selected!['id']}/history');if(!mounted)return;await showDialog(context:context,builder:(ctx)=>Dialog(child:SizedBox(width:700,child:ListView(shrinkWrap:true,padding:const EdgeInsets.all(24),children:[const Text('Revision history',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:16),...(r.data as List).map((v)=>ExpansionTile(title:Text('Version ${v['version']} · ${v['author']}'),subtitle:Text('${v['created_at']} · ${v['reason']}'),children:[Padding(padding:const EdgeInsets.all(16),child:SelectableText(v['snapshot']['content']??''))])),TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Close'))]))));}catch(e){if(mounted)setState(()=>error=Api.errorMessage(e));}
  }
  @override
  Widget build(BuildContext context) {
    final locked=selected?['status']=='final';final own=selected?['author_id']==Api.currentUser?['id'];
    final list=CxSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Your clinical workspace',style:TextStyle(fontWeight:FontWeight.bold,fontSize:17)),const SizedBox(height:12),if(notes.isEmpty)const Text('Create a draft to begin.'),...notes.map((n)=>ListTile(selected:selected?['id']==n['id'],shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(16)),contentPadding:const EdgeInsets.symmetric(horizontal:8),leading:Icon(n['status']=='final'?Icons.lock_outline:Icons.edit_note),title:Text(n['title']),subtitle:Text('${n['patient_name']} · v${n['version']}'),onTap:saving?null:()async{if(dirty&&!await leaveGuard())return;select(n);}))]));
    final editor=CxSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[if(selected==null)...[const Icon(Icons.edit_note,size:48),const SizedBox(height:16),const Text('A focused place for clinical thinking',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:10),const Text('Drafts save automatically. Finalize when ready; amendments keep a reviewable history.') ]else...[Wrap(spacing:10,runSpacing:10,children:[Chip(label:Text('${selected!['patient_name']} · v${selected!['version']}')),Chip(avatar:Icon(locked?Icons.lock:Icons.cloud_done,size:16),label:Text(saveStatus))]),const SizedBox(height:20),TextField(controller:title,readOnly:locked||!own||saving,onChanged:(_)=>changed(),decoration:const InputDecoration(labelText:'Note title')),const SizedBox(height:16),TextField(controller:body,readOnly:locked||!own||saving,onChanged:(_)=>changed(),minLines:12,maxLines:24,decoration:const InputDecoration(labelText:'Clinical note',alignLabelWithHint:true)),const SizedBox(height:16),Wrap(spacing:10,runSpacing:10,children:[if(own&&!locked)FilledButton.icon(onPressed:saving?null:()=>save(),icon:const Icon(Icons.save_outlined),label:const Text('Save now')),if(own&&!locked)OutlinedButton.icon(onPressed:saving?null:finalize,icon:const Icon(Icons.lock_outline),label:const Text('Finalize')),if(own&&locked)OutlinedButton.icon(onPressed:saving?null:amend,icon:const Icon(Icons.history_edu),label:const Text('Amend')),TextButton.icon(onPressed:history,icon:const Icon(Icons.history),label:const Text('History'))]),const SizedBox(height:10),Text(own?'Keep this screen open until changes are saved.':'Only the author can edit this note.',style:Theme.of(context).textTheme.bodySmall)]]));
    return PopScope(canPop:!dirty,child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CxPageHeader(eyebrow:'Clinical workspace',title:'Write with confidence.',subtitle:'Autosaved drafts, locked final notes and a complete revision trail.',actions:[if(Api.can('patient.clinical.write'))FilledButton.icon(onPressed:saving?null:create,icon:const Icon(Icons.add),label:const Text('New note')),IconButton(onPressed:load,tooltip:'Refresh notes',icon:const Icon(Icons.refresh))]),const SizedBox(height:24),if(error!=null)Padding(padding:const EdgeInsets.only(bottom:16),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),if(loading)const Center(child:CircularProgressIndicator())else LayoutBuilder(builder:(ctx,c)=>c.maxWidth>=900?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:300,child:list),const SizedBox(width:20),Expanded(child:editor)]):Column(children:[list,const SizedBox(height:20),editor]))])));
  }
}
