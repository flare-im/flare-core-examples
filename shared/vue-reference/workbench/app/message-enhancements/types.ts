import type { Conversation, Message } from "@flare-im/sdk/web";

export type EnhancedMessageKind =
  | "file"
  | "image"
  | "video"
  | "audio"
  | "location"
  | "card"
  | "schedule"
  | "task"
  | "linkCard"
  | "richText"
  | "imageGroup"
  | "miniProgram"
  | "vote"
  | "thread"
  | "notification"
  | "announcement";

export type MessageOperationKey =
  | "react"
  | "reply"
  | "forward"
  | "copy"
  | "edit"
  | "delete"
  | "recall"
  | "pin"
  | "multiSelect";

export type OperationAvailability = {
  enabled: boolean;
  reason?: string;
};

export type MessageCapabilities = Record<
  | "canReact"
  | "canReply"
  | "canForward"
  | "canCopy"
  | "canEdit"
  | "canDelete"
  | "canRecall"
  | "canPin"
  | "canMultiSelect",
  OperationAvailability
>;

export type CapabilityContext = {
  currentUserId: string;
  connected: boolean;
  multiSelectMode?: boolean;
};

export type EnhancedPayloadBase = {
  kind: EnhancedMessageKind;
  payloadVersion: 1;
  ext?: Record<string, unknown>;
};

export type ComposerPayloadRequest = {
  op: string;
  kind: EnhancedMessageKind;
  params: Record<string, unknown>;
  previewText: string;
};

export type ForwardMode = "separate" | "merged";

export type MessagePinScope = "conversation" | "self";

export type ForwardRequest = {
  mode: ForwardMode;
  targetConversationId: string;
  messageIds: string[];
  title?: string;
};

export type BatchOperationResult = {
  total: number;
  succeeded: string[];
  failed: { messageId: string; reason: string }[];
};

export type MediaComposerPreviewItem = {
  id: string;
  kind: EnhancedMessageKind;
  name: string;
  sourcePath?: string;
  previewUrl?: string;
  mimeType?: string;
  size?: number;
  file?: File;
};

export type MessageOperationSdk = {
  activeConversationId: { value: string };
  currentUserId: { value: string };
  conversations: { value: readonly Conversation[] };
  messages: { value: readonly Message[] };
  addReaction(messageId: string, emoji: string): Promise<void>;
  removeReaction(messageId: string, emoji: string): Promise<void>;
  toggleReaction(messageId: string, emoji: string): Promise<void>;
  buildAndSendMessage(op?: string, overrides?: Record<string, unknown>): Promise<void>;
  forwardMessagesToConversation(request: {
    conversationId: string;
    messageIds: string[];
    merge?: boolean;
    title?: string;
  }): Promise<Message>;
  deleteMessageForSelf(messageId: string): Promise<void>;
  setMessagePinned(
    messageId: string,
    pinned: boolean,
    options?: { scope?: MessagePinScope },
  ): Promise<void>;
  refreshActiveChat(): Promise<void>;
};

export function messageStableId(message: Pick<Message, "serverId" | "clientMsgId">): string {
  return message.serverId || message.clientMsgId;
}

/**
 * 消息是否就是这个 id 指向的那条——serverId 与 clientMsgId 都算。
 *
 * 同一条消息在不同来路会用不同的 id：菜单动作走 clientMsgId 优先
 * （buildMessageMenuOptions），选中集的键走 serverId 优先（messageStableId）。
 * 已同步的消息两个 id 都有，用单一优先级去比就永远对不上：多选后底部显示
 * "1 / 1 已选"，转发弹窗的消息预览却是 0 条、确认按钮灰着，转发发不出去。
 *
 * 与其强行统一某一端（会波及 reply / recall / edit 等既有契约），不如在比较
 * 时同时认两个 id——kit 里 messageMatchesId 早就是这个做法。
 */
export function messageHasId(
  message: Pick<Message, "serverId" | "clientMsgId">,
  id: string,
): boolean {
  return Boolean(id) && (message.serverId === id || message.clientMsgId === id);
}

export function messageIsPinned(message: Message): boolean {
  return message.attributes?.pinned === "true";
}
