import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../widgets/ui_bits.dart';

class RankScreen extends StatefulWidget {
  const RankScreen({super.key});

  @override
  State<RankScreen> createState() => _RankScreenState();
}

class _RankScreenState extends State<RankScreen> {
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.getJson('/api/rank');
      if (!mounted) return;
      setState(() {
        _data = res['data'] as Map<String, dynamic>;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = formatError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final byComposite = (_data?['byComposite'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final byPoints = (_data?['byPoints'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final byStreak = (_data?['byStreak'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final star = _data?['luckyStar'] as Map<String, dynamic>?;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('圈子排行'),
          bottom: const TabBar(
            labelColor: AppColors.accent,
            unselectedLabelColor: Color(0xFF8A8078),
            indicatorColor: AppColors.accent,
            tabs: [
              Tab(text: '综合分'),
              Tab(text: '任务分'),
              Tab(text: '连续天'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!, style: const TextStyle(color: Color(0xFFC0392B))),
              ),
            if (star != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD56A), Color(0xFFFFB703)]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Text('⭐', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '今日幸运星  ${star['nickname']}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      const Text('任务分翻倍', style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                '综合分 = 任务积分 + 全员评完后的互评均分×2',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A8078)),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _list(byComposite, mode: _RankMode.composite),
                  _list(byPoints, mode: _RankMode.points),
                  _list(byStreak, mode: _RankMode.streak),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _list(List<Map<String, dynamic>> items, {required _RankMode mode}) {
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [SizedBox(height: 80), Center(child: Text('暂无成员'))]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final m = items[i];
          final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}';
          final peer = m['peerAvgScore'];
          String right;
          switch (mode) {
            case _RankMode.composite:
              right = '${m['compositeScore']}分';
              break;
            case _RankMode.points:
              right = '${m['points']}分';
              break;
            case _RankMode.streak:
              right = '${m['streakDays']}天';
              break;
          }
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7DDD2)),
            ),
            child: Row(
              children: [
                SizedBox(width: 36, child: Text(medal, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                UserAvatar(
                  nickname: m['nickname']?.toString(),
                  avatarUrl: m['avatarUrl']?.toString(),
                  backgroundColor: m['luckyStar'] == true ? AppColors.gold : AppColors.moss,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(m['nickname']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 6),
                          TagChip(m['tag']?.toString()),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${m['title']} · 今日 ${AppColors.todayStatus(m['todayStatus']?.toString())}'
                        '${peer != null ? ' · 互评$peer' : ''}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8A8078)),
                      ),
                    ],
                  ),
                ),
                Text(
                  right,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _RankMode { composite, points, streak }
