/// 今日页轻量文案与校验（小打卡 / Duolingo / BeReal 风格，不引入新依赖）。
bool hasCheckinProof({required String text, required bool hasImage}) {
  return text.trim().isNotEmpty || hasImage;
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

String? streakBonusMessage(int streak) {
  if (streak <= 0) return null;
  final week = streak % 7 == 0;
  final month = streak % 30 == 0;
  if (week && month) {
    return '连续 $streak 天！额外 +10 和 +50 分已到账';
  }
  if (month) {
    return '连续 $streak 天！额外 +50 分已到账';
  }
  if (week) {
    return '连续满一周！额外 +10 分已到账';
  }
  return null;
}

String celebrateBody({
  required int streak,
  String? nextTitle,
  int daysToNext = 0,
}) {
  final bonus = streakBonusMessage(streak);
  final titleBit = (nextTitle != null && nextTitle.isNotEmpty)
      ? '\n再坚持 $daysToNext 天可解锁「$nextTitle」。'
      : '';
  if (streak > 1) {
    final head = bonus ?? '连续 $streak 天！凭证已发到社区。';
    return '$head$titleBit';
  }
  if (bonus != null) {
    return '$bonus$titleBit';
  }
  return '今日任务完成，凭证已发到社区。';
}

String circlePulseCopy({
  required int memberCount,
  required int completedCount,
  required List<String> doneNicknames,
  required bool iCompleted,
}) {
  if (memberCount <= 0) {
    return '圈子今日进度会显示在这里';
  }
  final ratio = '$completedCount/$memberCount';
  if (completedCount >= memberCount) {
    return '全员打卡完成 · $ratio';
  }
  if (!iCompleted && completedCount == memberCount - 1 && memberCount > 1) {
    return '就差你了 · $ratio 已打卡';
  }
  if (doneNicknames.isEmpty) {
    return '今日 $ratio 人已打卡';
  }
  final shown = doneNicknames.take(3).join('、');
  final extra = doneNicknames.length > 3 ? ' 等' : '';
  return '$shown$extra已打卡 · $ratio';
}

String weekProgressLabel(int completedDays) {
  final n = completedDays.clamp(0, 7);
  return '本周 $n/7';
}

DateTime? parseCheckedInAt(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) {
    final ms = raw > 20000000000 ? raw : raw * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
  }
  return DateTime.tryParse(raw.toString())?.toLocal();
}
