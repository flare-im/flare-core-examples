import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 已打开聊天页的会话 id 栈（push 顺序与路由一致，[last] 为当前前台会话）。
///
/// 用于：下行未读、全量 `load()` 合并时，不对「正在看的会话」累加/恢复未读。
class ActiveChatStackNotifier extends StateNotifier<List<String>> {
  ActiveChatStackNotifier() : super(const []);

  void push(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return;
    state = [...state.where((x) => x != id), id];
  }

  void remove(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) return;
    state = [
      for (final x in state)
        if (x != id) x,
    ];
  }

  void clear() => state = const [];
}

final activeChatStackProvider =
    StateNotifierProvider<ActiveChatStackNotifier, List<String>>((ref) {
      return ActiveChatStackNotifier();
    });

/// 栈顶 = 当前前台聊天会话 id（分屏/桌面端与最后打开的详情页一致）。
final foregroundChatConversationIdProvider = Provider<String?>((ref) {
  final stack = ref.watch(activeChatStackProvider);
  if (stack.isEmpty) return null;
  return stack.last;
});
