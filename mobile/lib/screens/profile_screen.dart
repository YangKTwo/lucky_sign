import 'package:flutter/material.dart';

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
              _ProfileHeader(profile: p, onEdit: _editNickname),
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
  const _ProfileHeader({required this.profile, required this.onEdit});
  final Map<String, dynamic> profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final nickname = profile['nickname']?.toString() ?? '';
    final title = profile['title']?.toString() ?? '';
    final email = profile['email']?.toString() ?? '';
    final tag = profile['tag']?.toString();

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
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                child: Text(
                  avatarLetter(nickname),
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
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
