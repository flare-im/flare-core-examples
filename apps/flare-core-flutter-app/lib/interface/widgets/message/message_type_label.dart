import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';

/// 与 `flare.common.v1.MessageType`（proto wire）及解码后 [MessageContent.contentType] 对齐的**简短类型名**，
/// 用于合并转发条目角标、会话摘要等；文案走 [FlareChatCopy]（中英双语）。
///
/// [messageTypeWire] 来自 `ForwardItem.messageType` / 消息 `messageType`；为 null 或 0 时回退到 [content]。
String messageTypeShortLabel(
  int? messageTypeWire,
  MessageContent content,
  FlareChatCopy i18n,
) {
  if (messageTypeWire != null && messageTypeWire != 0) {
    switch (messageTypeWire) {
      case 1:
        return i18n.typeText;
      case 2:
        return i18n.typeImage;
      case 3:
        return i18n.typeVideo;
      case 4:
        return i18n.typeAudio;
      case 5:
        return i18n.typeFile;
      case 6:
        return i18n.typeLocation;
      case 7:
        return i18n.typeCard;
      case 8:
        return i18n.typeSticker;
      case 9:
        return i18n.typeEmoji;
      case 11:
        return i18n.typeLink;
      case 12:
        return i18n.typeForward;
      case 13:
        return i18n.typeMiniProgram;
      case 14:
        return i18n.typeTopic;
      case 15:
        return i18n.typeQuote;
      case 30:
        return i18n.typeRichText;
      case 32:
        return i18n.typeImageGroup;
      case 60:
        return i18n.typeSystem;
      case 61:
        return i18n.typeNotification;
      case 80:
        return i18n.typeVote;
      case 81:
        return i18n.typeTask;
      case 82:
        return i18n.typeSchedule;
      case 83:
        return i18n.typeAnnouncement;
      case 100:
        return i18n.typeCustom;
      default:
        return i18n.typeUnknown(messageTypeWire);
    }
  }
  return messageTypeShortLabelFromContentType(content.contentType, i18n);
}

/// 仅根据 `contentType` 解析简短标签；无 wire 或与 proto 不一致时使用。
String messageTypeShortLabelFromContentType(
  String contentType,
  FlareChatCopy i18n,
) {
  switch (contentType) {
    case 'text':
      return i18n.typeText;
    case 'image':
      return i18n.typeImage;
    case 'video':
      return i18n.typeVideo;
    case 'audio':
      return i18n.typeAudio;
    case 'file':
      return i18n.typeFile;
    case 'location':
      return i18n.typeLocation;
    case 'card':
      return i18n.typeCard;
    case 'sticker':
      return i18n.typeSticker;
    case 'emoji':
      return i18n.typeEmoji;
    case 'link_card':
      return i18n.typeLink;
    case 'forward':
      return i18n.typeForward;
    case 'mini_program':
      return i18n.typeMiniProgram;
    case 'quote':
      return i18n.typeQuote;
    case 'rich_text':
    case 'rich_doc':
      return i18n.typeRichText;
    case 'vote':
      return i18n.typeVote;
    case 'task':
      return i18n.typeTask;
    case 'schedule':
      return i18n.typeSchedule;
    case 'announcement':
      return i18n.typeAnnouncement;
    case 'notification':
      return i18n.typeNotification;
    case 'image_group':
      return i18n.typeImageGroup;
    case 'placeholder':
      return i18n.typePlaceholder;
    case 'system':
      return i18n.typeSystem;
    case 'thread':
      return i18n.typeTopic;
    case 'custom':
      return i18n.typeCustom;
    default:
      return i18n.typeMessage;
  }
}
