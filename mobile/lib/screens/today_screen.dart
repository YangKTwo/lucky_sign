import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../theme.dart';
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
      final crossed = todayDateKey(next) != todayDateKey(_now);
      final stale = _data != null && _data!['date']?.toString() != todayDateKey(next);
      setState(() => _now = next);
      if (crossed || stale) {
        _load(force: true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      final stale = _data != null && _data!['date']?.toString() != todayDateKey(DateTime.now());
      _load(force: stale);
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
    final goCommunity = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('打卡成功'),
        content: Text(celebrateCheckinBody(streak: streak, nextTitle: next, daysToNext: daysTo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('去社区看看'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('好')),
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

  DateTime get _deadline {
    final n = _now;
    return DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
  }

  String _countdownLabel() {
    final left = _deadline.difference(_now);
    if (left.isNegative) return '即将结算';
    final h = left.inHours;
    final m = left.inMinutes.remainder(60);
    if (h > 0) return '距结算还剩 $h 小时 $m 分';
    return '距结算还剩 $m 分钟';
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
              _CircleProgressCard(progress: d['circleProgress'] as Map<String, dynamic>?),
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
                          _now.hour >= 18 && ((d['streakDays'] as num?)?.toInt() ?? 0) > 0
                              ? '连续即将断开 · ${_countdownLabel()}'
                              : _countdownLabel(),
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
                        Text(
                          '完成可得 ${d['rewardPoints']} 分${d['luckyStar'] == true ? '（幸运星已翻倍）' : ''}',
                          style: TextStyle(color: color, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (completed) ...[
                      const SizedBox(height: 12),
                      Text(
                        formatCompletedAt(d['completedAt']?.toString(), now: _now) ?? '今日已打卡',
                        style: const TextStyle(fontSize: 13, color: AppColors.moss, fontWeight: FontWeight.w700),
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
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.days});
  final List<Map<String, dynamic>> days;

  static const _labels = ['一', '二', '三', '四', '五', '六', '日'];

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
    if (days.length != 7) return const SizedBox.shrink();
    return Container(
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
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Column(
                    children: [
                      Text(_labels[i], style: const TextStyle(fontSize: 11, color: Color(0xFF8A8078))),
                      const SizedBox(height: 6),
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _color(days[i]['status']?.toString()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: days[i]['status'] == 'COMPLETED'
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleProgressCard extends StatelessWidget {
  const _CircleProgressCard({required this.progress});
  final Map<String, dynamic>? progress;

  @override
  Widget build(BuildContext context) {
    final p = progress;
    if (p == null) return const SizedBox.shrink();
    final completed = (p['completed'] is num) ? (p['completed'] as num).toInt() : 0;
    final total = (p['total'] is num) ? (p['total'] as num).toInt() : 0;
    final pending = (p['pendingNicknames'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final justYou = p['justYou'] == true;
    final message = circleProgressMessage(
      completed: completed,
      total: total,
      pendingNicknames: pending,
      justYou: justYou,
    );
    final ratio = total <= 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: justYou ? const Color(0xFFFFF1E6) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: justYou ? const Color(0xFFE8A87C) : const Color(0xFFE7DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            total > 0 ? '圈子打卡 $completed/$total' : '圈子打卡',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ratio,
              backgroundColor: const Color(0xFFF0EAE3),
              color: justYou ? AppColors.accent : AppColors.moss,
            ),
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF6B625A), height: 1.35)),
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
    if (bytes.length > maxCheckinImageBytes) {
      if (!mounted) return;
      setState(() => _error = '图片不能超过 5MB');
      return;
    }
    setState(() {
      _image = picked;
      _previewBytes = bytes;
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!canSubmitCheckin(text: _textCtrl.text, hasImage: _image != null)) {
      setState(() => _error = '请写点感受或选一张图');
      return;
    }
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
          const Text('完成打卡', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('写点感受或拍一张，凭证会发到社区', style: TextStyle(color: Color(0xFF8A8078))),
          const SizedBox(height: 16),
          TextField(
            controller: _textCtrl,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(hintText: '写点完成感受，或配一张图'),
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
              child: Text(_submitting ? '提交中…' : '提交到社区'),
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
