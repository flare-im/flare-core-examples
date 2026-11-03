import 'package:flare_im/application/providers/conversation_filter_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/domain/value_objects/conversation_filter.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 会话列表筛选条：迁移到 kit [FlareFilterTabs]（四端一致的胶囊 tab）。
/// 选项值用 [ConversationFilter] 的枚举名，回选时 `byName` 还原。
class ConversationFilterBar extends ConsumerWidget {
  const ConversationFilterBar({super.key, required this.onFilterChanged});

  final ValueChanged<ConversationFilter> onFilterChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(conversationFilterProvider);
    final c = ref.watch(flareMessagesProvider).conversation;
    final options = [
      FlareFilterTabOption(
        value: ConversationFilter.all.name,
        label: c.filterAll,
      ),
      FlareFilterTabOption(
        value: ConversationFilter.unread.name,
        label: c.filterUnread,
      ),
      FlareFilterTabOption(
        value: ConversationFilter.mention.name,
        label: c.filterMention,
      ),
    ];

    return SizedBox(
      height: 38,
      child: FlareFilterTabs(
        options: options,
        selected: active.name,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        onSelect: (value) {
          final filter = ConversationFilter.values.byName(value);
          ref.read(conversationFilterProvider.notifier).state = filter;
          onFilterChanged(filter);
        },
      ),
    );
  }
}
