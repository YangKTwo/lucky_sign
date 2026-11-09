import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_sign/utils/today_copy.dart';

void main() {
  test('evening countdown warns about breaking streak', () {
    final evening = DateTime(2026, 11, 9, 20, 10);
    expect(
      TodayCopy.countdownLabel(evening, streakDays: 6),
      contains('连续即将断开'),
    );
    expect(
      TodayCopy.countdownLabel(DateTime(2026, 11, 9, 9, 0), streakDays: 6),
      isNot(contains('连续即将断开')),
    );
  });

  test('circle progress just you / remaining names', () {
    expect(
      TodayCopy.circleProgress(meCompleted: false, completed: 3, members: 4, pending: const ['阿饼', '小陈']),
      '就差你了',
    );
    expect(
      TodayCopy.circleProgress(meCompleted: false, completed: 1, members: 4, pending: const ['阿饼', '小陈']),
      '还差 3 人：阿饼、小陈',
    );
    expect(
      TodayCopy.circleProgress(meCompleted: true, completed: 4, members: 4, pending: const []),
      '全员打卡完成',
    );
  });

  test('streak bonus copy for week and month', () {
    expect(TodayCopy.streakBonusPoints(7), 10);
    expect(TodayCopy.streakBonusPoints(30), 50);
    expect(TodayCopy.streakBonus(streakDays: 7, completed: true), contains('满周'));
    expect(TodayCopy.streakBonus(streakDays: 7, completed: false), contains('今天完成'));
    expect(TodayCopy.streakBonus(streakDays: 6, completed: false), isEmpty);
  });

  test('completed at is local clock copy', () {
    final now = DateTime(2026, 11, 9, 21, 4);
    expect(
      TodayCopy.completedAtLabel('2026-11-09T13:04:00Z', now),
      contains('打卡'),
    );
  });

  test('my rank copy', () {
    expect(TodayCopy.myRank(2, 6), '你目前第 2 名 · 共 6 人');
    expect(TodayCopy.myRank(null, 6), isEmpty);
  });

  test('heatmap monday pad', () {
    expect(TodayCopy.mondayPad(DateTime(2026, 11, 9)), 0);
    expect(TodayCopy.mondayPad(DateTime(2026, 11, 10)), 1);
  });
}
