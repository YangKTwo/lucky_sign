class WeekCell {
  const WeekCell({
    required this.label,
    required this.dateKey,
    required this.status,
    required this.isToday,
  });

  final String label;
  final String dateKey;
  final String status;
  final bool isToday;
}

class TodayCopy {
  static const weekLabels = ['一', '二', '三', '四', '五', '六', '日'];

  static String pad2(int n) => n.toString().padLeft(2, '0');

  static String dateKey(DateTime d) => '${d.year}-${pad2(d.month)}-${pad2(d.day)}';

  static bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isStaleDraw(String? drawDate, DateTime now) {
    if (drawDate == null || drawDate.isEmpty) return false;
    final parsed = DateTime.tryParse(drawDate);
    if (parsed == null) return false;
    return !sameDay(parsed, now);
  }

  static DateTime deadlineOf(DateTime now) =>
      DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

  static String countdownLabel(DateTime now) {
    final left = deadlineOf(now).difference(now);
    if (left.isNegative) return '即将结算';
    final h = left.inHours;
    final m = left.inMinutes.remainder(60);
    if (h > 0) return '距结算还剩 $h 小时 $m 分';
    return '距结算还剩 $m 分钟';
  }

  static String streakNudge(DateTime now, int streakDays) {
    final countdown = countdownLabel(now);
    if (now.hour >= 18 && streakDays > 0) {
      return '连续 $streakDays 天还差这一下 · $countdown';
    }
    return countdown;
  }

  static String? celebrate({
    required int streak,
    String? nextTitle,
    int daysTo = 0,
    int bonus = 0,
  }) {
    final bonusLine = streakBonusLine(bonus, streak);
    if (streak > 1) {
      final titleLine = nextTitle != null && nextTitle.isNotEmpty
          ? '\n再坚持 $daysTo 天可解锁「$nextTitle」。'
          : '';
      return '连续 $streak 天！凭证已发到社区。$titleLine${bonusLine == null ? '' : '\n$bonusLine'}';
    }
    return '今日任务完成，凭证已发到社区。${bonusLine == null ? '' : '\n$bonusLine'}';
  }

  static String? streakBonusLine(int bonus, int streak) {
    if (bonus >= 50) return '连续满月 +$bonus 分';
    if (bonus >= 10) return '连续满周 +$bonus 分';
    if (streak > 0 && streak % 30 == 0) return '连续满月 +50 分';
    if (streak > 0 && streak % 7 == 0) return '连续满周 +10 分';
    return null;
  }

  static String? completedCaption(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final match = RegExp(r'T(\d{2}):(\d{2})').firstMatch(iso);
    if (match != null) {
      return '今日 ${match.group(1)}:${match.group(2)} 完成';
    }
    final t = DateTime.tryParse(iso);
    if (t == null) return null;
    final local = t.toLocal();
    return '今日 ${pad2(local.hour)}:${pad2(local.minute)} 完成';
  }

  static String circleProgress({
    required int completed,
    required int total,
    required bool mineCompleted,
    required List<String> pendingNames,
  }) {
    if (total <= 0) return '';
    if (completed >= total) return '全员打卡完成 · $completed/$total';
    if (!mineCompleted && completed == total - 1) {
      return '就差你了 · $completed/$total 已打卡';
    }
    if (pendingNames.isEmpty) return '$completed/$total 已打卡';
    final shown = pendingNames.take(3).join('、');
    final extra = pendingNames.length > 3 ? '等${pendingNames.length}人' : shown;
    final who = pendingNames.length > 3 ? extra : shown;
    return '还差 $who · $completed/$total 已打卡';
  }

  static List<WeekCell> weekCells(List<Map<String, dynamic>> calendar, DateTime now) {
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final byDate = <String, String>{};
    for (final day in calendar) {
      final raw = day['date']?.toString() ?? '';
      if (raw.isEmpty) continue;
      final key = raw.length >= 10 ? raw.substring(0, 10) : raw;
      byDate[key] = day['status']?.toString() ?? 'NONE';
    }
    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final key = dateKey(day);
      return WeekCell(
        label: weekLabels[i],
        dateKey: key,
        status: byDate[key] ?? 'NONE',
        isToday: sameDay(day, now),
      );
    });
  }
}

class RankCopy {
  static String myPosition(int? rank) {
    if (rank == null || rank <= 0) return '';
    return '你目前第 $rank 名';
  }

  static String todayProgress(int completed, int total) {
    if (total <= 0) return '';
    return '今日 $completed/$total 已打卡';
  }
}
