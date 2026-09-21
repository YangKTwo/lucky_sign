import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_sign/utils/today_habits.dart';

void main() {
  test('empty checkin needs text or photo', () {
    expect(hasCheckinProof(text: '  ', hasImage: false), isFalse);
    expect(hasCheckinProof(text: '完成了', hasImage: false), isTrue);
    expect(hasCheckinProof(text: '', hasImage: true), isTrue);
  });

  test('countdown and week labels', () {
    final now = DateTime(2026, 9, 21, 20, 15);
    expect(countdownLabel(now), '距结算还剩 3 小时 45 分');
    expect(weekProgressLabel(5), '本周 5/7');
  });

  test('streak bonus copy', () {
    expect(streakBonusMessage(7), contains('+10'));
    expect(streakBonusMessage(30), contains('+50'));
    expect(celebrateBody(streak: 7), contains('额外 +10'));
  });

  test('circle pulse highlights last person and remaining names', () {
    expect(
      circlePulseCopy(
        memberCount: 4,
        completedCount: 3,
        doneNicknames: const ['阿签', '小周'],
        iCompleted: false,
      ),
      contains('就差你了'),
    );
    expect(
      circlePulseCopy(
        memberCount: 4,
        completedCount: 1,
        doneNicknames: const ['阿签'],
        pendingNicknames: const ['小周', '小陈'],
        iCompleted: false,
      ),
      contains('还差小周、小陈'),
    );
    expect(
      circlePulseCopy(
        memberCount: 3,
        completedCount: 3,
        doneNicknames: const ['阿签', '小周', '小陈'],
        iCompleted: true,
      ),
      contains('全员打卡完成'),
    );
  });

  test('checked-in time formats local clock', () {
    final dt = DateTime(2026, 9, 21, 8, 5);
    expect(formatCheckedInHm(dt), '08:05');
    expect(parseCheckedInAt('2026-09-21T00:05:00Z')?.isUtc, isFalse);
  });
}
