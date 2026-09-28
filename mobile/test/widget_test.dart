import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_sign/main.dart';
import 'package:lucky_sign/screens/login_screen.dart';
import 'package:lucky_sign/screens/rank_screen.dart';
import 'package:lucky_sign/screens/today_screen.dart';
import 'package:lucky_sign/widgets/ui_bits.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('app loads', (tester) async {
    await tester.pumpWidget(const LuckySignApp(loggedIn: false));
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
    expect(find.text('提交注册'), findsOneWidget);
  });

  testWidgets('empty checkin stays on sheet', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CheckinSheet())));
    await tester.pump();
    await tester.tap(find.text('提交到社区'));
    await tester.pump();
    expect(find.text('写点感受或加一张图再提交'), findsOneWidget);
    expect(find.text('完成打卡'), findsOneWidget);
  });

  testWidgets('failed checkin keeps the sheet', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CheckinSheet(
          onSubmit: (text, image) async {
            throw Exception('网络不通');
          },
        ),
      ),
    ));
    await tester.enterText(find.byType(TextField), '完成了');
    await tester.tap(find.text('提交到社区'));
    await tester.pump();
    expect(find.textContaining('网络不通'), findsOneWidget);
    expect(find.text('完成打卡'), findsOneWidget);
  });

  testWidgets('week strip renders seven days', (tester) async {
    final days = List.generate(7, (i) {
      final d = DateTime(2026, 9, 22).add(Duration(days: i));
      return {
        'date': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        'status': i == 6 ? 'PENDING' : 'COMPLETED',
      };
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: WeekCheckinStrip(days: days)),
    ));
    expect(find.text('本周 7 天'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNWidgets(6));
  });

  testWidgets('circle pace shows just you left', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: CirclePaceCard(
          checkedCount: 3,
          memberCount: 4,
          onlyMeLeft: true,
        ),
      ),
    ));
    expect(find.text('圈子就差你了'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
  });

  test('rank empty label hidden while loading or error', () {
    expect(rankEmptyLabel(hasData: false, isEmpty: true), isNull);
    expect(rankEmptyLabel(hasData: true, isEmpty: true), '暂无成员');
    expect(rankEmptyLabel(hasData: true, isEmpty: false), isNull);
  });

  test('today helpers', () {
    expect(todayKey(DateTime(2026, 9, 28)), '2026-09-28');
    expect(formatCheckedAt('2026-09-28T08:05:00Z'), isNotEmpty);
    expect(streakBonusCopy(10), contains('满周'));
    expect(streakBonusCopy(50), contains('满月'));
    expect(streakBonusCopy(0), isEmpty);
  });
}
