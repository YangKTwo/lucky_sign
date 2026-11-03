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
  Map<String, dynamic>? _rank;
  List<Map<String, dynamic>> _calendar = [];
  String? _error;
  bool _loading = true;
  bool _checkingIn = false;
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
      final now = DateTime.now();
      final crossedDay = !TodayCopy.sameDay(_now, now) || TodayCopy.isStaleDraw(_data?['date']?.toString(), now);
      setState(() => _now = now);
      if (crossedDay) {
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
        List<Map<String, dynamic>> calendar = _calendar;
        Map<String, dynamic>? rank = _rank;
        try {
          final calRes = await ApiClient.instance.getJson('/api/checkin/calendar?days=14');
          calendar = (calRes['data']?['days'] as List?)?.cast<Map<String, dynamic>>() ?? calendar;
        } catch (_) {}
        try {
          final rankRes = await ApiClient.instance.getJson('/api/rank');
          rank = rankRes['data'] as Map<String, dynamic>? ?? rank;
        } catch (_) {}
        final fp = jsonEncode({'today': data, 'calendar': calendar, 'rank': rank});
        if (!_gate.noteFingerprint(fp) && _data != null) {
          return;
        }
        setState(() {
          _data = data;
          _calendar = calendar;
          _rank = rank;
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
    if (_checkingIn) return;
    _checkingIn = true;
    final textCtrl = TextEditingController();
    XFile? image;
    Uint8List? previewBytes;
    String? localError;
    var submitting = false;
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> submit() async {
              final text = textCtrl.text.trim();
              if (text.isEmpty && image == null) {
                setLocal(() => localError = '请写一句完成感受，或拍一张凭证');
                return;
              }
              if (text.length > 500) {
                setLocal(() => localError = '打卡内容不能超过 500 字');
                return;
              }
              setLocal(() {
                submitting = true;
                localError = null;
              });
              try {
                final res = await ApiClient.instance.completeCheckin(text: textCtrl.text, image: image);
                if (ctx.mounted) {
                  Navigator.pop(ctx, res['data'] as Map<String, dynamic>);
                }
              } catch (e) {
                if (!ctx.mounted) return;
                setLocal(() {
                  submitting = false;
                  localError = formatError(e);
                });
              }
            }

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
                  const Text('写一句感受或拍一张现场照片，凭证会发到社区', style: TextStyle(color: Color(0xFF8A8078))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textCtrl,
                    maxLines: 3,
                    maxLength: 500,
                    enabled: !submitting,
                    decoration: const InputDecoration(hintText: '写点完成感受，或只拍照也可以'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: submitting
                            ? null
                            : () async {
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
                        onPressed: submitting
                            ? null
                            : () async {
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
                          onPressed: submitting
                              ? null
                              : () => setLocal(() {
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
                  if (localError != null) ...[
                    const SizedBox(height: 12),
                    Text(localError!, style: const TextStyle(color: Color(0xFFC0392B), height: 1.35)),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                      onPressed: submitting ? null : submit,
                      child: Text(submitting ? '提交中…' : '提交到社区'),
                    ),
                  ),
                  TextButton(
                    onPressed: submitting ? null : () => Navigator.pop(ctx),
                    child: const Center(child: Text('取消')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    textCtrl.dispose();
    if (!mounted) {
      return;
    }
    setState(() => _checkingIn = false);
    if (result == null) return;
    setState(() => _data = result);
    _gate.markFresh(jsonEncode({'today': result, 'calendar': _calendar, 'rank': _rank}));
    await _celebrateCheckin(result);
    await _load(force: true);
  }

  Future<void> _celebrateCheckin(Map<String, dynamic> data) async {
    final streak = (data['streakDays'] is num) ? (data['streakDays'] as num).toInt() : 0;
    final next = data['nextTitle']?.toString();
    final daysTo = (data['daysToNextTitle'] is num) ? (data['daysToNextTitle'] as num).toInt() : 0;
    final bonus = (data['streakBonusPoints'] is num) ? (data['streakBonusPoints'] as num).toInt() : 0;
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('打卡成功'),
        content: Text(TodayCopy.celebrate(streak: streak, nextTitle: next, daysTo: daysTo, bonus: bonus) ?? '今日任务完成'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'ok'), child: const Text('好')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'community'),
            child: const Text('去社区看看'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'community') {
      widget.onOpenCommunity?.call();
    }
  }

  double _titleProgress(Map<String, dynamic> d) {
    final total = (d['totalCompletedDays'] is num) ? (d['totalCompletedDays'] as num).toInt() : 0;
    final at = (d['nextTitleAt'] is num) ? (d['nextTitleAt'] as num).toInt() : 0;
    if (at <= 0) return 1;
    return (total / at).clamp(0.0, 1.0);
  }

  int _asInt(dynamic v) => v is num ? v.toInt() : 0;

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final level = d?['level']?.toString();
    final color = AppColors.level(level);
    final completed = d?['status'] == 'COMPLETED';
    final dormant = d?['tag'] == 'DORMANT' || (_error?.contains('休眠') ?? false);
    final members = (_rank?['byComposite'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final myId = ApiClient.instance.userId;
    final pendingNames = members
        .where((m) => m['todayStatus'] != 'COMPLETED' && !(myId != null && m['userId'] is num && (m['userId'] as num).toInt() == myId))
        .map((m) => m['nickname']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    final completedCount = _asInt(_rank?['todayCompletedCount']);
    final memberCount = _asInt(_rank?['memberCount']);
    final circleLine = memberCount > 0
        ? TodayCopy.circleProgress(
            completed: completedCount,
            total: memberCount,
            mineCompleted: completed,
            pendingNames: pendingNames,
          )
        : '';
    final week = TodayCopy.weekCells(_calendar, _now);
    final doneCaption = TodayCopy.completedCaption(d?['completedAt']?.toString());
    final bonus = _asInt(d?['streakBonusPoints']);

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
            if (_error != null && d != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFC0392B))),
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
              _WeekStrip(cells: week),
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
              if (circleLine.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE7DDD2)),
                  ),
                  child: Text(circleLine, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.35)),
                ),
              ],
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
                          TodayCopy.streakNudge(_now, _asInt(d['streakDays'])),
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
                    if (completed && doneCaption != null) ...[
                      const SizedBox(height: 10),
                      Text(doneCaption, style: const TextStyle(color: Color(0xFF6B625A), fontWeight: FontWeight.w700)),
                    ],
                    if (completed && bonus > 0) ...[
                      const SizedBox(height: 6),
                      Text(TodayCopy.streakBonusLine(bonus, _asInt(d['streakDays'])) ?? '',
                          style: const TextStyle(color: AppColors.moss, fontWeight: FontWeight.w700)),
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
                        onPressed: dormant || _checkingIn ? null : _checkin,
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
  const _WeekStrip({required this.cells});
  final List<WeekCell> cells;

  Color _color(WeekCell cell) {
    switch (cell.status) {
      case 'COMPLETED':
        return AppColors.moss;
      case 'MISSED':
        return const Color(0xFFC0392B);
      case 'PENDING':
        return AppColors.accent;
      default:
        return const Color(0xFFD9D0C7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final cell in cells) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: cell.isToday ? const Color(0xFFFFF4E8) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cell.isToday ? AppColors.accent.withValues(alpha: 0.55) : const Color(0xFFE7DDD2),
                ),
              ),
              child: Column(
                children: [
                  Text(cell.label, style: const TextStyle(fontSize: 11, color: Color(0xFF8A8078))),
                  const SizedBox(height: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: _color(cell), shape: BoxShape.circle),
                  ),
                ],
              ),
            ),
          ),
          if (cell != cells.last) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
