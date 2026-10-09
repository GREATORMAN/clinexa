import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clinexa/app.dart';
import 'package:clinexa/core/theme/theme.dart';
import 'package:clinexa/core/widgets/clinexa_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel("plugins.it_nomads.com/flutter_secure_storage"), (call) async => call.method == "readAll" ? <String,String>{} : null);
  });
  testWidgets('Login renders with device lock disabled', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ClinexaApp());
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final dark in [false,true]) {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('Shared layout at $width with enlarged text dark=$dark', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme: dark ? ClinexaTheme.dark : ClinexaTheme.light, home: MediaQuery(data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(1.6)), child: Scaffold(body: ListView(padding: EdgeInsets.all(18), children: [
        CxPageHeader(eyebrow: 'Care coordination', title: 'Every handoff, accounted for.', subtitle: 'Patient-linked tasks with priorities and due dates.', actions: [FilledButton(onPressed: () {}, child: Text('New task'))]),
        SizedBox(height: 20),
        CxAdaptiveGrid(minItemWidth: 180, children: [CxMetricCard(label: 'Active tasks', value: '123', caption: 'Open and in progress', icon: Icons.checklist_rounded), CxMetricCard(label: 'Completed', value: '45', caption: 'Completed care tasks', icon: Icons.task_alt_rounded)]),
      ])))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  }
}
