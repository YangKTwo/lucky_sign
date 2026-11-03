import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_sign/utils/today_copy.dart';

void main() {
  test('countdown and evening streak nudge', () {
    final morning = DateTime(2026, 11, 3, 9, 5);
    expect(TodayCopy.countdownLabel(morning), '距结算还剩 14 小时 55 分');
    expect(TodayCopy.streakNudge(morning, 4), '距结算还剩 14 小时 55 分');

    final evening = DateTime(2026, 11, 3, 20, 10);
    expect(TodayCopy.streakNudge(evening, 4), contains('连续 4 天还差这一下'));
    expect(TodayCopy.isStaleDraw('2026-11-02', evening), isTrue);
    expect(TodayCopy.isStaleDraw('2026-11-03', evening), isFalse);
  });

  test('circle progress copy', () {
    expect(
      TodayCopy.circleProgress(completed: 4, total: 5, mineCompleted: false, pendingNames: ['我']),
      '就差你了 · 4/5 已打卡',
    );
    expect(
      TodayCopy.circleProgress(completed: 3, total: 5, mineCompleted: true, pendingNames: ['小明', '小红']),
      '还差 小明、小红 · 3/5 已打卡',
    );
    expect(
      TodayCopy.circleProgress(completed: 5, total: 5, mineCompleted: true, pendingNames: []),
      '全员打卡完成 · 5/5',
    );
  });

  test('week strip maps Monday to Sunday', () {
    final now = DateTime(2026, 11, 3); // Tuesday
    final cells = TodayCopy.weekCells([
      {'date': '2026-11-02', 'status': 'COMPLETED'},
      {'date': '2026-11-03', 'status': 'PENDING'},
    ], now);
    expect(cells.length, 7);
    expect(cells.first.label, '一');
    expect(cells.first.dateKey, '2026-11-02');
    expect(cells.first.status, 'COMPLETED');
    expect(cells[1].isToday, isTrue);
    expect(cells[1].status, 'PENDING');
  });

  test('celebrate and completion caption', () {
    expect(TodayCopy.celebrate(streak: 7, bonus: 10), contains('连续满周 +10 分'));
    expect(TodayCopy.celebrate(streak: 30, bonus: 50), contains('连续满月 +50 分'));
    expect(TodayCopy.completedCaption('2026-11-03T14:32:00+08:00'), '今日 14:32 完成');
    expect(RankCopy.myPosition(3), '你目前第 3 名');
    expect(RankCopy.todayProgress(2, 5), '今日 2/5 已打卡');
  });
}
