import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../widgets/ui_bits.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _circle;
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _calendar = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ApiClient.instance.getJson('/api/user/profile');
      final history = await ApiClient.instance.getJson('/api/checkin/history');
      Map<String, dynamic>? circle;
      List<Map<String, dynamic>> calendar = [];
      try {
        final circleRes = await ApiClient.instance.getJson('/api/circle/me');
        circle = circleRes['data'] as Map<String, dynamic>?;
      } catch (_) {}
      try {
        final calRes = await ApiClient.instance.getJson('/api/checkin/calendar?days=84');
        calendar = (calRes['data']['days'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      } catch (_) {}
      if (!mounted) return;
      final data = profile['data'] as Map<String, dynamic>;
      final id = data['id'];
      if (id is int) {
        await ApiClient.instance.saveUserId(id);
      } else if (id is num) {
        await ApiClient.instance.saveUserId(id.toInt());
      }
      setState(() {
        _profile = data;
        _circle = circle;
        _history = (history['data']['items'] as List).cast<Map<String, dynamic>>();
        _calendar = calendar;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatError(e));
    }
  }

  Future<void> _changeAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    try {
      final res = await ApiClient.instance.uploadAvatar(picked);
      if (!mounted) return;
      setState(() => _profile = res['data'] as Map<String, dynamic>);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('头像已更新')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatError(e))),
      );
    }
  }

  Future<void> _editNickname() async {
    final p = _profile;
    if (p == null) return;
    final ctrl = TextEditingController(text: p['nickname']?.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: '昵称')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('保存')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty) return;
    try {
      final res = await ApiClient.instance.putJson('/api/user/profile', {'nickname': ctrl.text.trim()});
      if (!mounted) return;
      setState(() => _profile = res['data'] as Map<String, dynamic>);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(formatError(e))));
    }
  }

  Future<void> _openFeedback() async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _FeedbackSheet(),
    );
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已收到，感谢反馈')));
    }
  }

  Future<void> _copyInvite() async {
    final code = _circle?['inviteCode']?.toString() ?? '';
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('邀请码已复制')));
  }

  Future<void> _changePassword() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => const _PasswordSheet(),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('密码已更新')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            if (_error != null && p == null)
              ErrorRetry(message: _error!, onRetry: _load)
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFC0392B))),
              ),
            if (p != null) ...[
              _ProfileHeader(profile: p, onEdit: _editNickname, onAvatar: _changeAvatar),
              if (p['tag'] == 'DORMANT') ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2622),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    '账号已休眠：可看社区，不能发言/抽签。请联系管理员解锁。',
                    style: TextStyle(color: Colors.white, height: 1.4, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  StatTile(label: '总积分', value: '${p['points']}'),
                  const SizedBox(width: 10),
                  StatTile(label: '连续签到', value: '${p['streakDays']}'),
                  const SizedBox(width: 10),
                  StatTile(label: '累计完成', value: '${p['totalCompletedDays']}'),
                ],
              ),
              const SizedBox(height: 16),
              if (_calendar.isNotEmpty) ...[
                const Text('近 12 周打卡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _StreakHeatmap(days: _calendar),
                const SizedBox(height: 16),
              ],
              const Text('圈子与账号', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SettingsTile(
                icon: Icons.group_outlined,
                title: _circle?['name']?.toString() ?? '小圈子',
                subtitle: _circle?['inviteCode'] == null
                    ? '邀请码加载失败，下拉刷新'
                    : '邀请码 ${_circle!['inviteCode']} · ${_circle!['memberCount']}/${_circle!['maxMembers']} 人 · 点此复制',
                onTap: _copyInvite,
              ),
              const SizedBox(height: 10),
              SettingsTile(
                icon: Icons.lock_reset_outlined,
                title: '修改密码',
                subtitle: '需要验证当前密码',
                onTap: _changePassword,
              ),
              const SizedBox(height: 10),
              _FeedbackEntry(onTap: _openFeedback),
              const SizedBox(height: 28),
              const Row(
                children: [
                  Text('历史签到', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  Spacer(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _history.isEmpty ? '完成打卡后会出现在这里' : '最近 ${_history.take(30).length} 条',
                style: const TextStyle(fontSize: 13, color: Color(0xFF8A8078)),
              ),
              const SizedBox(height: 12),
              if (_history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: Text('还没有打卡记录', style: TextStyle(color: Color(0xFF8A8078)))),
                )
              else
                ..._history.take(30).map((h) => _HistoryRow(item: h)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8A4030),
                    side: const BorderSide(color: Color(0xFFE2C8BC)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => logoutAndGoLogin(context),
                  child: const Text('退出登录'),
                ),
              ),
            ] else if (_error == null)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile, required this.onEdit, required this.onAvatar});
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final nickname = profile['nickname']?.toString() ?? '';
    final title = profile['title']?.toString() ?? '';
    final email = profile['email']?.toString() ?? '';
    final tag = profile['tag']?.toString();
    final avatarUrl = profile['avatarUrl']?.toString();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF254F44), Color(0xFF3A7A64), Color(0xFF4E9478)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onAvatar,
                child: Stack(
                  children: [
                    UserAvatar(nickname: nickname, avatarUrl: avatarUrl, radius: 34),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, size: 14, color: AppColors.moss),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nickname,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: onEdit,
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                          tooltip: '修改昵称',
                        ),
                      ],
                    ),
                    if (title.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(title, style: const TextStyle(color: Color(0xFFE8F5EF), fontWeight: FontWeight.w700, fontSize: 14)),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TagChip(tag),
                        Text(email, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('点头像可更换图片', style: TextStyle(color: Colors.white54, fontSize: 11)),
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final level = item['level']?.toString();
    final img = imageFullUrl(item['imageUrl']?.toString());
    final avg = item['avgScore'];
    final count = item['ratingCount'] is num ? (item['ratingCount'] as num).toInt() : 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.level(level),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              level ?? '-',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['date']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  item['taskContent']?.toString() ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF8A8078), height: 1.3),
                ),
                if (count > 0) ...[
                  const SizedBox(height: 4),
                  Text('成员均分 $avg（$count 人）', style: const TextStyle(fontSize: 11, color: AppColors.accent)),
                ],
                if (img.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  NetworkImageBox(url: img, height: 96),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '+${item['pointsEarned']}',
            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _FeedbackEntry extends StatelessWidget {
  const _FeedbackEntry({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF8F0),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7DDD2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.mail_outline, color: AppColors.moss, size: 26),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('意见箱', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    SizedBox(height: 4),
                    Text('提需求、吐槽、许愿都可以', style: TextStyle(fontSize: 13, color: Color(0xFF8A8078), height: 1.3)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Color(0xFFB0A69C)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写意见内容')));
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ApiClient.instance.postJson('/api/feedback', {'content': text});
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final safe = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom + safe),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE0D6CC), borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('意见箱', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
            '想加什么功能、哪里不好用，都可以写在这里。',
            style: TextStyle(fontSize: 13, color: Color(0xFF8A8078), height: 1.4),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            minLines: 5,
            maxLines: 8,
            maxLength: 1000,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: '写下你的想法…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('提交'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakHeatmap extends StatelessWidget {
  const _StreakHeatmap({required this.days});
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
    if (days.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text('暂无签到日历', style: TextStyle(color: Color(0xFF8A8078)))),
      );
    }
    const cell = 12.0;
    const gap = 3.0;
    final weeks = (days.length / 7).ceil();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7DDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              height: 7 * (cell + gap) - gap,
              width: weeks * (cell + gap) - gap,
              child: CustomPaint(
                painter: _HeatmapPainter(days: days, colorOf: _color, cell: cell, gap: gap),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 12,
            children: [
              _HeatLegend(color: Color(0xFFF0EAE3), label: '无签'),
              _HeatLegend(color: Color(0xFFE2C8BC), label: '缺勤'),
              _HeatLegend(color: AppColors.gold, label: '今日未完成'),
              _HeatLegend(color: AppColors.moss, label: '已打卡'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeatLegend extends StatelessWidget {
  const _HeatLegend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF8A8078))),
      ],
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({required this.days, required this.colorOf, required this.cell, required this.gap});
  final List<Map<String, dynamic>> days;
  final Color Function(String?) colorOf;
  final double cell;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < days.length; i++) {
      final week = i ~/ 7;
      final weekday = i % 7;
      final rect = Rect.fromLTWH(week * (cell + gap), weekday * (cell + gap), cell, cell);
      final paint = Paint()..color = colorOf(days[i]['status']?.toString());
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) => oldDelegate.days != days;
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _old = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _old.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final oldP = _old.text;
    final newP = _next.text;
    if (oldP.isEmpty || newP.isEmpty) {
      setState(() => _error = '请填写完整');
      return;
    }
    if (newP.length < 6) {
      setState(() => _error = '新密码至少 6 位');
      return;
    }
    if (newP != _confirm.text) {
      setState(() => _error = '两次新密码不一致');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ApiClient.instance.putJson('/api/user/password', {
        'oldPassword': oldP,
        'newPassword': newP,
      });
      if (!mounted) return;
      Navigator.pop(context, true);
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final safe = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + bottom + safe),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE0D6CC), borderRadius: BorderRadius.circular(4)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('修改密码', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
            controller: _old,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: '当前密码'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _next,
            obscureText: _obscure,
            decoration: const InputDecoration(labelText: '新密码'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirm,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: '确认新密码',
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Color(0xFFC0392B))),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, minimumSize: const Size.fromHeight(48)),
            child: Text(_submitting ? '请稍候…' : '保存'),
          ),
        ],
      ),
    );
  }
}
