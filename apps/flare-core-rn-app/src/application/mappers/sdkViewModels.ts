import { MessageContentType, type Conversation, type Message } from '@flare-im/sdk/model';
import type { ConversationItem, TimelineMessage } from '../../types';

const FALLBACK_AVATAR_COLOR = '#1677ff';

export function conversationToItem(conversation: Conversation): ConversationItem {
  const displayName = conversation.displayName || conversation.channelId || conversation.conversationId;
  const preview = formatStoragePreview(conversation.lastMessagePreview ?? '');
  return {
    id: conversation.conversationId,
    channelId: conversation.channelId,
    title: displayName,
    avatar: avatarInitial(displayName),
    avatarUrl: conversation.avatarUrl || undefined,
    avatarColor: conversation.ext.avatarColor || FALLBACK_AVATAR_COLOR,
    presence: presenceFromExt(conversation.ext.presence),
    lastMessagePreview: preview.text || '暂无消息',
    lastMessagePreviewKind: preview.kind,
    lastMessageAt: formatMessageTime(conversation.lastMessageAt ?? conversation.updatedAtTs ?? conversation.updatedAt),
    unreadCount: conversation.unreadCount,
    mentionMe: conversation.mentionMe || conversation.mentionCount > 0,
    pinned: conversation.isPinned,
    muted: conversation.isMuted,
    archived: conversation.isArchived,
    draft: conversation.draft ?? '',
    maxSeq: conversation.maxSeq,
    peerReadSeq: conversation.peerReadSeq,
    membersCount: conversation.membersCount,
  };
}

export function messageToTimelineMessage(message: Message, currentUserId: string): TimelineMessage {
  const direction = message.senderId === currentUserId ? 'outbound' : 'inbound';
  return {
    id: stableMessageId(message),
    clientMsgId: message.clientMsgId || undefined,
    serverId: message.serverId || undefined,
    authorId: message.senderId,
    authorName: message.senderDisplayName || message.senderName || message.senderId,
    direction,
    text: messageText(message),
    time: formatMessageTime(message.timelineSortTs || message.createdAt || message.clientCreatedAt),
    seq: message.conversationSeq,
    status: messageStatus(message, direction),
    contentType: message.content?.contentType ?? MessageContentType.Text,
    reactions: message.reactions.map((reaction) => reaction.emoji),
    pinned: message.attributes.pinned === 'true',
    recalled: message.isRecalled,
    edited: message.isEdited,
  };
}

export function messagesToTimeline(messages: readonly Message[], currentUserId: string): TimelineMessage[] {
  return messages.map((message) => messageToTimelineMessage(message, currentUserId));
}

function stableMessageId(message: Message): string {
  if (message.serverId) return message.serverId;
  if (message.clientMsgId) return message.clientMsgId;
  if (message.timelineKey) return message.timelineKey;
  return `${message.conversationId}:${message.conversationSeq}:${message.timelineSortTs || message.createdAt}`;
}

function messageStatus(message: Message, direction: TimelineMessage['direction']): TimelineMessage['status'] {
  if (message.localState?.failed) return 'failed';
  if (message.localState?.sending) return 'sending';
  if (direction === 'inbound') return 'received';
  if (message.isRead) return 'read';
  if (message.serverId) return 'delivered';
  return 'sent';
}

function messageText(message: Message): string {
  if (message.isRecalled) return '这条消息已撤回';
  if (message.textPreview) return formatStoragePreview(message.textPreview).text;
  const content = message.content;
  if (!content) return '';
  if (content.contentType === MessageContentType.Text) return stringFromData(content.data.text);
  if (content.contentType === MessageContentType.File) return stringFromData(content.data.name) || '[文件]';
  if (content.contentType === MessageContentType.Image) return '[图片]';
  if (content.contentType === MessageContentType.Sticker) return '[贴纸]';
  if (content.contentType === MessageContentType.Emoji) return stringFromData(content.data.emoji) || '[表情]';
  return `[${content.contentType}]`;
}

function stringFromData(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function avatarInitial(value: string): string {
  return (value.trim().slice(0, 1) || '?').toUpperCase();
}

function presenceFromExt(value: string | undefined): ConversationItem['presence'] {
  if (value === 'online' || value === 'busy' || value === 'offline') return value;
  return 'offline';
}

function formatMessageTime(timestamp: number | undefined): string {
  if (!timestamp) return '-';
  return new Date(timestamp).toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
}

function formatStoragePreview(raw: string): { text: string; kind: ConversationItem['lastMessagePreviewKind'] } {
  const text = raw.trim();
  if (!text) return { text: '', kind: 'text' };
  if (!text.startsWith('{')) return { text, kind: 'text' };
  try {
    const parsed = JSON.parse(text) as { k?: unknown; a?: unknown };
    const key = typeof parsed.k === 'string' ? parsed.k : '';
    const args = isRecord(parsed.a) ? parsed.a : {};
    if (!key.startsWith('im.preview.')) return { text, kind: 'text' };
    switch (key) {
      case 'im.preview.user_text':
        return { text: readString(args, 't'), kind: 'text' };
      case 'im.preview.sticker':
        return { text: '[贴纸]', kind: 'sticker' };
      case 'im.preview.emoji':
        return { text: readString(args, 'e') || '[表情]', kind: 'emoji' };
      case 'im.preview.rich_text':
        return { text: joinText(readString(args, 'title'), readString(args, 'body')) || '[富文本]', kind: 'text' };
      case 'im.preview.image':
        return { text: args.m === true ? '[动图]' : readString(args, 'd') || '[图片]', kind: 'text' };
      case 'im.preview.video':
        return { text: readString(args, 'd') || '[视频]', kind: 'text' };
      case 'im.preview.audio':
        return { text: readString(args, 'd') || '[语音]', kind: 'text' };
      case 'im.preview.file':
        return { text: readString(args, 'n') || '[文件]', kind: 'text' };
      case 'im.preview.location': {
        const label = readString(args, 'label');
        return { text: label ? `[位置] ${label}` : '[位置]', kind: 'text' };
      }
      case 'im.preview.card': {
        const label = readString(args, 'label');
        return { text: label ? `[名片] ${label}` : '[名片]', kind: 'text' };
      }
      case 'im.preview.vote':
        return { text: '[投票]', kind: 'text' };
      case 'im.preview.task':
        return { text: readString(args, 't') ? `[任务] ${readString(args, 't')}` : '[任务]', kind: 'text' };
      case 'im.preview.schedule':
        return { text: '[日程]', kind: 'text' };
      case 'im.preview.announcement':
        return { text: readString(args, 't') ? `[公告] ${readString(args, 't')}` : '[公告]', kind: 'text' };
      default:
        return { text: readString(args, 't') || readString(args, 'body') || readString(args, 'title') || '[消息]', kind: 'text' };
    }
  } catch {
    return { text, kind: 'text' };
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return Boolean(value && typeof value === 'object' && !Array.isArray(value));
}

function readString(source: Record<string, unknown>, ...keys: string[]): string {
  for (const key of keys) {
    const value = source[key];
    if (typeof value === 'string' && value.trim()) return value.trim();
  }
  return '';
}

function joinText(...values: string[]): string {
  return values.map((value) => value.trim()).filter(Boolean).join(' ');
}
