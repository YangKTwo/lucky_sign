import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../theme.dart';
import '../utils/checkin_proof.dart';
import '../utils/errors.dart';
import '../utils/refresh_gate.dart';
import '../utils/today_copy.dart';
import '../widgets/ui_bits.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, this.isActive = true, this.onOpenCommunity});

  final bool isActive;
  final VoidCallback? onOpenCommunity;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  Timer? _clock;
  DateTime _now = DateTime.now();
  final _gate = RefreshGate(minInterval: const Duration(seconds: 15));

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _load();
    }
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      final next = DateTime.now();
      final crossed = DateTime(_now.year, _now.month, _now.day) != DateTime(next.year, next.month, next.day);
      setState(() => _now = next);
      if (crossed) {
        _load(force: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _load();
    }
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load({bool force = false}) {
    return _gate.run(() async {
      if (!mounted) return;
      final showSpinner = _data == null;
      if (showSpinner) {
        setState(() {
          _loading = true;
          _error = null;
        });
      }
      try {
        final res = await ApiClient.instance.getJson('/api/checkin/today');
        if (!mounted) return;
        final data = res['data'] as Map<String, dynamic>;
        final fp = jsonEncode(data);
        if (!_gate.noteFingerprint(fp) && _data != null) {
          return;
        }
        setState(() {
          _data = data;
          _error = null;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = formatError(e));
      } finally {
        if (mounted && _loading) setState(() => _loading = false);
      }
    }, force: force);
  }

  Future<void> _checkin() async {
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => const _CheckinSheet(),
    );
    if (data == null || !mounted) return;
    setState(() => _data = data);
    _gate.markFresh(jsonEncode(data));
    await _celebrateCheckin(data);
  }

  Future<void> _celebrateCheckin(Map<String, dynamic> data) async {
    final streak = (data['streakDays'] is num) ? (data['streakDays'] as num).toInt() : 0;
    final next = data['nextTitle']?.toString();
    final daysTo = (data['daysToNextTitle'] is num) ? (data['daysToNextTitle'] as num).toInt() : 0;
    if (!mounted) return;
    final bonus = TodayCopy.streakBonus(streakDays: streak, completed: true);
    final goCommunity = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('打卡成功'),
        content: Text(
          [
            if (streak > 1) '连续 $streak 天！凭证已发到社区。' else '今日任务完成，凭证已发到社区。',
            if (bonus.isNotEmpty) bonus,
            if (next != null && next.isNotEmpty) '再坚持 $daysTo 天可解锁「$next」。',
          ].join('\n'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('好')),
          if (widget.onOpenCommunity != null)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('去社区看看'),
            ),
        ],
      ),
    );
    if (!mounted) return;
    if (goCommunity == true) {
      widget.onOpenCommunity?.call();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('打卡成功，已发到社区')));
  }

  double _titleProgress(Map<String, dynamic> d) {
    final total = (d['totalCompletedDays'] is num) ? (d['totalCompletedDays'] as num).toInt() : 0;
    final at = (d['nextTitleAt'] is num) ? (d['nextTitleAt'] as num).toInt() : 0;
    if (at <= 0) return 1;
    return (total / at).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final level = d?['level']?.toString();
    final color = AppColors.level(level);
    final completed = d?['status'] == 'COMPLETED';
    final dormant = d?['tag'] == 'DORMANT' || (_error?.contains('休眠') ?? false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('今日运势'),
        actions: [
          IconButton(onPressed: () => _load(force: true), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null && d == null)
              ErrorRetry(
                message: _error!,
                hint: dormant ? '休眠账号请联系管理员解锁后才能抽签。' : null,
                onRetry: () => _load(force: true),
              ),
            if (d != null) ...[
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.72)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(AppColors.levelEmoji(level), style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 8),
                        Text(
                          '${d['level']} · ${d['levelName']}',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        const Spacer(),
                        if (d['luckyStar'] == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                            child: const Text('幸运星 ×2', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        const SizedBox(width: 6),
                        TagChip(d['tag']?.toString()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      d['fortuneText']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.25),
                    ),
                    const SizedBox(height: 10),
                    Text(d['date']?.toString() ?? '', style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  StatTile(label: '积分', value: '${d['points']}'),
                  const SizedBox(width: 8),
                  StatTile(label: '连续', value: '${d['streakDays']}天'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE7DDD2)),
                      ),
                      child: Column(
                        children: [
                          Text(
                            d['title']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.ink),
                          ),
                          const SizedBox(height: 2),
                          const Text('称号', style: TextStyle(fontSize: 12, color: Color(0xFF8A8078))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _WeekStrip(days: (d['weekDays'] as List?)?.cast<Map<String, dynamic>>() ?? const []),
              const SizedBox(height: 12),
              _CirclePulseCard(
                meCompleted: completed,
                completed: (d['todayCompletedCount'] as num?)?.toInt() ?? 0,
                members: (d['circleMemberCount'] as num?)?.toInt() ?? 0,
                pending: (d['pendingNicknames'] as List?)?.map((e) => e.toString()).toList() ?? const [],
              ),
              const SizedBox(height: 16),
              if (!completed && !dormant) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: _now.hour >= 18 ? const Color(0xFFFFF1E6) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _now.hour >= 18 ? const Color(0xFFE8A87C) : const Color(0xFFE7DDD2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _now.hour >= 18 ? Icons.warning_amber_rounded : Icons.schedule,
                        color: _now.hour >= 18 ? AppColors.accent : AppColors.moss,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          TodayCopy.countdownLabel(
                            _now,
                            streakDays: (d['streakDays'] as num?)?.toInt() ?? 0,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (d['nextTitle'] != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE7DDD2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '下一称号「${d['nextTitle']}」还差 ${d['daysToNextTitle']} 天',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: _titleProgress(d),
                          backgroundColor: const Color(0xFFF0EAE3),
                          color: AppColors.moss,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE7DDD2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('今日任务', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(d['taskContent']?.toString() ?? '', style: const TextStyle(fontSize: 16, height: 1.4)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.stars_rounded, color: color, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '完成可得 ${d['rewardPoints']} 分${d['luckyStar'] == true ? '（幸运星已翻倍）' : ''}',
                            style: TextStyle(color: color, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    if (((d['streakBonusPoints'] as num?)?.toInt() ?? 0) > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        TodayCopy.streakBonus(
                          streakDays: completed
                              ? ((d['streakDays'] as num?)?.toInt() ?? 0)
                              : _streakMatchingBonus(d),
                          completed: completed,
                        ),
                        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                    if (completed && TodayCopy.completedAtLabel(d['completedAt']?.toString(), _now).isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        TodayCopy.completedAtLabel(d['completedAt']?.toString(), _now),
                        style: const TextStyle(fontSize: 13, color: Color(0xFF8A8078)),
                      ),
                    ],
                    if (completed && (d['textContent']?.toString().isNotEmpty ?? false)) ...[
                      const SizedBox(height: 12),
                      Text(d['textContent'].toString(), style: const TextStyle(color: Color(0xFF6B625A), height: 1.35)),
                    ],
                    if (completed && imageFullUrl(d['imageUrl']?.toString()).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      NetworkImageBox(url: imageFullUrl(d['imageUrl']?.toString())),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 52,
                child: completed
                    ? FilledButton.icon(
                        onPressed: widget.onOpenCommunity,
                        icon: const Icon(Icons.forum_outlined),
                        label: const Text('今日已完成 · 去社区'),
                      )
                    : FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: dormant ? null : _checkin,
                        child: Text(dormant ? '休眠中，无法打卡' : '打卡完成任务'),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _streakMatchingBonus(Map<String, dynamic> d) {
    final current = (d['streakDays'] as num?)?.toInt() ?? 0;
    final bonus = (d['streakBonusPoints'] as num?)?.toInt() ?? 0;
    if (bonus >= 50) {
      final next = current + 1;
      return next % 30 == 0 ? next : 30;
    }
    final next = current + 1;
    return next % 7 == 0 ? next : 7;
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});
  final List<Map<String, dynamic>> days;

  Color _color(String? status) {
    switch (status) {
      case 'COMPLETED':
        return AppColors.moss;
      case 'MISSED':
        return const Color(0xFFE2C8BC);
      case 'PENDING':
        return AppColors.gold;
      default:
        return const Color(0xFFF0EAE3);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('本周', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < days.length && i < 7; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        height: 28,
                        decoration: BoxDecoration(
                          color: _color(days[i]['status']?.toString()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        () {
                          final dt = DateTime.tryParse(days[i]['date']?.toString() ?? '');
                          if (dt == null) return labels[i.clamp(0, 6)];
                          return labels[dt.weekday - 1];
                        }(),
                        style: const TextStyle(fontSize: 11, color: Color(0xFF8A8078)),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CirclePulseCard extends StatelessWidget {
  const _CirclePulseCard({
    required this.meCompleted,
    required this.completed,
    required this.members,
    required this.pending,
  });

  final bool meCompleted;
  final int completed;
  final int members;
  final List<String> pending;

  @override
  Widget build(BuildContext context) {
    final copy = TodayCopy.circleProgress(
      meCompleted: meCompleted,
      completed: completed,
      members: members,
      pending: pending,
    );
    if (copy.isEmpty) return const SizedBox.shrink();
    final justYou = copy == '就差你了';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: justYou ? const Color(0xFFFFF1E6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: justYou ? const Color(0xFFE8A87C) : const Color(0xFFE7DDD2)),
      ),
      child: Row(
        children: [
          Icon(
            justYou ? Icons.diversity_3 : Icons.groups_outlined,
            color: justYou ? AppColors.accent : AppColors.moss,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(copy, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _CheckinSheet extends StatefulWidget {
  const _CheckinSheet();

  @override
  State<_CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends State<_CheckinSheet> {
  final _textCtrl = TextEditingController();
  XFile? _image;
  Uint8List? _previewBytes;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final sizeErr = checkinImageSizeError(bytes.length);
    if (!mounted) return;
    if (sizeErr != null) {
      setState(() => _error = sizeErr);
      return;
    }
    setState(() {
      _image = picked;
      _previewBytes = bytes;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final err = checkinProofError(text: _textCtrl.text, hasImage: _image != null);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.completeCheckin(text: _textCtrl.text, image: _image);
      if (!mounted) return;
      Navigator.pop(context, res['data'] as Map<String, dynamic>);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = formatError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE0D6CC), borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('完成今天的任务', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('写一句感受，或拍一张完成瞬间。凭证会发到社区。', style: TextStyle(color: Color(0xFF8A8078))),
          const SizedBox(height: 16),
          TextField(
            controller: _textCtrl,
            maxLines: 3,
            maxLength: 500,
            enabled: !_submitting,
            decoration: const InputDecoration(hintText: '可选：写点完成感受'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _submitting ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_outlined),
                label: Text(_image == null ? '相册' : '已选图'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _submitting ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('拍照'),
              ),
              if (_image != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => setState(() {
                            _image = null;
                            _previewBytes = null;
                          }),
                  child: const Text('清除'),
                ),
              ],
            ],
          ),
          if (_previewBytes != null) ...[
            const SizedBox(height: 12),
            LocalImagePreview(bytes: _previewBytes!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Color(0xFFC0392B))),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '正在提交' : '提交到社区'),
            ),
          ),
          TextButton(
            onPressed: _submitting ? null : () => Navigator.pop(context),
            child: const Center(child: Text('取消')),
          ),
        ],
      ),
    );
  }
}
