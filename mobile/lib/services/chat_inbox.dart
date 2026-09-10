import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 社区未读 / @我 提示（进程内 + 本地 lastRead）。
class ChatInbox {
  ChatInbox._();
  static final ChatInbox instance = ChatInbox._();

  static const _lastReadKey = 'chat_last_read_id';

  final ValueNotifier<List<int>> unreadIds = ValueNotifier<List<int>>(const []);
  final ValueNotifier<List<int>> mentionIds = ValueNotifier<List<int>>(const []);

  int? lastReadId;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    lastReadId = prefs.getInt(_lastReadKey);
    _loaded = true;
  }

  Future<void> _persistLastRead(int id) async {
    if (lastReadId != null && id <= lastReadId!) return;
    lastReadId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastReadKey, id);
  }

  void pushUnread(int messageId) {
    if (unreadIds.value.contains(messageId)) return;
    final next = [...unreadIds.value, messageId]..sort();
    unreadIds.value = next;
  }

  void pushMention(int messageId) {
    if (mentionIds.value.contains(messageId)) return;
    final next = [...mentionIds.value, messageId]..sort();
    mentionIds.value = next;
  }

  void remove(int messageId) {
    unreadIds.value = unreadIds.value.where((e) => e != messageId).toList();
    mentionIds.value = mentionIds.value.where((e) => e != messageId).toList();
  }

  /// 标记已读到某条（含之前）。
  Future<void> markReadThrough(int messageId) async {
    unreadIds.value = unreadIds.value.where((e) => e > messageId).toList();
    mentionIds.value = mentionIds.value.where((e) => e > messageId).toList();
    await _persistLastRead(messageId);
  }

  Future<void> clearAllAsRead(int? latestId) async {
    unreadIds.value = const [];
    mentionIds.value = const [];
    if (latestId != null) {
      await _persistLastRead(latestId);
    }
  }

  int get unreadCount => unreadIds.value.length;

  int? get oldestUnread => unreadIds.value.isEmpty ? null : unreadIds.value.first;

  int? get oldestMention => mentionIds.value.isEmpty ? null : mentionIds.value.first;

  Future<void> reset() async {
    unreadIds.value = const [];
    mentionIds.value = const [];
    lastReadId = null;
    _loaded = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastReadKey);
  }
}
