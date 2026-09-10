import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/chat_socket.dart';
import '../theme.dart';
import '../widgets/ui_bits.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _socket = ChatSocket();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _items = <Map<String, dynamic>>[];
  bool _loading = true;
  int? _myUserId;

  @override
  void initState() {
    super.initState();
    _myUserId = ApiClient.instance.userId;
    _ensureMyUserId();
    _loadHistory();
    _socket.connect();
    _socket.messages.listen((msg) {
      if (!mounted) return;
      setState(() {
        if (_items.every((e) => e['id'] != msg['id'])) {
          _items.add(msg);
        }
      });
      _jumpBottom();
    });
  }

  Future<void> _ensureMyUserId() async {
    if (_myUserId != null) return;
    try {
      final res = await ApiClient.instance.getJson('/api/user/profile');
      if (!mounted) return;
      final id = res['data']?['id'];
      final parsed = id is int ? id : (id is num ? id.toInt() : null);
      if (parsed != null) {
        await ApiClient.instance.saveUserId(parsed);
        setState(() => _myUserId = parsed);
      }
    } catch (_) {}
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _loadHistory() async {
    try {
      final res = await ApiClient.instance.getJson('/api/chat/messages?size=50');
      if (!mounted) return;
      final list = (res['data']['messages'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _items
          ..clear()
          ..addAll(list);
      });
      _jumpBottom();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    try {
      final res = await ApiClient.instance.postJson('/api/chat/messages', {'content': text});
      if (!mounted) return;
      final msg = res['data'] as Map<String, dynamic>;
      setState(() {
        if (_items.every((e) => e['id'] != msg['id'])) {
          _items.add(msg);
        }
      });
      _jumpBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openCheckinDetail(Map<String, dynamic> m) async {
    final checkinId = m['checkinId'];
    final id = checkinId is int ? checkinId : (checkinId is num ? checkinId.toInt() : null);
    if (id == null) return;
    try {
      final res = await ApiClient.instance.checkinDetail(id);
      if (!mounted) return;
      final detail = res['data'] as Map<String, dynamic>;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (ctx) => _CheckinDetailSheet(
          detail: detail,
          isMine: _isMine(m),
          onRated: (summary) {
            setState(() {
              m['avgScore'] = summary['avgScore'];
              m['ratingCount'] = summary['ratingCount'];
              m['expectedRaterCount'] = summary['expectedRaterCount'];
              m['ratingComplete'] = summary['ratingComplete'];
              m['myScore'] = summary['myScore'];
            });
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  bool _isMine(Map<String, dynamic> m) {
    final uid = m['userId'];
    if (_myUserId == null || uid == null) return false;
    if (uid is int) return uid == _myUserId;
    if (uid is num) return uid.toInt() == _myUserId;
    return uid.toString() == _myUserId.toString();
  }

  @override
  void dispose() {
    _socket.dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('圈子社区')),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _items.isEmpty && !_loading
                ? const Center(child: Text('还没有消息，打个招呼吧'))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _bubble(_items[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '说点什么… 或 @助手 提问',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '插入 @助手',
                    onPressed: () {
                      final cur = _input.text;
                      final insert = cur.isEmpty || cur.endsWith(' ') ? '@助手 ' : ' @助手 ';
                      _input.text = '$cur$insert';
                      _input.selection = TextSelection.collapsed(offset: _input.text.length);
                    },
                    icon: const Icon(Icons.smart_toy_outlined),
                  ),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> m) {
    final type = m['type']?.toString();
    final name = m['nickname']?.toString() ?? '系统';
    final content = m['content']?.toString() ?? '';
    final img = imageFullUrl(m['imageUrl']?.toString());
    final avatarUrl = m['avatarUrl']?.toString();

    if (type == 'SYSTEM') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFEFE6DC), borderRadius: BorderRadius.circular(20)),
            child: Text(content, style: const TextStyle(fontSize: 12, color: Color(0xFF6B625A))),
          ),
        ),
      );
    }

    final mine = _isMine(m);
    final checkin = type == 'CHECKIN';
    final assistant = type == 'ASSISTANT';
    final displayName = assistant ? (name.isEmpty ? '千问助手' : name) : name;
    final avatar = UserAvatar(
      nickname: assistant ? '助' : displayName,
      avatarUrl: avatarUrl,
      backgroundColor: assistant
          ? const Color(0xFF5B6CFF)
          : (checkin ? AppColors.gold : (mine ? AppColors.accent : AppColors.moss)),
    );
    final avg = m['avgScore'];
    final count = m['ratingCount'] is num ? (m['ratingCount'] as num).toInt() : 0;
    final expected = m['expectedRaterCount'] is num ? (m['expectedRaterCount'] as num).toInt() : 0;
    final complete = m['ratingComplete'] == true;

    final bubble = InkWell(
      onTap: checkin && m['checkinId'] != null ? () => _openCheckinDetail(m) : null,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(mine ? 16 : 4),
        topRight: Radius.circular(mine ? 4 : 16),
        bottomLeft: const Radius.circular(16),
        bottomRight: const Radius.circular(16),
      ),
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
        color: mine
            ? (checkin ? const Color(0xFFFFF3D6) : const Color(0xFFFFE8D6))
            : (assistant
                ? const Color(0xFFEEF0FF)
                : (checkin ? const Color(0xFFFFF3D6) : Colors.white)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 16 : 4),
          topRight: Radius.circular(mine ? 4 : 16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
        border: Border.all(
          color: mine
              ? (checkin ? const Color(0xFFE8C96A) : const Color(0xFFE8B48A))
              : (assistant
                  ? const Color(0xFFC9D0FF)
                  : (checkin ? const Color(0xFFE8C96A) : const Color(0xFFE7DDD2))),
        ),
      ),
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (checkin) const Text('✅ 打卡', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          if (assistant) const Text('🤖 千问助手', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF5B6CFF))),
          if (checkin || assistant) const SizedBox(height: 4),
          Text(
            content,
            textAlign: mine ? TextAlign.right : TextAlign.left,
            style: const TextStyle(height: 1.35),
          ),
            if (img.isNotEmpty) ...[
              const SizedBox(height: 8),
              NetworkImageBox(url: img),
            ],
            if (checkin && m['checkinId'] != null) ...[
              const SizedBox(height: 10),
              Text(
                complete
                    ? '全员已评 · 均分 ${avg ?? '-'}（$count 人）'
                    : '评分进度 $count/$expected · 点击查看评分',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A8078), fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: mine
            ? [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B625A))),
                      const SizedBox(height: 4),
                      bubble,
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                avatar,
              ]
            : [
                avatar,
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B625A))),
                      const SizedBox(height: 4),
                      bubble,
                    ],
                  ),
                ),
              ],
      ),
    );
  }
}

