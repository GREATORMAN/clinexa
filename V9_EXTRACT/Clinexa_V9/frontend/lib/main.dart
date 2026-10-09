import 'package:flutter/material.dart';
import 'app.dart';
import 'core/theme/preferences.dart';
import 'core/notifications/reminders.dart';
import 'core/network/api.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.configure();
  await AppPreferences.load();
  try { await MedicationReminders.initialize(); } catch (_) { MedicationReminders.status.value="Device reminders could not initialize"; }
  runApp(ClinexaApp());
}
