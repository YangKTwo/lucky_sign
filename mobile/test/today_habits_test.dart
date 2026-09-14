import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_sign/utils/today_habits.dart';

void main() {
  test('empty checkin proof is rejected', () {
    expect(hasCheckinProof(text: '', hasImage: false), isFalse);
    expect(hasCheckinProof(text: '   ', hasImage: false), isFalse);
    expect(hasCheckinProof(text: '完成了', hasImage: false), isTrue);
    expect(hasCheckinProof(text: '', hasImage: true), isTrue);
  });

  test('countdown labels remaining time', () {
    final now = DateTime(2026, 9, 14, 20, 10);
    expect(countdownLabel(now), '距结算还剩 3 小时 50 分');
    expect(countdownLabel(DateTime(2026, 9, 14, 23, 50)), '距结算还剩 10 分钟');
  });

  test('streak bonus copy matches backend cadence', () {
    expect(streakBonusMessage(6), isNull);
    expect(streakBonusMessage(7), contains('+10'));
    expect(streakBonusMessage(30), contains('+50'));
    expect(streakBonusMessage(210), contains('+10'));
    expect(streakBonusMessage(210), contains('+50'));
  });

  test('circle pulse copy covers FOMO and all-done', () {
    expect(
      circlePulseCopy(
        memberCount: 4,
        completedCount: 3,
        doneNicknames: const ['阿明', '小红', '石头'],
        iCompleted: false,
      ),
      '就差你了 · 3/4 已打卡',
    );
    expect(
      circlePulseCopy(
        memberCount: 3,
        completedCount: 3,
        doneNicknames: const ['阿明', '小红', '我'],
        iCompleted: true,
      ),
      '全员打卡完成 · 3/3',
    );
    expect(weekProgressLabel(4), '本周 4/7');
  });
}
