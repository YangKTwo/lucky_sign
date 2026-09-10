import 'package:flutter/foundation.dart';

/// 被 @ 的未读消息 id 队列（先进先出，类似微信「有人@我」）。
class MentionBus {
  MentionBus._();
  static final MentionBus instance = MentionBus._();

  final ValueNotifier<List<int>> unreadIds = ValueNotifier<List<int>>(const []);

  void push(int messageId) {
    if (unreadIds.value.contains(messageId)) return;
    unreadIds.value = [...unreadIds.value, messageId];
  }

  void remove(int messageId) {
    unreadIds.value = unreadIds.value.where((e) => e != messageId).toList();
  }

  void clear() {
    unreadIds.value = const [];
  }

  int? get oldest => unreadIds.value.isEmpty ? null : unreadIds.value.first;

  int get count => unreadIds.value.length;
}
