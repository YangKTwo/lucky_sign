import 'package:flutter_test/flutter_test.dart';
import 'package:lucky_sign/utils/today_copy.dart';

void main() {
  test('empty checkin is intercepted', () {
    expect(checkinProofError('', false), '请写一句完成感受，或拍一张凭证');
    expect(checkinProofError('   ', false), '请写一句完成感受，或拍一张凭证');
    expect(checkinProofError('完成了', false), isNull);
    expect(checkinProofError('', true), isNull);
  });

  test('midnight rollover compares local date', () {
    expect(dateRolledOver('2026-10-18', DateTime(2026, 10, 19, 0, 1)), isTrue);
    expect(dateRolledOver('2026-10-19', DateTime(2026, 10, 19, 23, 50)), isFalse);
    expect(dateRolledOver(null, DateTime(2026, 10, 19)), isFalse);
  });

  test('countdown copy', () {
    final now = DateTime(2026, 10, 19, 21, 10);
    expect(countdownLabel(now), '距结算还剩 2 小时 50 分');
    expect(countdownLabel(DateTime(2026, 10, 19, 23, 40)), '距结算还剩 20 分钟');
    expect(
      countdownLabel(DateTime(2026, 10, 20, 0, 2), deadline: DateTime(2026, 10, 20, 0, 0)),
      '即将结算',
    );
  });

  test('streak bonus copy', () {
    expect(streakBonusLabel(6), isNull);
    expect(streakBonusLabel(7), '连续满周 +10 分');
    expect(streakBonusLabel(30), '连续满月 +50 分');
  });

  test('circle progress copy', () {
    expect(circleProgressHeadline(3, 5), '今日圈子 3/5 已打卡');
    expect(
      circleProgressDetail(meCompleted: false, waiting: []),
      '就差你了',
    );
    expect(
      circleProgressDetail(meCompleted: true, waiting: ['小明', '小红']),
      '还差 小明、小红',
    );
    expect(
      circleProgressDetail(meCompleted: false, waiting: ['小明']),
      '还差你和小明',
    );
    expect(
      circleProgressDetail(meCompleted: true, waiting: []),
      '全员打卡，漂亮',
    );
  });

  test('rank position', () {
    final items = [
      {'userId': 8},
      {'userId': 3},
      {'userId': 1},
    ];
    expect(compositeRank(items, 3), 2);
    expect(rankPositionLine(2), '你目前综合第 2 名');
    expect(compositeRank(items, 99), isNull);
  });

  test('completed at formats local time', () {
    final dt = DateTime.utc(2026, 10, 19, 13, 8);
    expect(formatCompletedAt(dt.toIso8601String()), contains('完成于'));
  });
}
