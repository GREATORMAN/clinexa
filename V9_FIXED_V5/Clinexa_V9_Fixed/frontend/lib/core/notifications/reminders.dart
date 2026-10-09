import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../network/api.dart';
class MedicationReminders {
  static final plugin=FlutterLocalNotificationsPlugin();
  static const storage=FlutterSecureStorage();
  static bool initialized=false;
  static Future<void> pending=Future<void>.value();
  static Future<void> serial(Future<void> Function() action) { pending=pending.catchError((Object e) { status.value="Reminder action failed; please retry in Clinexa"; }).then((_)=>action()); return pending; }
  static final status=ValueNotifier<String>('Reminders are off');
  static bool get supported=>!kIsWeb && (defaultTargetPlatform==TargetPlatform.android||defaultTargetPlatform==TargetPlatform.iOS);
  static Future<void> initialize()async{
    if(!supported||initialized)return;
    tzdata.initializeTimeZones();
    final name=await FlutterTimezone.getLocalTimezone();tz.setLocalLocation(tz.getLocation(name));
    await plugin.initialize(InitializationSettings(android:AndroidInitializationSettings('@mipmap/ic_launcher'),iOS:DarwinInitializationSettings(requestAlertPermission:false,requestBadgePermission:false,requestSoundPermission:false,notificationCategories:[DarwinNotificationCategory('medication',actions:[DarwinNotificationAction.plain('taken','Taken',options:{DarwinNotificationActionOption.foreground}),DarwinNotificationAction.plain('skipped','Skip',options:{DarwinNotificationActionOption.foreground}),DarwinNotificationAction.plain('snooze','Snooze 10 min',options:{DarwinNotificationActionOption.foreground})])])),onDidReceiveNotificationResponse:respond);
    initialized=true;
    final launch=await plugin.getNotificationAppLaunchDetails();if(launch?.didNotificationLaunchApp==true && launch?.notificationResponse!=null)await respond(launch!.notificationResponse!);
  }
  static Future<void> respond(NotificationResponse response)=>serial(()=>handle(response));
  static Future<void> handle(NotificationResponse response)async{
    if(response.payload==null||(response.actionId?.isEmpty ?? true))return;
    final data=Map<String,dynamic>.from(jsonDecode(response.payload!));
    final owner=Api.currentUser?['id'];if(owner==null||owner!=data['owner']){status.value='Sign in to the reminder’s account to record this dose';return;}
    if(response.actionId=='snooze'){
      await schedule(data,DateTime.now().add(const Duration(minutes:10)));status.value='Snoozed for ten minutes';return;
    }
    if(!['taken','skipped'].contains(response.actionId))return;
    final key='dose_queue_$owner';final queue=List<Map<String,dynamic>>.from(jsonDecode(await storage.read(key:key)??'[]'));
    queue.removeWhere((x)=>x['schedule_id']==data['schedule_id']&&x['scheduled_for']==data['scheduled_for']);
    queue.add({'schedule_id':data['schedule_id'],'scheduled_for':data['scheduled_for'],'status':response.actionId});
    await storage.write(key:key,value:jsonEncode(queue));await flushInternal();
  }
  static Future<void> flush()=>serial(flushInternal);
  static Future<void> flushInternal()async{
    final owner=Api.currentUser?['id'];if(owner==null)return;
    final key='dose_queue_$owner';final queue=List<Map<String,dynamic>>.from(jsonDecode(await storage.read(key:key)??'[]'));final remaining=<Map<String,dynamic>>[];
    for(final dose in queue){try{await Api.dio.post('/api/v1/portal/medications/${dose['schedule_id']}/dose-logs',data:{'scheduled_for':dose['scheduled_for'],'status':dose['status'],'note':'Notification action','idempotency_key':'${dose['schedule_id']}:${dose['scheduled_for']}'});}catch(_){remaining.add(dose);}}
    await storage.write(key:key,value:jsonEncode(remaining));status.value=remaining.isEmpty?'Dose actions synced':'${remaining.length} dose actions pending · open Clinexa online to retry';
  }
  static int id(Map<String,dynamic> data){final value='${data['schedule_id']}:${data['scheduled_for']}';var hash=2166136261;for(final c in value.codeUnits){hash=((hash^c)*16777619)&0x7fffffff;}return hash;}
  static Future<void> schedule(Map<String,dynamic> data,DateTime date)async{
    await plugin.zonedSchedule(id(data),'Medication reminder','Open Clinexa to review and record your scheduled dose.',tz.TZDateTime.from(date,tz.local),const NotificationDetails(android:AndroidNotificationDetails('medication_reminders','Medication reminders',channelDescription:'Patient-enabled medication schedules',importance:Importance.high,priority:Priority.high,visibility:NotificationVisibility.private,actions:[AndroidNotificationAction('taken','Taken',showsUserInterface:true,cancelNotification:true),AndroidNotificationAction('skipped','Skip',showsUserInterface:true,cancelNotification:true),AndroidNotificationAction('snooze','Snooze 10 min',showsUserInterface:true,cancelNotification:true)]),iOS:DarwinNotificationDetails(categoryIdentifier:'medication')),payload:jsonEncode(data),androidScheduleMode:AndroidScheduleMode.inexactAllowWhileIdle,uiLocalNotificationDateInterpretation:UILocalNotificationDateInterpretation.absoluteTime);
  }
  static Future<void> enable(List<Map<String,dynamic>> schedules)async{
    if(!supported){status.value='Scheduled reminders are available on Android and iOS';return;}
    await initialize();
    final android=plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();final ios=plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final allowed=await android?.requestNotificationsPermission()??await ios?.requestPermissions(alert:true,badge:true,sound:true)??false;
    if(!allowed){status.value='Notification permission was denied';return;}
    final owner=Api.currentUser?['id'];if(owner==null)return;
    await storage.write(key:'reminders_enabled_$owner',value:'true');await sync(schedules);
  }
  static Future<void> sync(List<Map<String,dynamic>> schedules)async{
    final owner=Api.currentUser?['id'];if(!supported||owner==null||await storage.read(key:'reminders_enabled_$owner')!='true')return;
    await initialize();await plugin.cancelAll();final now=DateTime.now();final candidates=<Map<String,dynamic>>[];
    for(final s in schedules.where((s)=>s['active']==true)){
      for(var day=0;day<7;day++){
        final date=DateTime(now.year,now.month,now.day+day);
        final start=DateTime.tryParse(s['start_date']?.toString()??'');final end=DateTime.tryParse(s['end_date']?.toString()??'');
        if(start!=null&&date.isBefore(start)||end!=null&&date.isAfter(end))continue;
        for(final time in s['times_csv'].toString().split(',')){
          final parts=time.trim().split(':');if(parts.length!=2)continue;final h=int.tryParse(parts[0]),m=int.tryParse(parts[1]);if(h==null||m==null||h<0||h>23||m<0||m>59)continue;
          final at=DateTime(date.year,date.month,date.day,h,m);if(!at.isAfter(now))continue;
          candidates.add({'owner':owner,'schedule_id':s['id'],'scheduled_for':at.toUtc().toIso8601String()});
        }
      }
    }
    candidates.sort((a,b)=>a['scheduled_for'].toString().compareTo(b['scheduled_for'].toString()));
    for(final data in candidates.take(60)){await schedule(data,DateTime.parse(data['scheduled_for']));}
    status.value='${candidates.take(60).length} reminders scheduled · refresh the next seven days by opening Clinexa';await flush();
  }
  static Future<void> disable()async{
    final owner=Api.currentUser?['id'];if(owner!=null)await storage.delete(key:'reminders_enabled_$owner');if(initialized)await plugin.cancelAll();status.value='Reminders are off';
  }
}
