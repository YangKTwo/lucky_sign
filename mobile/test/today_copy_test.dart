import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_sign/utils/today_copy.dart';

void main() {
  test('empty checkin is rejected', () {
    expect(canSubmitCheckin(text: '', hasImage: false), isFalse);
    expect(canSubmitCheckin(text: '   ', hasImage: false), isFalse);
    expect(canSubmitCheckin(text: '完成了', hasImage: false), isTrue);
    expect(canSubmitCheckin(text: '', hasImage: true), isTrue);
  });

  test('circle progress copy', () {
    expect(
      circleProgressMessage(completed: 0, total: 0, pendingNicknames: const [], justYou: false),
      '圈子还没有成员',
    );
    expect(
      circleProgressMessage(completed: 3, total: 3, pendingNicknames: const [], justYou: false),
      '全员打卡完成',
    );
    expect(
      circleProgressMessage(completed: 2, total: 3, pendingNicknames: const [], justYou: true),
      '就差你了',
    );
    expect(
      circleProgressMessage(
        completed: 1,
        total: 3,
        pendingNicknames: const ['小明', '小红'],
        justYou: false,
      ),
      '还差小明、小红',
    );
  });

  test('completed at and streak bonus', () {
    final now = DateTime(2026, 10, 5, 21, 10);
    expect(formatCompletedAt('2026-10-05T13:32:00', now: now), '今天 13:32 打卡');
    expect(streakBonusCopy(7), '满周连续 +10 分');
    expect(streakBonusCopy(30), '满月连续 +50 分');
    expect(streakBonusCopy(4), '');
    expect(
      celebrateCheckinBody(streak: 7, nextTitle: '坚持勇士', daysToNext: 3),
      contains('满周连续 +10 分'),
    );
  });

  test('today date key pads month and day', () {
    expect(todayDateKey(DateTime(2026, 10, 5)), '2026-10-05');
  });
}