class _CheckinDetailSheet extends StatefulWidget {
  const _CheckinDetailSheet({
    required this.detail,
    required this.isMine,
    required this.onRated,
  });

  final Map<String, dynamic> detail;
  final bool isMine;
  final ValueChanged<Map<String, dynamic>> onRated;

  @override
  State<_CheckinDetailSheet> createState() => _CheckinDetailSheetState();
}

class _CheckinDetailSheetState extends State<_CheckinDetailSheet> {
  late Map<String, dynamic> _rating;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rating = Map<String, dynamic>.from((widget.detail['rating'] as Map?)?.cast<String, dynamic>() ?? {});
  }

  Future<void> _submit(int score) async {
    final rawId = widget.detail['checkinId'];
    final id = rawId is int ? rawId : (rawId is num ? rawId.toInt() : null);
    if (id == null || _submitting) return;
    setState(() => _submitting = true);
    try {
      final res = await ApiClient.instance.rateCheckin(id, score);
      if (!mounted) return;
      final data = (res['data'] as Map).cast<String, dynamic>();
      setState(() => _rating = data);
      widget.onRated(data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final img = imageFullUrl(d['imageUrl']?.toString());
    final count = _rating['ratingCount'] is num ? (_rating['ratingCount'] as num).toInt() : 0;
    final expected = _rating['expectedRaterCount'] is num ? (_rating['expectedRaterCount'] as num).toInt() : 0;
    final complete = _rating['ratingComplete'] == true;
    final avg = _rating['avgScore'];
    final myScore = _rating['myScore'] is num ? (_rating['myScore'] as num).toInt() : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE0D6CC), borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                UserAvatar(
                  nickname: d['nickname']?.toString(),
                  avatarUrl: d['avatarUrl']?.toString(),
                  radius: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d['nickname']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(
                        '${d['checkinDate'] ?? ''} · ${d['level'] ?? ''}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF8A8078)),
                      ),
                    ],
                  ),
                ),
                Text('+${d['pointsEarned'] ?? 0}分', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.accent)),
              ],
            ),
            const SizedBox(height: 14),
            Text(d['taskContent']?.toString() ?? '', style: const TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w600)),
            if ((d['textContent']?.toString().isNotEmpty ?? false)) ...[
              const SizedBox(height: 8),
              Text(d['textContent'].toString(), style: const TextStyle(height: 1.4, color: Color(0xFF6B625A))),
            ],
            if (img.isNotEmpty) ...[
              const SizedBox(height: 12),
              NetworkImageBox(url: img, height: 220),
            ],
            const SizedBox(height: 16),
            Text(
              complete ? '全员已评完 · 均分 ${avg ?? '-'}' : '评分进度 $count / $expected（全员评完后计入综合分）',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (!widget.isMine) ...[
              const SizedBox(height: 12),
              const Text('你的评分', style: TextStyle(fontSize: 13, color: Color(0xFF8A8078))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(5, (i) {
                  final score = i + 1;
                  final selected = myScore == score;
                  return InkWell(
                    onTap: _submitting ? null : () => _submit(score),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 44,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? AppColors.accent : const Color(0xFFFFF8F0),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? AppColors.accent : const Color(0xFFE7DDD2)),
                      ),
                      child: Text(
                        '$score',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : AppColors.ink,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              Text(
                myScore == null ? '点选 1-5 分提交' : '已评 $myScore 分，可修改',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A8078)),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('这是你的打卡，等待其他成员评分', style: TextStyle(fontSize: 12, color: Color(0xFF8A8078))),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
