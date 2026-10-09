import 'package:flutter_test/flutter_test.dart';import 'package:clinexa/app.dart';
void main(){testWidgets('Clinexa login renders',(tester)async{await tester.pumpWidget(const ClinexaApp());expect(find.text('Clinexa'),findsWidgets);expect(find.text('Welcome back'),findsOneWidget);});}
