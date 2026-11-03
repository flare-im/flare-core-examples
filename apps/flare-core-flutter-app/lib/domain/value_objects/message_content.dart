import 'package:equatable/equatable.dart';

/// 消息内容基类
///
/// 使用 sealed class 实现类型安全的消息内容
sealed class MessageContent extends Equatable {
  const MessageContent();

  /// 获取预览文本
  String get previewText;

  /// 获取内容类型
  String get contentType;

  @override
  List<Object?> get props => [];
}

/// 文本消息内容
class TextContent extends MessageContent {
  final String text;

  const TextContent(this.text);

  @override
  String get previewText => text;

  @override
  String get contentType => 'text';

  @override
  List<Object?> get props => [text];
}

/// RichDoc v2 富文档消息内容。
///
/// 示例端只负责展示 core 规范化后的可读预览；文档结构、搜索文本和渲染提示仍由 SDK/core 产出。
class RichDocContent extends MessageContent {
  final String docJson;
  final String plainText;
  final String? sourceFormat;

  const RichDocContent({
    required this.docJson,
    required this.plainText,
    this.sourceFormat,
  });

  @override
  String get previewText {
    final t = plainText.trim();
    if (t.isNotEmpty) return t;
    return '[富文本]';
  }

  @override
  String get contentType => 'rich_text';

  @override
  List<Object?> get props => [docJson, plainText, sourceFormat];
}

/// 图片消息内容
class ImageContent extends MessageContent {
  final String url;
  final String? localPath;

  /// 核心里存的图片 id（`source.imageId`）：显示经 SDK 缓存解析、保存到本机都按它取。
  /// 上传完成前没有（那时只有本机文件）。
  final String? fileId;
  final int? width;
  final int? height;
  final int? size;

  /// 与 SDK `ImageElem.description` / 会话列表摘要一致；有值时在气泡内展示说明文案。
  final String? description;

  const ImageContent({
    required this.url,
    this.localPath,
    this.fileId,
    this.width,
    this.height,
    this.size,
    this.description,
  });

  @override
  String get previewText {
    final d = (description ?? '').trim();
    if (d.isNotEmpty) return '[图片] $d';
    return '[图片]';
  }

  @override
  String get contentType => 'image';

  @override
  List<Object?> get props => [
    url,
    localPath,
    fileId,
    width,
    height,
    size,
    description,
  ];
}

/// 多图（相册），与 SDK `Elem::ImageGroup` / `contentType: image_group`（core 标准枚举值）对应。
class ImageGroupContent extends MessageContent {
  final List<String> imageUrls;
  final String? description;

  const ImageGroupContent({required this.imageUrls, this.description});

  @override
  String get previewText {
    final n = imageUrls.where((e) => e.trim().isNotEmpty).length;
    if (n <= 0) return '[多图]';
    return '[多图] $n 张';
  }

  @override
  String get contentType => 'image_group';

  @override
  List<Object?> get props => [imageUrls, description];
}

/// 视频消息内容
class VideoContent extends MessageContent {
  final String url;
  final String? localPath;

  /// 核心里存的视频 id（`videoId`）：保存到本机按它取。
  final String? fileId;
  final String? thumbnailUrl;
  final int? width;
  final int? height;
  final int? duration;
  final int? size;

  /// 与 SDK `VideoElem.description` 一致；有值时在气泡内缩略图下方展示。
  final String? description;

  const VideoContent({
    required this.url,
    this.localPath,
    this.fileId,
    this.thumbnailUrl,
    this.width,
    this.height,
    this.duration,
    this.size,
    this.description,
  });

  @override
  String get previewText {
    final d = (description ?? '').trim();
    if (d.isNotEmpty) return '[视频] $d';
    return '[视频]';
  }

  @override
  String get contentType => 'video';

  @override
  List<Object?> get props => [
    url,
    localPath,
    fileId,
    thumbnailUrl,
    width,
    height,
    duration,
    size,
    description,
  ];
}

/// 音频消息内容
class AudioContent extends MessageContent {
  final String url;
  final String? localPath;
  final int? duration;
  final int? size;

  const AudioContent({
    required this.url,
    this.localPath,
    this.duration,
    this.size,
  });

  @override
  String get previewText => '[语音]';

  @override
  String get contentType => 'audio';

  @override
  List<Object?> get props => [url, localPath, duration, size];
}

/// 文件消息内容
class FileContent extends MessageContent {
  final String url;
  final String? localPath;

  /// 核心里存的文件 id（`fileId`）：保存到本机按它取。
  final String? fileId;
  final String filename;
  final int? size;

  const FileContent({
    required this.url,
    this.localPath,
    this.fileId,
    required this.filename,
    this.size,
  });

  @override
  String get previewText => '[文件] $filename';

  @override
  String get contentType => 'file';

  @override
  List<Object?> get props => [url, localPath, fileId, filename, size];
}

/// 位置消息内容
class LocationContent extends MessageContent {
  final double latitude;
  final double longitude;
  final String? address;
  final String? title;
  final int? zoom;
  final String? snapshotUrl;
  final String? snapshotLocalPath;

