import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_sign/main.dart';
import 'package:lucky_sign/screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app loads', (tester) async {
    await tester.pumpWidget(const LuckySignApp());
    await tester.pump();
    expect(find.textContaining('幸运签'), findsWidgets);
  });

  testWidgets('register shows invite code field', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();
    await tester.tap(find.text('没有账号？去注册'));
    await tester.pump();
    expect(find.text('邀请码'), findsOneWidget);
    expect(find.textContaining('邀请码'), findsWidgets);
  });
}
