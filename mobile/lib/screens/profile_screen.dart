import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../widgets/ui_bits.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _history = [];
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
        _history = (history['data']['items'] as List).cast<Map<String, dynamic>>();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
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
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _openFeedback() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('意见箱'),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '想加什么功能、哪里不好用，都可以写在这里。',
                style: TextStyle(fontSize: 13, color: Color(0xFF8A8078), height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: '写下你的想法…',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('提交'),
          ),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return;
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写意见内容')));
      return;
    }
    try {
      await ApiClient.instance.postJson('/api/feedback', {'content': text});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已收到，感谢反馈')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
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
            if (_error != null)
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
              const SizedBox(height: 28),
              _FeedbackEntry(onTap: _openFeedback),
              const SizedBox(height: 12),
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
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7DDD2)),
          ),
          child: const Row(
            children: [
              Icon(Icons.mail_outline, color: AppColors.moss),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('意见箱', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    SizedBox(height: 2),
                    Text('提需求、吐槽、许愿都可以', style: TextStyle(fontSize: 12, color: Color(0xFF8A8078))),
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
