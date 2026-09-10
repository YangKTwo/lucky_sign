import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/chat_socket.dart';
import '../services/mention_bus.dart';
import '../theme.dart';
import '../widgets/ui_bits.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.isActive = true});

  /// 当前是否在底部「社区」Tab（用于决定是否立刻标记已读）。
  final bool isActive;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _socket = ChatSocket();
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _items = <Map<String, dynamic>>[];
  final _itemKeys = <int, GlobalKey>{};
  final _members = <Map<String, dynamic>>[];
  bool _loading = true;
  int? _myUserId;
  bool _showMentionPicker = false;
  String _mentionQuery = '';
  int _atStart = -1;

  static const _assistantNames = ['石桥头第一AI', '助手'];

  @override
  void initState() {
    super.initState();
    _myUserId = ApiClient.instance.userId;
    _ensureMyUserId();
    _loadMembers();
    _loadHistory();
    _socket.connect();
    _input.addListener(_onInputChanged);
    _socket.messages.listen((msg) {
      if (!mounted) return;
      final isNew = _items.every((e) => e['id'] != msg['id']);
      setState(() => _upsertMessage(msg));
      if (isNew) {
        _maybeTrackMention(msg);
        _jumpBottom();
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      // 切回社区时不自动清未读，保留「有人@我」跳转。
    }
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

  Future<void> _loadMembers() async {
    try {
      final res = await ApiClient.instance.getJson('/api/circle/members');
      if (!mounted) return;
      final list = (res['data']['members'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      setState(() {
        _members
          ..clear()
          ..addAll(list);
      });
    } catch (_) {}
  }

  void _upsertMessage(Map<String, dynamic> msg) {
    final i = _items.indexWhere((e) => e['id'] == msg['id']);
    if (i >= 0) {
      _items[i] = msg;
    } else {
      _items.add(msg);
    }
  }

  int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '');
  }

  bool _mentionsMe(Map<String, dynamic> m) {
    if (_myUserId == null || _isMine(m)) return false;
    final raw = m['mentionedUserIds'];
    if (raw is! List) return false;
    for (final e in raw) {
      final id = _asInt(e);
      if (id == _myUserId) return true;
    }
    return false;
  }

  void _maybeTrackMention(Map<String, dynamic> msg) {
    if (!_mentionsMe(msg)) return;
    final id = _asInt(msg['id']);
    if (id == null) return;
    MentionBus.instance.push(id);
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

  Future<void> _jumpToMention() async {
    final id = MentionBus.instance.oldest;
    if (id == null) return;
    final index = _items.indexWhere((e) => _asInt(e['id']) == id);
    if (index < 0) {
      MentionBus.instance.remove(id);
      return;
    }
    MentionBus.instance.remove(id);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final key = _itemKeys[id];
    final ctx = key?.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.25,
      );
    }
    setState(() {});
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

  void _onInputChanged() {
    final text = _input.text;
    final sel = _input.selection;
    if (!sel.isValid || !sel.isCollapsed) {
      if (_showMentionPicker) setState(() => _showMentionPicker = false);
      return;
    }
    final cursor = sel.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      if (_showMentionPicker) setState(() => _showMentionPicker = false);
      return;
    }
    final before = text.substring(0, cursor);
    final at = before.lastIndexOf('@');
    if (at < 0) {
      if (_showMentionPicker) setState(() => _showMentionPicker = false);
      return;
    }
    if (at > 0) {
      final prev = before[at - 1];
      if (prev.trim().isNotEmpty && prev != '\n') {
        // 非词首的 @（如邮箱）不弹
        if (_showMentionPicker) setState(() => _showMentionPicker = false);
        return;
      }
    }
    final query = before.substring(at + 1);
    if (query.contains(' ') || query.contains('\n')) {
      if (_showMentionPicker) setState(() => _showMentionPicker = false);
      return;
    }
    setState(() {
      _showMentionPicker = true;
      _mentionQuery = query;
      _atStart = at;
    });
  }

  List<Map<String, dynamic>> get _filteredMembers {
    final q = _mentionQuery.trim().toLowerCase();
    if (q.isEmpty) return _members;
    return _members.where((m) {
      final name = (m['nickname']?.toString() ?? '').toLowerCase();
      return name.contains(q);
    }).toList();
  }

  void _insertMention(Map<String, dynamic> member) {
    final name = member['nickname']?.toString() ?? '';
    if (name.isEmpty || _atStart < 0) return;
    final text = _input.text;
    final cursor = _input.selection.baseOffset.clamp(0, text.length);
    final insert = '@$name ';
    final newText = text.replaceRange(_atStart, cursor, insert);
    final newCursor = _atStart + insert.length;
    _input.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
    setState(() {
      _showMentionPicker = false;
      _mentionQuery = '';
      _atStart = -1;
    });
    _focus.requestFocus();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _showMentionPicker = false);
    try {
      final res = await ApiClient.instance.postJson('/api/chat/messages', {'content': text});
      if (!mounted) return;
      final msg = res['data'] as Map<String, dynamic>;
      setState(() => _upsertMessage(msg));
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

  List<String> get _highlightNames {
    final names = <String>[..._assistantNames];
    for (final m in _members) {
      final n = m['nickname']?.toString();
      if (n != null && n.isNotEmpty) names.add(n);
    }
    names.sort((a, b) => b.length.compareTo(a.length));
    return names;
  }

  Widget _richContent(String content, {required bool mine}) {
    final names = _highlightNames;
    if (names.isEmpty || !content.contains('@')) {
      return Text(
        content,
        textAlign: mine ? TextAlign.right : TextAlign.left,
        style: const TextStyle(height: 1.35),
      );
    }
    final spans = <TextSpan>[];
    var i = 0;
    while (i < content.length) {
      if (content[i] == '@') {
        var matched = false;
        for (final name in names) {
          final token = '@$name';
          if (content.startsWith(token, i)) {
            spans.add(TextSpan(
              text: token,
              style: const TextStyle(
                height: 1.35,
                color: Color(0xFF2F6BFF),
                fontWeight: FontWeight.w700,
              ),
            ));
            i += token.length;
            matched = true;
            break;
          }
        }
        if (matched) continue;
      }
      final nextAt = content.indexOf('@', i + 1);
      final end = nextAt < 0 ? content.length : nextAt;
      spans.add(TextSpan(text: content.substring(i, end), style: const TextStyle(height: 1.35)));
      i = end;
    }
    return Text.rich(
      TextSpan(children: spans),
      textAlign: mine ? TextAlign.right : TextAlign.left,
    );
  }

  @override
  void dispose() {
    _input.removeListener(_onInputChanged);
    _socket.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMembers;
    return Scaffold(
      appBar: AppBar(title: const Text('圈子社区')),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: Stack(
              children: [
                _items.isEmpty && !_loading
                    ? const Center(child: Text('还没有消息，打个招呼吧'))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        itemCount: _items.length,
                        itemBuilder: (_, i) {
                          final m = _items[i];
                          final id = _asInt(m['id']);
                          final key = id == null ? null : _itemKeys.putIfAbsent(id, GlobalKey.new);
                          return KeyedSubtree(key: key, child: _bubble(m));
                        },
                      ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: ValueListenableBuilder<List<int>>(
                    valueListenable: MentionBus.instance.unreadIds,
                    builder: (_, ids, __) {
                      if (ids.isEmpty) return const SizedBox.shrink();
                      return Material(
                        color: const Color(0xFFFFF3D6),
                        elevation: 2,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: _jumpToMention,
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Text(
                              ids.length == 1 ? '有人@我' : '有人@我 · ${ids.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Color(0xFFB86A00),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_showMentionPicker && filtered.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 0,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final m = filtered[i];
                            final assistant = m['assistant'] == true;
                            final name = m['nickname']?.toString() ?? '';
                            return ListTile(
                              dense: true,
                              leading: UserAvatar(
                                nickname: assistant ? '石' : name,
                                avatarUrl: m['avatarUrl']?.toString(),
                                radius: 18,
                                backgroundColor: assistant ? const Color(0xFF5B6CFF) : AppColors.moss,
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: assistant ? const Text('社区助手 · 输入问题即可回复') : null,
                              onTap: () => _insertMention(m),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
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
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: '说点什么… 输入 @ 可提醒成员或助手',
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
    final avatarUrl = m['avatarUrl']?.toString();
    final mentionedMe = _mentionsMe(m);

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
    final displayName = assistant ? (name.isEmpty ? '石桥头第一AI' : name) : name;
    final avatar = UserAvatar(
      nickname: assistant ? '石' : displayName,
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
            color: mentionedMe
                ? const Color(0xFFFFB020)
                : (mine
                    ? (checkin ? const Color(0xFFE8C96A) : const Color(0xFFE8B48A))
                    : (assistant
                        ? const Color(0xFFC9D0FF)
                        : (checkin ? const Color(0xFFE8C96A) : const Color(0xFFE7DDD2)))),
            width: mentionedMe ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (checkin) const Text('✅ 打卡', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            if (assistant)
              Text('🤖 $displayName', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF5B6CFF))),
            if (checkin || assistant) const SizedBox(height: 4),
            if (assistant && content == '正在回复…')
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5B6CFF)),
                  ),
                  SizedBox(width: 8),
                  Text('正在回复…', style: TextStyle(height: 1.35, color: Color(0xFF5B6CFF))),
                ],
              )
            else
              _richContent(content, mine: mine),
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
