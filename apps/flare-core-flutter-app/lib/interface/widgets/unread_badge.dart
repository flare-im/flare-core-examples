import 'package:flare_im/application/providers/im_sync_state_provider.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 角标：只监听未读总数（`select`），会话列表大刷新时也不重复重建整树。
/// 视觉交给 kit 的 [FlareUnreadBadge]（四端一致的未读胶囊，99+ 截断、0 隐藏）。
class UnreadBadge extends ConsumerWidget {
  const UnreadBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(unreadProvider.select((u) => u.total));
    return FlareUnreadBadge(count: total);
  }
}
