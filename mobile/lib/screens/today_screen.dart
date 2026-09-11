import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../widgets/ui_bits.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await ApiClient.instance.getJson('/api/checkin/today');
      if (!mounted) return;
      setState(() => _data = res['data'] as Map<String, dynamic>);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkin() async {
    final textCtrl = TextEditingController();
    XFile? image;
    Uint8List? previewBytes;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
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
                  const Text('凭证会发到社区，大家都能看见', style: TextStyle(color: Color(0xFF8A8078))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(hintText: '可选：写点完成感受'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
                          if (picked == null) return;
                          final bytes = await picked.readAsBytes();
                          setLocal(() {
                            image = picked;
                            previewBytes = bytes;
                          });
                        },
                        icon: const Icon(Icons.photo_outlined),
                        label: Text(image == null ? '相册' : '已选图'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80);
                          if (picked == null) return;
                          final bytes = await picked.readAsBytes();
                          setLocal(() {
                            image = picked;
                            previewBytes = bytes;
                          });
                        },
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('拍照'),
                      ),
                      if (image != null) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => setLocal(() {
                            image = null;
                            previewBytes = null;
                          }),
                          child: const Text('清除'),
                        ),
                      ],
                    ],
                  ),
                  if (previewBytes != null) ...[
                    const SizedBox(height: 12),
                    LocalImagePreview(bytes: previewBytes!),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('提交到社区'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Center(child: Text('取消')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (ok != true) return;
    try {
      final res = await ApiClient.instance.completeCheckin(text: textCtrl.text, image: image);
      if (!mounted) return;
      setState(() => _data = res['data'] as Map<String, dynamic>);
      await _celebrateCheckin(res['data'] as Map<String, dynamic>);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatError(e))),
      );
    }
  }

  Future<void> _celebrateCheckin(Map<String, dynamic> data) async {
    final streak = (data['streakDays'] is num) ? (data['streakDays'] as num).toInt() : 0;
    final next = data['nextTitle']?.toString();
    final daysTo = (data['daysToNextTitle'] is num) ? (data['daysToNextTitle'] as num).toInt() : 0;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('打卡成功'),
        content: Text(
          streak > 1
              ? '连续 $streak 天！凭证已发到社区。${next != null && next.isNotEmpty ? '\n再坚持 $daysTo 天可解锁「$next」。' : ''}'
              : '今日任务完成，凭证已发到社区。',
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('好')),
        ],
      ),
    );
    if (!mounted) return;
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
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null && d == null)
              ErrorRetry(
                message: _error!,
                hint: dormant ? '休眠账号请联系管理员解锁后才能抽签。' : null,
                onRetry: _load,
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
                        onPressed: null,
                        icon: const Icon(Icons.check_circle),
                        label: const Text('今日已完成 ✓'),
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
