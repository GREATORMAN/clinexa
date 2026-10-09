import 'package:flutter/material.dart';
import 'core/theme/theme.dart';
import 'core/theme/preferences.dart';
import 'features/auth/login_page.dart';
import 'features/security/security_gate.dart';

class ClinexaApp extends StatefulWidget {
  ClinexaApp({super.key});

  @override
  State<ClinexaApp> createState() => _ClinexaAppState();
}

class _ClinexaAppState extends State<ClinexaApp> {

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(valueListenable: AppPreferences.mode, builder: (context, mode, _) => MaterialApp(
      title: 'Clinexa',
      debugShowCheckedModeBanner: false,
      theme: ClinexaTheme.light,
      darkTheme: ClinexaTheme.dark,
      themeMode: mode,
      home: SecurityGate(child: LoginPage()),
    ));
  }
}
