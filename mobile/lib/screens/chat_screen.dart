import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../constants/assistant.dart';
import '../main.dart';
import '../services/api_client.dart';
import '../services/chat_inbox.dart';
import '../services/chat_socket.dart';
import '../theme.dart';
import '../utils/errors.dart';
import '../widgets/ui_bits.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, this.isActive = true});

  /// 当前是否在底部「社区」Tab。
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
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _historyError;
  String? _membersError;
  int? _myUserId;
  String? _myNickname;
  bool _showMentionPicker = false;
  String _mentionQuery = '';
  int _atStart = -1;

  /// 是否贴近列表底部（最新消息）。
  bool _nearBottom = true;

  /// 人不在底部时，下方积压的新消息条数（点「↓」回到最新）。
  int _newBelowCount = 0;

  /// 跳转到某条时短暂高亮。
  int? _highlightId;

  static const _assistantNames = assistantMentionNames;
  static final _timeFmt = DateFormat('HH:mm');
  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  void initState() {
    super.initState();
    _myUserId = ApiClient.instance.userId;
    _scroll.addListener(_onScroll);
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
        _onNewMessage(msg);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切回社区：落到最新；上方若有未读，保留顶部提示可点跳转。
    if (widget.isActive && !oldWidget.isActive) {
      _scrollToLatest(animate: false);
      if (_nearBottom) {
        _markVisibleAsRead();
      }
    }
  }

  Future<void> _ensureMyUserId() async {
    try {
      final res = await ApiClient.instance.getJson('/api/user/profile');
      if (!mounted) return;
      final data = res['data'];
      final id = data?['id'];
      final parsed = id is int ? id : (id is num ? id.toInt() : null);
      final nick = data?['nickname']?.toString();
      if (parsed != null) {
        await ApiClient.instance.saveUserId(parsed);
      }
      setState(() {
        if (parsed != null) _myUserId = parsed;
        if (nick != null && nick.isNotEmpty) _myNickname = nick;
      });
    } catch (e) {
      debugPrint('ensureMyUserId failed: $e');
    }
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
        _membersError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _membersError = formatError(e));
    }
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

  DateTime? _createdAt(Map<String, dynamic> m) {
    final raw = m['createdAt'];
    if (raw == null) return null;
    if (raw is int) {
      // 秒 / 毫秒
      final ms = raw > 20000000000 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    }
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  bool _isNearBottom({double threshold = 120}) {
    if (!_scroll.hasClients) return true;
    final pos = _scroll.position;
    return pos.maxScrollExtent - pos.pixels <= threshold;
  }

  void _onScroll() {
    final near = _isNearBottom();
    if (near != _nearBottom) {
      setState(() => _nearBottom = near);
    }
    if (!widget.isActive) return;
    if (near) {
      if (_newBelowCount != 0) {
        setState(() => _newBelowCount = 0);
      }
      // 有上方未读待跳转时，贴底不要整段清掉（否则顶部「↑未读」会立刻消失）
      final hasCatchUp = ChatInbox.instance.unreadCount > 0 || ChatInbox.instance.mentionIds.value.isNotEmpty;
      if (!hasCatchUp) {
        _markVisibleAsRead();
      }
    } else {
      _markUnreadsEnteredViewport();
      if (_scroll.position.pixels <= 48) {
        _loadOlder();
      }
    }
  }

  /// 向上浏览时，进入视口的未读逐条消掉。
  void _markUnreadsEnteredViewport() {
    if (!_scroll.hasClients) return;
    final ids = {
      ...ChatInbox.instance.unreadIds.value,
      ...ChatInbox.instance.mentionIds.value,
    };
    if (ids.isEmpty) return;
    var changed = false;
    for (final id in ids) {
      final ctx = _itemKeys[id]?.currentContext;
      if (ctx == null || !ctx.mounted) continue;
      final ro = ctx.findRenderObject();
      if (ro is! RenderBox || !ro.hasSize) continue;
      final dy = ro.localToGlobal(Offset.zero).dy;
      final screenH = MediaQuery.sizeOf(context).height;
      // 大致进入屏幕中部偏上，视为已看见
      if (dy > 80 && dy < screenH * 0.75) {
        ChatInbox.instance.remove(id);
        changed = true;
      }
    }
    if (changed && mounted) setState(() {});
  }

  Future<void> _markVisibleAsRead({bool force = false}) async {
    if (_items.isEmpty) return;
    if (!force) {
      final hasCatchUp = ChatInbox.instance.unreadCount > 0 || ChatInbox.instance.mentionIds.value.isNotEmpty;
      if (hasCatchUp) return;
    }
    final latest = _asInt(_items.last['id']);
    if (latest == null) return;
    await ChatInbox.instance.markReadThrough(latest);
    if (mounted) setState(() {});
  }

  bool _mentionsMe(Map<String, dynamic> m) {
    if (_isMine(m)) return false;
    final raw = m['mentionedUserIds'];
    if (raw is List && _myUserId != null) {
      for (final e in raw) {
        if (_asInt(e) == _myUserId) return true;
      }
    }
    final nick = _myNickname?.trim();
    final content = m['content']?.toString() ?? '';
    if (nick != null && nick.isNotEmpty && content.contains('@$nick')) {
      final idx = content.indexOf('@$nick');
      final end = idx + nick.length + 1;
      if (end >= content.length) return true;
      final next = content[end];
      if (RegExp(r'[\s,.!?;:，。！？；：、)\]\}」』]').hasMatch(next)) return true;
    }
    return false;
  }

  void _onNewMessage(Map<String, dynamic> msg) {
    final id = _asInt(msg['id']);
    if (id == null) return;
    final mine = _isMine(msg);
    final mentionsMe = _mentionsMe(msg);
    final away = !widget.isActive || !_isNearBottom();

    if (!mine && away) {
      ChatInbox.instance.pushUnread(id);
    }
    if (mentionsMe && away) {
      ChatInbox.instance.pushMention(id);
      final from = msg['nickname']?.toString() ?? '有人';
      rootScaffoldMessengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('$from @了你'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: '查看',
              onPressed: () => _jumpToMessage(id, markThrough: false),
            ),
          ),
        );
    }

    if (widget.isActive && _isNearBottom()) {
      _scrollToLatest(animate: true);
      _markVisibleAsRead();
    } else if (widget.isActive && mine) {
      _scrollToLatest(animate: true);
      setState(() => _newBelowCount = 0);
    } else if (!mine) {
      setState(() => _newBelowCount += 1);
    }
    if (mounted) setState(() {});
  }

  /// 滚到最新一条。首次进入用 jump，避免动画时高度未算完落空。
  Future<void> _scrollToLatest({bool animate = false}) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      await Future<void>.delayed(Duration(milliseconds: attempt == 0 ? 16 : 40));
      if (!mounted || !_scroll.hasClients) continue;
      final target = _scroll.position.maxScrollExtent;
      if (animate && attempt == 0) {
        await _scroll.animateTo(
          target,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scroll.jumpTo(target);
      }
      if ((_scroll.position.maxScrollExtent - _scroll.position.pixels).abs() < 4) {
        if (mounted) {
          setState(() {
            _nearBottom = true;
            _newBelowCount = 0;
          });
        }
        return;
      }
    }
  }

  Future<void> _jumpToMessage(int id, {required bool markThrough}) async {
    final index = _items.indexWhere((e) => _asInt(e['id']) == id);
    if (index < 0) {
      ChatInbox.instance.remove(id);
      if (mounted) setState(() {});
      return;
    }
    setState(() => _highlightId = id);
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final key = _itemKeys[id];
    final ctx = key?.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.25,
      );
    }
    if (markThrough) {
      await ChatInbox.instance.markReadThrough(id);
    } else {
      ChatInbox.instance.remove(id);
    }
    if (mounted) setState(() {});
    Future<void>.delayed(const Duration(milliseconds: 1200), () {
      if (mounted && _highlightId == id) {
        setState(() => _highlightId = null);
      }
    });
  }

  Future<void> _jumpToOldestUnreadOrMention() async {
    final mentionId = ChatInbox.instance.oldestMention;
    if (mentionId != null) {
      await _jumpToMessage(mentionId, markThrough: true);
      return;
    }
    final unreadId = ChatInbox.instance.oldestUnread;
    if (unreadId != null) {
      await _jumpToMessage(unreadId, markThrough: true);
    }
  }

  Future<void> _loadHistory() async {
    try {
      await ChatInbox.instance.load();
      final res = await ApiClient.instance.getJson('/api/chat/messages?size=50');
      if (!mounted) return;
      final list = (res['data']['messages'] as List).cast<Map<String, dynamic>>();
      final hasMore = res['data']['hasMore'] == true;
      setState(() {
        _historyError = null;
        _hasMore = hasMore;
        _items
          ..clear()
          ..addAll(list);
      });

      final latest = list.isEmpty ? null : _asInt(list.last['id']);
      if (ChatInbox.instance.lastReadId == null) {
        if (latest != null) {
          await ChatInbox.instance.markReadThrough(latest);
        }
      } else {
        final lastRead = ChatInbox.instance.lastReadId!;
        for (final m in list) {
          final id = _asInt(m['id']);
          if (id == null || id <= lastRead || _isMine(m)) continue;
          ChatInbox.instance.pushUnread(id);
          if (_mentionsMe(m)) {
            ChatInbox.instance.pushMention(id);
          }
        }
      }

      // 进入会话：先落到最新；未读提示留给顶部胶囊。
      await _scrollToLatest(animate: false);
      if (widget.isActive && ChatInbox.instance.unreadCount == 0) {
        await _markVisibleAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _historyError = formatError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOlder() async {
    if (_loadingMore || !_hasMore || _items.isEmpty) return;
    final oldest = _asInt(_items.first['id']);
    if (oldest == null) return;
    _loadingMore = true;
    if (mounted) setState(() {});
    try {
      final res = await ApiClient.instance.getJson('/api/chat/messages?size=30&beforeId=$oldest');
      if (!mounted) return;
      final list = (res['data']['messages'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      final hasMore = res['data']['hasMore'] == true;
      if (list.isEmpty) {
        setState(() {
          _hasMore = false;
          _loadingMore = false;
        });
        return;
      }
      final oldMax = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
      final oldPixels = _scroll.hasClients ? _scroll.position.pixels : 0.0;
      setState(() {
        _items.insertAll(0, list);
        _hasMore = hasMore;
        _loadingMore = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final delta = _scroll.position.maxScrollExtent - oldMax;
        _scroll.jumpTo(oldPixels + delta);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更早消息加载失败：${formatError(e)}')),
      );
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
      await _scrollToLatest(animate: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(formatError(e))),
      );
    }
  }

  Future<void> _copyText(String text) async {
    if (text.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
    );
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
        SnackBar(content: Text(formatError(e))),
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

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _shouldShowDateHeader(int index) {
    final cur = _createdAt(_items[index]);
    if (cur == null) return false;
    if (index == 0) return true;
    return !_sameDay(cur, _createdAt(_items[index - 1]));
  }

  /// 列表里「以下为新消息」插在第一条仍未读的消息前。
  bool _shouldShowUnreadDivider(int index) {
    final firstId = ChatInbox.instance.oldestMention ?? ChatInbox.instance.oldestUnread;
    if (firstId == null) return false;
    return _asInt(_items[index]['id']) == firstId;
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
    _scroll.removeListener(_onScroll);
    _input.removeListener(_onInputChanged);
    _socket.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Widget _unreadJumpChip() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ChatInbox.instance.unreadIds,
        ChatInbox.instance.mentionIds,
      ]),
      builder: (_, __) {
        final mentions = ChatInbox.instance.mentionIds.value;
        final unreads = ChatInbox.instance.unreadIds.value;
        if (mentions.isEmpty && unreads.isEmpty) {
          return const SizedBox.shrink();
        }
        final isMention = mentions.isNotEmpty;
        final count = isMention ? mentions.length : unreads.length;
        final label = isMention
            ? (count == 1 ? '↑ 有人@我' : '↑ 有人@我 · $count')
            : (count > 99 ? '↑ 99+ 条未读' : '↑ $count 条未读');
        return Material(
          color: isMention ? const Color(0xFFFFF3D6) : Colors.white,
          elevation: 3,
          shadowColor: const Color(0x33000000),
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            onTap: _jumpToOldestUnreadOrMention,
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMention ? Icons.alternate_email : Icons.keyboard_arrow_up_rounded,
                    size: 18,
                    color: isMention ? const Color(0xFFB86A00) : const Color(0xFF2F6BFF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: isMention ? const Color(0xFFB86A00) : const Color(0xFF2F6BFF),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _scrollToLatestFab() {
    final showNew = _newBelowCount > 0;
    if (_nearBottom && !showNew) return const SizedBox.shrink();
    return Material(
      color: showNew ? AppColors.accent : Colors.white,
      elevation: 3,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: () async {
          await _scrollToLatest(animate: true);
          if (widget.isActive) await _markVisibleAsRead(force: true);
        },
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: showNew ? Colors.white : const Color(0xFF5A524A),
              ),
              const SizedBox(width: 2),
              Text(
                showNew
                    ? (_newBelowCount > 99 ? '99+ 条新消息' : '$_newBelowCount 条新消息')
                    : '回到底部',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: showNew ? Colors.white : const Color(0xFF5A524A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMembers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('圈子社区'),
        actions: [
          if (!_loading && _items.isNotEmpty)
            IconButton(
              tooltip: '最新消息',
              onPressed: () async {
                await _scrollToLatest(animate: true);
                if (widget.isActive) await _markVisibleAsRead(force: true);
              },
              icon: const Icon(Icons.vertical_align_bottom_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          if (_historyError != null)
            Material(
              color: const Color(0xFFFFF1E6),
              child: ListTile(
                dense: true,
                title: Text('聊天记录加载失败：$_historyError', style: const TextStyle(fontSize: 13)),
                trailing: TextButton(onPressed: () {
                  setState(() {
                    _loading = true;
                    _historyError = null;
                  });
                  _loadHistory();
                }, child: const Text('重试')),
              ),
            ),
          if (_membersError != null)
            Material(
              color: const Color(0xFFFFF8F0),
              child: ListTile(
                dense: true,
                title: Text('@ 成员列表加载失败：$_membersError', style: const TextStyle(fontSize: 13)),
                trailing: TextButton(onPressed: _loadMembers, child: const Text('重试')),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                _items.isEmpty && !_loading
                    ? const Center(child: Text('还没有消息，打个招呼吧'))
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                        itemCount: _items.length + ((_loadingMore || _hasMore) ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == 0 && (_loadingMore || _hasMore)) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: _loadingMore
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : TextButton(
                                        onPressed: _loadOlder,
                                        child: const Text('加载更早消息'),
                                      ),
                              ),
                            );
                          }
                          final msgIndex = (_loadingMore || _hasMore) ? i - 1 : i;
                          final m = _items[msgIndex];
                          final id = _asInt(m['id']);
                          final key = id == null ? null : _itemKeys.putIfAbsent(id, GlobalKey.new);
                          return KeyedSubtree(
                            key: key,
                            child: Column(
                              children: [
                                if (_shouldShowDateHeader(msgIndex)) _DateSeparator(label: _formatDateLabel(_createdAt(m))),
                                if (_shouldShowUnreadDivider(msgIndex)) const _UnreadDivider(),
                                _bubble(m),
                              ],
                            ),
                          );
                        },
                      ),
                // 上方：跳到第一条未读 / @
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: Center(child: _unreadJumpChip()),
                ),
                // 下方：新消息 / 回到底部
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(child: _scrollToLatestFab()),
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
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE7DDD2))),
              ),
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '说点什么… 输入 @ 可提醒',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateLabel(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    final wd = _weekdays[(dt.weekday - 1).clamp(0, 6)];
    if (dt.year == now.year) return '${dt.month}月${dt.day}日 $wd';
    return '${dt.year}年${dt.month}月${dt.day}日 $wd';
  }

  Widget _bubble(Map<String, dynamic> m) {
    final type = m['type']?.toString();
    final name = m['nickname']?.toString() ?? '系统';
    final content = m['content']?.toString() ?? '';
    final img = imageFullUrl(m['imageUrl']?.toString());
    final avatarUrl = m['avatarUrl']?.toString();
    final mentionedMe = _mentionsMe(m);
    final id = _asInt(m['id']);
    final highlighted = id != null && id == _highlightId;
    final when = _createdAt(m);

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

    final bubble = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: checkin && m['checkinId'] != null ? () => _openCheckinDetail(m) : null,
        onLongPress: content.trim().isEmpty ? null : () => _copyText(content),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 16 : 4),
          topRight: Radius.circular(mine ? 4 : 16),
          bottomLeft: const Radius.circular(16),
          bottomRight: const Radius.circular(16),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: highlighted
                ? const Color(0xFFFFF0C8)
                : (mine
                    ? (checkin ? const Color(0xFFFFF3D6) : const Color(0xFFFFE8D6))
                    : (assistant
                        ? const Color(0xFFEEF0FF)
                        : (checkin ? const Color(0xFFFFF3D6) : Colors.white))),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(mine ? 16 : 4),
              topRight: Radius.circular(mine ? 4 : 16),
              bottomLeft: const Radius.circular(16),
              bottomRight: const Radius.circular(16),
            ),
            border: Border.all(
              color: mentionedMe
                  ? const Color(0xFFFFB020)
                  : (highlighted
                      ? const Color(0xFFE8A838)
                      : (mine
                          ? (checkin ? const Color(0xFFE8C96A) : const Color(0xFFE8B48A))
                          : (assistant
                              ? const Color(0xFFC9D0FF)
                              : (checkin ? const Color(0xFFE8C96A) : const Color(0xFFE7DDD2))))),
              width: mentionedMe || highlighted ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (checkin) const Text('✅ 打卡', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              if (assistant)
                Text('🤖 $displayName',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF5B6CFF))),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (when != null) ...[
                            Text(_timeFmt.format(when),
                                style: const TextStyle(fontSize: 11, color: Color(0xFFA09890))),
                            const SizedBox(width: 6),
                          ],
                          Text(displayName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B625A))),
                        ],
                      ),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(displayName,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF6B625A))),
                          if (when != null) ...[
                            const SizedBox(width: 6),
                            Text(_timeFmt.format(when),
                                style: const TextStyle(fontSize: 11, color: Color(0xFFA09890))),
                          ],
                        ],
                      ),
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

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEFE6DC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B625A), fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Color(0xFFE8A838), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '以下为新消息',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.orange.shade800,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Color(0xFFE8A838), thickness: 1)),
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
        SnackBar(content: Text(formatError(e))),
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
