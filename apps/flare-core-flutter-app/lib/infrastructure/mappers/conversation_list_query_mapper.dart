import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/domain/value_objects/conversation_filter.dart';

/// 将应用层 [ConversationFilter] 映射为 SDK [ConversationListQuery]。
abstract final class ConversationListQueryMapper {
  const ConversationListQueryMapper._();

  /// `null` 表示走默认 `listConversations`（或归档专用列表 API）。
  static core.ConversationListQuery? toSdkQuery(
    ConversationFilter filter, {
    String? keyword,
  }) {
    final trimmedKeyword = keyword?.trim();
    final hasKeyword = trimmedKeyword != null && trimmedKeyword.isNotEmpty;

    return switch (filter) {
      ConversationFilter.all =>
        hasKeyword
            ? core.ConversationListQuery(keyword: trimmedKeyword, limit: 100)
            : null,
      ConversationFilter.archived => null,
      ConversationFilter.unread => core.ConversationListQuery(
        keyword: hasKeyword ? trimmedKeyword : null,
        unreadOnly: true,
        limit: 100,
      ),
      ConversationFilter.mention => core.ConversationListQuery(
        keyword: hasKeyword ? trimmedKeyword : null,
        mentionMeOnly: true,
        limit: 100,
      ),
      ConversationFilter.pinned => core.ConversationListQuery(
        keyword: hasKeyword ? trimmedKeyword : null,
        pinnedOnly: true,
        limit: 100,
      ),
      ConversationFilter.draft => core.ConversationListQuery(
        keyword: hasKeyword ? trimmedKeyword : null,
        hasDraftOnly: true,
        limit: 100,
      ),
      ConversationFilter.muted => core.ConversationListQuery(
        keyword: hasKeyword ? trimmedKeyword : null,
        limit: 100,
      ),
    };
  }
}
