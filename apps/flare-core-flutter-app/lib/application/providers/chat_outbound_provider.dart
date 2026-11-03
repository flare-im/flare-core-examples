import 'package:flare_im/interface/widgets/composer/composer_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 输入区 → 聊天页 的出站意图（仅 [ChatScreen] 应消费并调用 [messageServiceProvider] / [messageProvider]）。
sealed class ChatOutboundEvent {
  const ChatOutboundEvent();
}

/// 发送纯文本（含多行）；表情 pack 消息请用 [ChatOutboundSendEmojiPackKey]（会打成 `[key]` 再走文本发送管线）。
final class ChatOutboundSendText extends ChatOutboundEvent {
  final String text;
  const ChatOutboundSendText(this.text);
}

/// 点选 assets 表情：发送 `emoji` 消息（payload 为 `packKey`）。
final class ChatOutboundSendEmojiPackKey extends ChatOutboundEvent {
  final String packKey;
  const ChatOutboundSendEmojiPackKey(this.packKey);
}

/// 贴纸选择。
final class ChatOutboundSendSticker extends ChatOutboundEvent {
  final ComposerStickerPick pick;
  const ChatOutboundSendSticker(this.pick);
}

enum ChatRichDocInputFormat { markdown, html, docJson }

final class ChatOutboundSendRichDoc extends ChatOutboundEvent {
  final ChatRichDocInputFormat format;
  final String source;

  const ChatOutboundSendRichDoc({required this.format, required this.source});
}

enum ChatBusinessMessageKind { location, contactCard, schedule, task }

/// 更多面板里的业务消息入口。由聊天页收集表单数据后再调用 SDK build/send。
final class ChatOutboundRequestBusinessMessage extends ChatOutboundEvent {
  final ChatBusinessMessageKind kind;
  const ChatOutboundRequestBusinessMessage(this.kind);
}

class ChatOutboundNotifier extends StateNotifier<ChatOutboundEvent?> {
  ChatOutboundNotifier() : super(null);

  void dispatch(ChatOutboundEvent event) => state = event;

  void clear() => state = null;
}

final chatOutboundProvider = StateNotifierProvider.autoDispose
    .family<ChatOutboundNotifier, ChatOutboundEvent?, String>(
      (ref, _) => ChatOutboundNotifier(),
    );
