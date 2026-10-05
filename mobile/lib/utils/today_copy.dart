bool canSubmitCheckin({required String text, required bool hasImage}) {
  return text.trim().isNotEmpty || hasImage;
}

const int maxCheckinImageBytes = 5 * 1024 * 1024;

String circleProgressMessage({
  required int completed,
  required int total,
  required List<String> pendingNicknames,
  required bool justYou,
}) {
  if (total <= 0) return '圈子还没有成员';
  if (completed >= total) return '全员打卡完成';
  if (justYou) return '就差你了';
  if (pendingNicknames.isEmpty) return '已打卡 $completed/$total';
  final shown = pendingNicknames.take(3).join('、');
  final extra = pendingNicknames.length > 3 ? '等${pendingNicknames.length}人' : '';
  return '还差$shown$extra';
}

String? formatCompletedAt(String? raw, {DateTime? now}) {
  final dt = DateTime.tryParse(raw ?? '')?.toLocal();
  if (dt == null) return null;
  final n = now ?? DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  final time = '${two(dt.hour)}:${two(dt.minute)}';
  final sameDay = dt.year == n.year && dt.month == n.month && dt.day == n.day;
  if (sameDay) return '今天 $time 打卡';
  return '${dt.month}/${dt.day} $time 打卡';
}

String celebrateCheckinBody({
  required int streak,
  String? nextTitle,
  int daysToNext = 0,
}) {
  final bonus = streakBonusCopy(streak);
  final titleHint = (nextTitle != null && nextTitle.isNotEmpty && daysToNext > 0)
      ? '再坚持 $daysToNext 天可解锁「$nextTitle」。'
      : '';
  final parts = <String>[
    if (streak > 1) '连续 $streak 天！凭证已发到社区。' else '今日任务完成，凭证已发到社区。',
    if (bonus.isNotEmpty) bonus,
    if (titleHint.isNotEmpty) titleHint,
  ];
  return parts.join('\n');
}

String streakBonusCopy(int streak) {
  if (streak <= 0) return '';
  if (streak % 30 == 0) return '满月连续 +50 分';
  if (streak % 7 == 0) return '满周连续 +10 分';
  return '';
}

String todayDateKey(DateTime n) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)}';
}
