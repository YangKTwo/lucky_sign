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

  @override
  void initState() {
    super.initState();
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
                        hintText: '说点什么…',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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

    final checkin = type == 'CHECKIN';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: checkin ? AppColors.gold : AppColors.moss,
            child: Text(avatarLetter(name), style: const TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B625A))),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: checkin ? const Color(0xFFFFF3D6) : Colors.white,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: checkin ? const Color(0xFFE8C96A) : const Color(0xFFE7DDD2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (checkin) const Text('✅ 打卡', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      if (checkin) const SizedBox(height: 4),
                      Text(content, style: const TextStyle(height: 1.35)),
                      if (img.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(img, height: 160, width: double.infinity, fit: BoxFit.cover),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
