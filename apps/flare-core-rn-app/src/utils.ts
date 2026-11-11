import { MessageContentType } from '@flare-im/sdk/model';
import { colors } from './theme/tokens';
import type { ConversationItem, PresenceStatus, SdkStatus, TimelineMessage, UploadTask } from './types';

export function connectionText(status: SdkStatus): string {
  if (status === 'ready') return 'Ready';
  if (status === 'connecting') return 'Connecting';
  if (status === 'disconnected') return 'Disconnected';
  if (status === 'error') return 'Bridge Missing';
  return 'Idle';
}

export function statusColor(status: SdkStatus): string {
  if (status === 'ready') return colors.success;
  if (status === 'connecting') return colors.warning;
  if (status === 'error') return colors.danger;
  if (status === 'disconnected') return colors.textMuted;
  return colors.warning;
}

export function conversationSubtitle(conversation: ConversationItem): string {
  if (conversation.membersCount > 2) return `${conversation.membersCount} 成员`;
  if (conversation.presence === 'online') return '在线';
  if (conversation.presence === 'busy') return '忙碌';
  return '离线';
}

export function presenceDotStyle(status: PresenceStatus) {
  if (status === 'online') return { backgroundColor: colors.success };
  if (status === 'busy') return { backgroundColor: colors.warning };
  return { backgroundColor: colors.textMuted };
}

export function messageStatusText(status: TimelineMessage['status']): string {
  switch (status) {
    case 'sending':
      return '发送中';
    case 'sent':
      return '已发送';
    case 'delivered':
      return '已送达';
    case 'read':
      return '已读';
    case 'failed':
      return '失败';
    case 'received':
      return '已接收';
  }
}

export function renderMessageText(message: TimelineMessage): string {
  if (message.contentType === MessageContentType.File) return `📎 ${message.text}`;
  if (message.contentType === MessageContentType.Image) return `🖼 ${message.text}`;
  if (message.contentType === MessageContentType.Sticker) return `🎭 ${message.text}`;
  if (message.contentType === MessageContentType.Emoji) return message.text;
  return message.text;
}

export function uploadStatusText(status: UploadTask['status']): string {
  switch (status) {
    case 'queued':
      return '等待上传';
    case 'uploading':
      return '上传中';
    case 'success':
      return '上传完成';
    case 'failed':
      return '上传失败';
  }
}
