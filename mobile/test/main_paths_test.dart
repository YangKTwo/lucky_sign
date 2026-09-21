import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_sign/screens/login_screen.dart';
import 'package:lucky_sign/screens/rank_screen.dart';
import 'package:lucky_sign/widgets/checkin_proof_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('register requires 8-char password', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();
    await tester.tap(find.text('没有账号？去注册'));
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextFormField, '昵称'), '小签');
    await tester.enterText(find.widgetWithText(TextFormField, '邀请码'), 'ABCD12');
    await tester.enterText(find.widgetWithText(TextFormField, '邮箱'), 'a@b.com');
    await tester.enterText(find.widgetWithText(TextFormField, '密码'), '1234567');
    await tester.enterText(find.widgetWithText(TextFormField, '确认密码'), '1234567');
    await tester.tap(find.text('提交注册'));
    await tester.pump();

    expect(find.text('密码至少 8 位'), findsOneWidget);
  });

  testWidgets('checkin sheet stays open without proof', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CheckinProofSheet()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('提交到社区'));
    await tester.pump();

    expect(find.text('写一句或拍张照，圈子才能看见你完成了'), findsOneWidget);
    expect(find.text('完成打卡'), findsOneWidget);
  });

  testWidgets('checkin sheet keeps draft after submit failure', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CheckinProofSheet(
            submitter: ({required String text, image}) async {
              throw Exception('网络不太好');
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '晨跑完成');
    await tester.tap(find.text('提交到社区'));
    await tester.pump();

    expect(find.text('晨跑完成'), findsOneWidget);
    expect(find.textContaining('网络不太好'), findsOneWidget);
    expect(find.text('完成打卡'), findsOneWidget);
  });

  testWidgets('rank first paint does not show empty members', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: RankScreen()));
    await tester.pump();

    expect(find.text('暂无成员'), findsNothing);
    expect(
      find.byType(CircularProgressIndicator).evaluate().isNotEmpty || find.text('重试').evaluate().isNotEmpty,
      isTrue,
    );
  });
}
