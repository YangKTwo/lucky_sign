import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_sign/main.dart';
import 'package:lucky_sign/screens/login_screen.dart';
import 'package:lucky_sign/utils/checkin_proof.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app loads login when logged out', (tester) async {
    await tester.pumpWidget(const LuckySignApp(loggedIn: false));
    await tester.pump();
    expect(find.textContaining('幸运签'), findsWidgets);
    expect(find.text('进入今日'), findsOneWidget);
  });

  testWidgets('register shows invite code field', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();
    await tester.tap(find.text('没有账号？去注册'));
    await tester.pump();
    expect(find.text('邀请码'), findsOneWidget);
    expect(find.textContaining('邀请码'), findsWidgets);
    expect(find.text('提交注册'), findsOneWidget);
  });

  test('empty checkin proof is rejected', () {
    expect(checkinProofError(text: '', hasImage: false), isNotNull);
    expect(checkinProofError(text: '   ', hasImage: false), isNotNull);
    expect(checkinProofError(text: '完成了', hasImage: false), isNull);
    expect(checkinProofError(text: '', hasImage: true), isNull);
  });

  test('checkin image over 5MB is rejected', () {
    expect(checkinImageSizeError(maxCheckinImageBytes), isNull);
    expect(checkinImageSizeError(maxCheckinImageBytes + 1), isNotNull);
  });
}
