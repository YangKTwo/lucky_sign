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
      setState(() {
        _profile = profile['data'] as Map<String, dynamic>;
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            if (_error != null) Text(_error!, style: const TextStyle(color: Color(0xFFC0392B))),
            if (p != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF2F6B5A), Color(0xFF3E8E75)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      child: Text(
                        avatarLetter(p['nickname']?.toString()),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  p['nickname']?.toString() ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                                ),
                              ),
                              IconButton(
                                onPressed: _editNickname,
                                icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                              ),
                              TagChip(p['tag']?.toString()),
                            ],
                          ),
                          Text(p['email']?.toString() ?? '', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(p['title']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (p['tag'] == 'DORMANT') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFEEECEA), borderRadius: BorderRadius.circular(14)),
                  child: const Text('账号已休眠：可看社区，不能发言/抽签。请联系管理员解锁。'),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  StatTile(label: '总积分', value: '${p['points']}'),
                  const SizedBox(width: 8),
                  StatTile(label: '连续签到', value: '${p['streakDays']}'),
                  const SizedBox(width: 8),
                  StatTile(label: '累计完成', value: '${p['totalCompletedDays']}'),
                ],
              ),
            ],
            const SizedBox(height: 22),
            const Text('历史签到', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (_history.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('还没有打卡记录')),
            ..._history.take(30).map((h) {
              final level = h['level']?.toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE7DDD2)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.level(level),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(level ?? '-', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h['date']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(h['taskContent']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF8A8078))),
                        ],
                      ),
                    ),
                    Text('+${h['pointsEarned']}', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent)),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => logoutAndGoLogin(context),
              child: const Text('退出登录'),
            ),
          ],
        ),
      ),
    );
  }
}
