String localDateKey(DateTime t) {
  final y = t.year.toString().padLeft(4, '0');
  final m = t.month.toString().padLeft(2, '0');
  final d = t.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

bool dateRolledOver(String? shownDate, DateTime now) {
  if (shownDate == null || shownDate.isEmpty) return false;
  return shownDate != localDateKey(now);
}

String countdownLabel(DateTime now, {DateTime? deadline}) {
  final end = deadline ?? DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
  final left = end.difference(now);
  if (left.isNegative) return '即将结算';
  final h = left.inHours;
  final m = left.inMinutes.remainder(60);
  if (h > 0) return '距结算还剩 $h 小时 $m 分';
  return '距结算还剩 $m 分钟';
}

String? checkinProofError(String text, bool hasImage) {
  if (text.trim().isEmpty && !hasImage) {
    return '请写一句完成感受，或拍一张凭证';
  }
  return null;
}

String? streakBonusLabel(int streakDays) {
  final parts = <String>[];
  if (streakDays > 0 && streakDays % 7 == 0) {
    parts.add('连续满周 +10 分');
  }
  if (streakDays > 0 && streakDays % 30 == 0) {
    parts.add('连续满月 +50 分');
  }
  if (parts.isEmpty) return null;
  return parts.join('，');
}

String circleProgressHeadline(int completed, int total) {
  return '今日圈子 $completed/$total 已打卡';
}

String circleProgressDetail({
  required bool meCompleted,
  required List<String> waiting,
}) {
  if (waiting.isEmpty) {
    return meCompleted ? '全员打卡，漂亮' : '就差你了';
  }
  final names = waiting.take(3).join('、');
  final extra = waiting.length > 3 ? ' 等${waiting.length}人' : '';
  if (meCompleted) return '还差 $names$extra';
  return '还差你和$names$extra';
}

int? compositeRank(List<Map<String, dynamic>> items, int? userId) {
  if (userId == null) return null;
  final idx = items.indexWhere((m) {
    final uid = m['userId'];
    return uid is num && uid.toInt() == userId;
  });
  return idx < 0 ? null : idx + 1;
}

String rankPositionLine(int rank) => '你目前综合第 $rank 名';

String? formatCompletedAt(dynamic raw, {DateTime? now}) {
  DateTime? dt;
  if (raw is DateTime) {
    dt = raw;
  } else if (raw is String) {
    dt = DateTime.tryParse(raw);
  } else if (raw is num) {
    final n = raw.toInt();
    dt = DateTime.fromMillisecondsSinceEpoch(n > 9999999999 ? n : n * 1000, isUtc: true);
  }
  if (dt == null) return null;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '完成于 ${two(local.hour)}:${two(local.minute)}';
}

const weekDayLabels = ['一', '二', '三', '四', '五', '六', '日'];

String weekDayLabel(DateTime date) => weekDayLabels[date.weekday - 1];
