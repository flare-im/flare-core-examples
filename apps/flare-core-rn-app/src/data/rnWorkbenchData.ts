import { ConnectionEventName, MessageEventName } from '@flare-im/sdk/model';
import type { ConversationFilter } from '../types';

export const filters: Array<{ label: string; value: ConversationFilter }> = [
  { label: '全部', value: 'all' },
  { label: '未读', value: 'unread' },
  { label: '@我', value: 'mention' },
  { label: '置顶', value: 'pinned' },
  { label: '免打扰', value: 'muted' },
  { label: '归档', value: 'archived' },
  { label: '草稿', value: 'draft' },
];

export const quickEmoji = ['😀', '👍', '🔥', '❤️', '🎉', '🙏'];
export const stickerPacks = ['Flare', 'Ready', 'Ship', 'Ack'];
export const sdkEvents = [
  `connection.${ConnectionEventName.Ready}`,
  'conversation.updated',
  `message.${MessageEventName.ReceivedBatch}`,
  `message.${MessageEventName.SendAck}`,
  `message.${MessageEventName.ReadReceipt}`,
];
