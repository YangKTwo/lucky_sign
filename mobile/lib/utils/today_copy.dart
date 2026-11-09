class TodayCopy {
  static String countdownLabel(DateTime now, {int streakDays = 0}) {
    final deadline = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final left = deadline.difference(now);
    final String base;
    if (left.isNegative) {
      base = '即将结算';
    } else {
      final h = left.inHours;
      final m = left.inMinutes.remainder(60);
      base = h > 0 ? '距结算还剩 $h 小时 $m 分' : '距结算还剩 $m 分钟';
    }
    if (now.hour >= 18 && streakDays > 0) {
      return '连续即将断开 · $base';
    }
    return base;
  }

  static String circleProgress({
    required bool meCompleted,
    required int completed,
    required int members,
    required List<String> pending,
  }) {
    if (members <= 0) return '';
    if (meCompleted) {
      if (completed >= members) return '全员打卡完成';
      if (pending.isEmpty) return '今日已有 $completed/$members 人打卡';
      final names = pending.take(3).join('、');
      return '今日 $completed/$members 人已打卡，还差$names';
    }
    if (completed == members - 1) return '就差你了';
    if (pending.isEmpty) return '今日 $completed/$members 人已打卡';
    final names = pending.take(3).join('、');
    final left = members - completed;
    return '还差 $left 人：$names';
  }

  static int streakBonusPoints(int streakDays) {
    var n = 0;
    if (streakDays > 0 && streakDays % 7 == 0) n += 10;
    if (streakDays > 0 && streakDays % 30 == 0) n += 50;
    return n;
  }

  static String streakBonus({required int streakDays, required bool completed}) {
    final bonus = streakBonusPoints(streakDays);
    if (bonus <= 0) return '';
    final month = streakDays > 0 && streakDays % 30 == 0;
    if (completed) {
      if (month) return '连续 $streakDays 天，满月 +$bonus';
      return '连续 $streakDays 天，满周 +$bonus';
    }
    if (month) return '今天完成可拿满月 +$bonus';
    return '今天完成可拿满周 +$bonus';
  }

  static String completedAtLabel(String? iso, DateTime now) {
    final dt = DateTime.tryParse(iso ?? '')?.toLocal();
    if (dt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    final sameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (sameDay) return '今天 ${two(dt.hour)}:${two(dt.minute)} 打卡';
    return '${dt.month}月${dt.day}日 ${two(dt.hour)}:${two(dt.minute)} 打卡';
  }

  static String myRank(int? rank, int total) {
    if (rank == null || rank <= 0 || total <= 0) return '';
    return '你目前第 $rank 名 · 共 $total 人';
  }

  /// GitHub / 小打卡热力图：把第一天对齐到周一。
  static int mondayPad(DateTime first) => first.weekday - DateTime.monday;
}