  const LocationContent({
    required this.latitude,
    required this.longitude,
    this.address,
    this.title,
    this.zoom,
    this.snapshotUrl,
    this.snapshotLocalPath,
  });

  @override
  String get previewText =>
      '[位置] ${title ?? address ?? '$latitude, $longitude'}';

  @override
  String get contentType => 'location';

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    address,
    title,
    zoom,
    snapshotUrl,
    snapshotLocalPath,
  ];
}

/// 名片消息内容
class CardContent extends MessageContent {
  final String id;
  final String? cardType;
  final String? title;
  final String? subtitle;
  final String? avatar;

  const CardContent({
    required this.id,
    this.cardType,
    this.title,
    this.subtitle,
    this.avatar,
  });

  @override
  String get previewText => '[名片] ${title ?? id}';

  @override
  String get contentType => 'card';

  @override
  List<Object?> get props => [id, cardType, title, subtitle, avatar];
}

/// 表情消息内容
class EmojiContent extends MessageContent {
  final String emoji;

  const EmojiContent(this.emoji);

  @override
  String get previewText => emoji;

  @override
  String get contentType => 'emoji';

  @override
  List<Object?> get props => [emoji];
}

/// 贴纸消息内容
class StickerContent extends MessageContent {
  final String stickerId;
  final String? packageId;
  final String? url;
  final int? width;
  final int? height;

  const StickerContent({
    required this.stickerId,
    this.packageId,
    this.url,
    this.width,
    this.height,
  });

  @override
  String get previewText => '[贴纸]';

  @override
  String get contentType => 'sticker';

  @override
  List<Object?> get props => [stickerId, packageId, url, width, height];
}

/// 引用回复消息内容
class QuoteContent extends MessageContent {
  final String quotedMessageId;
  final MessageContent content;
  final String? quotedTextPreview;

  /// 被引用方展示名（如「张总」）；无则引用区不显示昵称行。
  final String? quotedSenderName;

  /// 被引用消息发送方用户 id（与 SDK JSON `quotedSenderId` 一致）；可与列表内消息对照解析展示名。
  final String? quotedSenderId;

  const QuoteContent({
    required this.quotedMessageId,
    required this.content,
    this.quotedTextPreview,
    this.quotedSenderName,
    this.quotedSenderId,
  });

  @override
  String get previewText => content.previewText;

  @override
  String get contentType => 'quote';

  @override
  List<Object?> get props => [
    quotedMessageId,
    content,
    quotedTextPreview,
    quotedSenderName,
    quotedSenderId,
  ];
}

/// 话题回复（与 SDK `thread` / `create_thread_reply` 对齐）。
class ThreadReplyContent extends MessageContent {
  final String threadId;
  final String text;
  final String? rootMessageId;

  const ThreadReplyContent({
    required this.threadId,
    required this.text,
    this.rootMessageId,
  });

  @override
  String get previewText {
    final t = text.trim();
    if (t.isNotEmpty) return '[话题] $t';
    return '[话题]';
  }

  @override
  String get contentType => 'thread';

  @override
  List<Object?> get props => [threadId, text, rootMessageId];
}

/// 合并转发中的单条快照（与 proto `ForwardItem` / SDK `items[]` 对应）。
class ForwardSnapshotItem extends Equatable {
  final String? sourceMessageId;
  final String? sourceSenderId;
  final String? senderName;
  final String? plainText;

  /// 与 `MessageType` 的 proto wire 值一致，用于展示类型标签等。
  final int? messageTypeWire;
  final MessageContent content;
  final DateTime? sentAt;

  const ForwardSnapshotItem({
    this.sourceMessageId,
    this.sourceSenderId,
    this.senderName,
    this.plainText,
    this.messageTypeWire,
    required this.content,
    this.sentAt,
  });

  @override
  List<Object?> get props => [
    sourceMessageId,
    sourceSenderId,
    senderName,
    plainText,
    messageTypeWire,
    content,
    sentAt,
  ];
}

/// 转发消息内容（单条扁平展示 / 多条合并卡片 + 详情）。
class ForwardContent extends MessageContent {
  /// 附言或会话标题（proto `title`，可为空）。
  final String forwardTitle;
  final List<ForwardSnapshotItem> items;

  const ForwardContent({this.forwardTitle = '', this.items = const []});

  @override
  String get previewText {
    if (items.isEmpty) return '[转发]';
    if (items.length == 1) return items.first.content.previewText;
    return '[转发] ${items.length} 条';
  }

  @override
  String get contentType => 'forward';

  @override
  List<Object?> get props => [forwardTitle, items];
}

/// 链接卡片（与 `message_content.proto` 里 `LinkCardContent`、SDK `linkCard` / `LinkCardElem` 对齐）
///
/// SDK JSON：`url`、`title`、`description`、`thumbnailUrl`、`siteName`。
class LinkCardContent extends MessageContent {
  final String url;
  final String? title;
  final String? summary;
  final String? siteName;

