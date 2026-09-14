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
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), '阿明');
    await tester.enterText(fields.at(1), 'ABCDEFGH');
    await tester.enterText(fields.at(2), 'a@b.com');
    await tester.enterText(fields.at(3), 'short');
    await tester.enterText(fields.at(4), 'short');
    await tester.ensureVisible(find.text('加入圈子'));
    await tester.tap(find.text('加入圈子'));
    await tester.pump();
    expect(find.text('密码至少 8 位'), findsOneWidget);
  });

  testWidgets('checkin sheet keeps form when proof is empty', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CheckinProofSheet()),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('提交到社区'));
    await tester.pump();
    expect(find.textContaining('写一句或拍张照'), findsOneWidget);
    expect(find.text('完成打卡'), findsOneWidget);
  });

  testWidgets('checkin sheet submits text proof', (tester) async {
    Map<String, dynamic>? captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                showModalBottomSheet<Map<String, dynamic>>(
                  context: context,
                  builder: (_) => CheckinProofSheet(
                    submitter: ({required String text, image}) async {
                      captured = {'text': text};
                      return {
                        'data': {'status': 'COMPLETED', 'streakDays': 3},
                      };
                    },
                  ),
                );
              },
              child: const Text('open-checkin'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open-checkin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '今天完成了拉伸');
    await tester.tap(find.text('提交到社区'));
    await tester.pumpAndSettle();
    expect(captured?['text'], '今天完成了拉伸');
  });

  testWidgets('rank first paint is loading not empty list', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RankScreen()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('暂无成员'), findsNothing);
  });
}
