import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_sign/main.dart';
import 'package:lucky_sign/screens/home_shell.dart';
import 'package:lucky_sign/screens/login_screen.dart';
import 'package:lucky_sign/screens/rank_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app loads login', (tester) async {
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

  testWidgets('home shell has four tabs', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));
    await tester.pump();
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('社区'), findsOneWidget);
    expect(find.text('排行'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('rank loading does not look empty', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RankScreen()));
    await tester.pump();
    expect(find.text('暂无成员'), findsNothing);
    expect(find.text('圈子排行'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
