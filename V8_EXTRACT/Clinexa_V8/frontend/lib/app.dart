import 'package:flutter/material.dart';
import 'core/theme/theme.dart';
import 'features/auth/login_page.dart';
import 'features/security/security_gate.dart';

class ClinexaApp extends StatefulWidget {
  const ClinexaApp({super.key});

  @override
  State<ClinexaApp> createState() => _ClinexaAppState();
}

class _ClinexaAppState extends State<ClinexaApp> {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clinexa',
      debugShowCheckedModeBanner: false,
      theme: ClinexaTheme.light,
      darkTheme: ClinexaTheme.dark,
      themeMode: ThemeMode.light,
      home: const SecurityGate(child: LoginPage()),
    );
  }
}
