import 'package:flutter/material.dart';
import 'app.dart';
import 'core/network/api.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.configure();
  runApp(const ClinexaApp());
}
