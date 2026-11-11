import * as assert from 'node:assert/strict';
import { test } from 'node:test';
import { MessageContentType, ConversationType, type Conversation, type Message } from '@flare-im/sdk/model';
import { conversationToItem, messageToTimelineMessage, messagesToTimeline } from '../src/application/mappers/sdkViewModels.ts';

function baseConversation(overrides: Partial<Conversation> = {}): Conversation {
  return {
    avatarUrl: '',
    businessType: 'im',
    channelId: 'alice',
    conversationId: 'conv-alice',
    conversationType: ConversationType.Single,
    createdAt: 1710000000000,
    displayName: 'Alice',
    ext: {},
    isArchived: false,
    isMuted: false,
    isPinned: false,
    lastReadSeq: 8,
    lastSenderAvatarUrl: '',
    lastSenderNickname: 'Alice',
    maxSeq: 12,
    memberPreview: [],
    membersCount: 2,
    mentionCount: 0,
    mentionMe: false,
    participantVersion: 1,
    participants: [],
    peerReadSeq: 9,
    unreadCount: 4,
    updatedAt: 1710000001000,
    version: 1,
    visibleAfterSeq: 0,
    ...overrides,
  };
}

function baseMessage(overrides: Partial<Message> = {}): Message {
  return {
    attributes: {},
    channelId: 'alice',
    clientCreatedAt: 1710000000000,
    clientMsgId: 'client-1',
    content: { contentType: MessageContentType.Text, data: { text: 'hello' } },
    conversationId: 'conv-alice',
    conversationSeq: 12,
    conversationType: 1,
    createdAt: 1710000002000,
    extensions: {},
    isEdited: false,
    isRead: false,
    isRecalled: false,
    mentionAll: false,
    mentionUsers: [],
    messageType: 1,
    reactions: [],
    senderAvatar: '',
    senderDisplayName: 'Alice',
    senderId: 'alice',
    senderName: 'Alice',
    serverId: 'server-1',
    source: 0,
    status: 0,
    textPreview: 'hello',
    updatedAt: 1710000002000,
    version: 1,
    timelineKey: 'timeline-1',
    timelineSortTs: 1710000002000,
    ...overrides,
  };
}

test('conversationToItem maps SDK conversation fields into stable RN view model', () => {
  const item = conversationToItem(baseConversation({
    avatarUrl: 'https://avatar.test/a.png',
    displayName: 'Alice Zhang',
    draft: 'draft text',
    isPinned: true,
    isMuted: true,
    mentionMe: true,
    lastMessagePreview: 'latest preview',
    lastMessageAt: 1710003600000,
  }));

  assert.equal(item.id, 'conv-alice');
  assert.equal(item.channelId, 'alice');
  assert.equal(item.title, 'Alice Zhang');
  assert.equal(item.avatar, 'A');
  assert.equal(item.avatarUrl, 'https://avatar.test/a.png');
  assert.equal(item.draft, 'draft text');
  assert.equal(item.pinned, true);
  assert.equal(item.muted, true);
  assert.equal(item.mentionMe, true);
  assert.equal(item.lastMessagePreview, 'latest preview');
  assert.equal(item.unreadCount, 4);
  assert.equal(item.maxSeq, 12);
  assert.equal(item.peerReadSeq, 9);
});

test('conversationToItem does not derive preview from shadow message fields', () => {
  const item = conversationToItem(baseConversation({
    lastMessagePreview: undefined,
    lastMessage: {
      messageId: 'server-shadow',
      senderId: 'alice',
      text: 'shadow preview must not leak',
      time: 1710003600000,
      type: 1,
    },
  }));

  assert.equal(item.lastMessagePreview, '暂无消息');
});

test('conversationToItem formats storage preview payloads for emoji and stickers', () => {
  const sticker = conversationToItem(baseConversation({
    lastMessagePreview: JSON.stringify({ k: 'im.preview.sticker' }),
  }));
  const emoji = conversationToItem(baseConversation({
    lastMessagePreview: JSON.stringify({ k: 'im.preview.emoji', a: { e: 'blue_heart' } }),
  }));

  assert.equal(sticker.lastMessagePreview, '[贴纸]');
  assert.equal(sticker.lastMessagePreviewKind, 'sticker');
  assert.equal(emoji.lastMessagePreview, 'blue_heart');
  assert.equal(emoji.lastMessagePreviewKind, 'emoji');
});

test('messageToTimelineMessage prefers SDK stable identity and local-state status', () => {
  const failed = messageToTimelineMessage(baseMessage({
    serverId: '',
    clientMsgId: 'client-failed',
    senderId: 'me',
    senderDisplayName: 'Me',
    localState: { failed: true, sending: false, isLocal: true, sortTs: 1710000003000 },
    content: { contentType: MessageContentType.File, data: { name: 'report.pdf' } },
    textPreview: 'report.pdf',
    reactions: [{ emoji: '🔥', count: 2, userIds: ['me', 'alice'] }],
  }), 'me');

  assert.equal(failed.id, 'client-failed');
  assert.equal(failed.direction, 'outbound');
  assert.equal(failed.status, 'failed');
  assert.equal(failed.contentType, MessageContentType.File);
  assert.deepEqual(failed.reactions, ['🔥']);
});

test('messagesToTimeline preserves core SDK timeline order without client sorting', () => {
  const first = baseMessage({ serverId: 'server-late', conversationSeq: 20, textPreview: 'late' });
  const second = baseMessage({ serverId: 'server-early', conversationSeq: 1, textPreview: 'early' });
  const timeline = messagesToTimeline([first, second], 'me');

  assert.deepEqual(timeline.map((item) => item.text), ['late', 'early']);
});
