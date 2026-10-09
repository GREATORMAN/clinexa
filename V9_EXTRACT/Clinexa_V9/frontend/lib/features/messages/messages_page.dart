import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/network/api.dart';
import '../../core/widgets/clinexa_ui.dart';
class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override State<MessagesPage> createState()=>_MessagesPageState();
}
class _MessagesPageState extends State<MessagesPage>{
  List<Map<String,dynamic>> contacts=[],messages=[];
  Map<String,dynamic>? selected;String? error;bool sending=false;
  final body=TextEditingController();Timer? poll;int request=0;
  @override void initState(){super.initState();load();poll=Timer.periodic(const Duration(seconds:10),(_){if(selected!=null)loadThread();});}
  @override void dispose(){poll?.cancel();body.dispose();super.dispose();}
  Future<void> load()async{try{final r=await Api.dio.get('/api/v1/message-contacts');if(mounted)setState(()=>contacts=List<Map<String,dynamic>>.from(r.data));}catch(e){if(mounted)setState(()=>error=Api.errorMessage(e));}}
  Future<void> loadThread()async{
    final id=selected?['id'];if(id==null)return;final serial=++request;
    try{await Api.dio.post('/api/v1/messages/thread/$id/read');final r=await Api.dio.get('/api/v1/messages/thread/$id');if(mounted&&selected?['id']==id&&serial==request)setState((){messages=List<Map<String,dynamic>>.from(r.data);error=null;});}catch(e){if(mounted&&serial==request)setState(()=>error=Api.errorMessage(e));}
  }
  Future<void> send()async{
    if(selected==null||body.text.trim().isEmpty||sending)return;final text=body.text.trim();
    setState(()=>sending=true);
    try{await Api.dio.post('/api/v1/messages',data:{'recipient_user_id':selected!['id'],'body':text});body.clear();await loadThread();}catch(e){if(mounted)setState(()=>error=Api.errorMessage(e));}finally{if(mounted)setState(()=>sending=false);}
  }
  @override Widget build(BuildContext context){
    final people=CxSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('Care team',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:16),if(contacts.isEmpty)const Text('No contacts available.'),...contacts.map((c)=>ListTile(contentPadding:EdgeInsets.zero,selected:selected?['id']==c['id'],leading:CircleAvatar(child:Text(c['full_name'].toString().isEmpty?'?':c['full_name'].toString()[0])),title:Text(c['full_name']),onTap:sending?null:(){if(body.text.isNotEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Send or clear your draft before changing conversations.')));return;}setState((){selected=c;messages=[];});loadThread();}))]));
    final conversation=CxSurface(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(selected?['full_name']??'Start a conversation',style:const TextStyle(fontSize:22,fontWeight:FontWeight.bold))),IconButton(onPressed:loadThread,tooltip:'Refresh conversation',icon:const Icon(Icons.refresh))]),const SizedBox(height:16),if(selected==null)const Padding(padding:EdgeInsets.symmetric(vertical:50),child:Text('Choose a member of your care team. Messages stay visible only to their sender and recipient.'))else...[if(messages.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('No messages yet. Say hello.')),for(final m in messages)Align(alignment:m['sender_user_id']==Api.currentUser?['id']?Alignment.centerRight:Alignment.centerLeft,child:Container(margin:const EdgeInsets.only(bottom:12),padding:const EdgeInsets.all(16),constraints:const BoxConstraints(maxWidth:520),decoration:BoxDecoration(color:m['sender_user_id']==Api.currentUser?['id']?Theme.of(context).colorScheme.primaryContainer:Theme.of(context).colorScheme.surfaceContainerLow,borderRadius:BorderRadius.circular(20)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[SelectableText(m['body']),const SizedBox(height:8),Text('${m['created_at']} ${m['sender_user_id']==Api.currentUser?['id']?m['is_read']?'· Read':'· Sent':''}',style:Theme.of(context).textTheme.bodySmall)]))),const SizedBox(height:16),TextField(controller:body,enabled:!sending,minLines:2,maxLines:5,decoration:const InputDecoration(labelText:'Message',hintText:'Write to your care team…')),const SizedBox(height:12),FilledButton.icon(onPressed:Api.can('messages.send')&&!sending?send:null,icon:const Icon(Icons.send_outlined),label:Text(sending?'Sending…':'Send message'))]]));
    return SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[CxPageHeader(eyebrow:'Connected care',title:'Keep the conversation going.',subtitle:'Private care-team threads with sent and read status. Refreshes every ten seconds.'),const SizedBox(height:24),if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),LayoutBuilder(builder:(ctx,c)=>c.maxWidth>=900?Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:280,child:people),const SizedBox(width:20),Expanded(child:conversation)]):Column(children:[people,const SizedBox(height:20),conversation]))]));
  }
}