  /// 对应 SDK JSON 字段 `thumbnailUrl`。
  final String? thumbnailUrl;

  const LinkCardContent({
    required this.url,
    this.title,
    this.summary,
    this.siteName,
    this.thumbnailUrl,
  });

  @override
  String get previewText {
    final t = (title ?? '').trim();
    if (t.isNotEmpty) return t;
    final u = url.trim();
    if (u.isNotEmpty) return '[链接] $u';
    return '[链接]';
  }

  @override
  String get contentType => 'link_card';

  @override
  List<Object?> get props => [url, title, summary, siteName, thumbnailUrl];
}

/// 小程序（与 `message_content.proto` [MiniProgramContent]、SDK `mini_program` core 标准枚举值对齐）
class MiniProgramContent extends MessageContent {
  final String appId;
  final String? title;
  final String? pagePath;
  final String? thumbnailUrl;
  final String? description;

  const MiniProgramContent({
    required this.appId,
    this.title,
    this.pagePath,
    this.thumbnailUrl,
    this.description,
  });

  @override
  String get previewText {
    final t = (title ?? '').trim();
    if (t.isNotEmpty) return t;
    return '[小程序]';
  }

  @override
  String get contentType => 'mini_program';

  @override
  List<Object?> get props => [
    appId,
    title,
    pagePath,
    thumbnailUrl,
    description,
  ];
}

/// 通知（与 SDK `notification` 对齐）
class NotificationContent extends MessageContent {
  final String? title;
  final String? body;
  final String? notificationType;
  final Map<String, String> data;

  const NotificationContent({
    this.title,
    this.body,
    this.notificationType,
    this.data = const <String, String>{},
  });

  NotificationContent copyWithData(Map<String, String> nextData) {
    return NotificationContent(
      title: title,
      body: body,
      notificationType: notificationType,
      data: nextData,
    );
  }

  @override
  String get previewText {
    final b = (body ?? '').trim();
    if (b.isNotEmpty) return b;
    final t = (title ?? '').trim();
    if (t.isNotEmpty) return t;
    return '[通知]';
  }

  @override
  String get contentType => 'notification';

  @override
  List<Object?> get props => [title, body, notificationType, data];
}

/// 投票（与 SDK `vote` 对齐）
class VoteContent extends MessageContent {
  final String? voteId;
  final String? headline;
  final List<String> options;
  final Map<String, String> metadata;

  const VoteContent({
    this.voteId,
    this.headline,
    this.options = const [],
    this.metadata = const {},
  });

  @override
  String get previewText => '[投票]';

  @override
  String get contentType => 'vote';

  @override
  List<Object?> get props => [voteId, headline, options, metadata];
}

/// 任务（与 SDK `task` 对齐）
class TaskContent extends MessageContent {
  final String? taskId;
  final String? title;
  final String? detail;
  final Map<String, String> metadata;
  final List<String> participantUserIds;

  const TaskContent({
    this.taskId,
    this.title,
    this.detail,
    this.metadata = const {},
    this.participantUserIds = const [],
  });

  @override
  String get previewText {
    final t = (title ?? '').trim();
    if (t.isNotEmpty) return '[任务] $t';
    return '[任务]';
  }

  @override
  String get contentType => 'task';

  @override
  List<Object?> get props => [
    taskId,
    title,
    detail,
    metadata,
    participantUserIds,
  ];
}

/// 日程（与 SDK `schedule` 对齐）
class ScheduleContent extends MessageContent {
  final String? scheduleId;
  final String? title;
  final String? timeRange;
  final Map<String, String> metadata;
  final List<String> participantUserIds;

  const ScheduleContent({
    this.scheduleId,
    this.title,
    this.timeRange,
    this.metadata = const {},
    this.participantUserIds = const [],
  });

  @override
  String get previewText {
    final t = (title ?? '').trim();
    if (t.isNotEmpty) return '[日程] $t';
    return '[日程]';
  }

  @override
  String get contentType => 'schedule';

  @override
  List<Object?> get props => [
    scheduleId,
    title,
    timeRange,
    metadata,
    participantUserIds,
  ];
}

/// 公告（与 SDK `announcement` 对齐）
class AnnouncementContent extends MessageContent {
  final String? announcementId;
  final String? headline;
  final String? body;
  final Map<String, String> metadata;

  const AnnouncementContent({
    this.announcementId,
    this.headline,
    this.body,
    this.metadata = const {},
  });

  @override
  String get previewText {
    final t = (headline ?? '').trim();
    if (t.isNotEmpty) return '[公告] $t';
    return '[公告]';
  }

  @override
  String get contentType => 'announcement';

  @override
  List<Object?> get props => [announcementId, headline, body, metadata];
}

/// 占位消息（与 SDK `placeholder` 对齐）
class PlaceholderMessageContent extends MessageContent {
  final String fallbackText;

  const PlaceholderMessageContent({required this.fallbackText});

  @override
  String get previewText => fallbackText;

  @override
  String get contentType => 'placeholder';

  @override
  List<Object?> get props => [fallbackText];
}
