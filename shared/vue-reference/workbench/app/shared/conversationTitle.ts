import { ConversationType } from "@flare-im/sdk/web";
import { translateFlare } from "@flare-im/vue-ui/i18n";

export type ConversationTitleParticipant = {
  readonly userId?: string;
  readonly nickname?: string;
};

export type ConversationTitleSource = {
  readonly conversationType?: ConversationType;
  readonly remark?: string;
  readonly displayName?: string;
  readonly channelId?: string;
  readonly conversationId?: string;
  readonly memberPreview?: readonly ConversationTitleParticipant[];
  readonly participants?: readonly ConversationTitleParticipant[];
};

export function conversationTitle(
  item: ConversationTitleSource | undefined,
  currentUserId?: string,
): string {
  if (!item) return "";
  const peer = resolveConversationPeer(item, currentUserId);
  if (item.conversationType === ConversationType.Single) {
    return firstText(
      item.remark,
      peer?.nickname,
      peer?.userId,
      item.channelId,
      item.displayName,
      item.conversationId,
    );
  }
  const groupMemberTitle = buildGroupMemberTitle(item);
  const displayName = item.displayName?.trim();
  return firstText(
    item.remark,
    displayName && !isMemberOnlyGroupTitle(displayName, item) ? displayName : undefined,
    groupMemberTitle,
    displayName,
    item.channelId,
    item.conversationId,
  );
}

export function resolveConversationPeer(
  item: ConversationTitleSource,
  currentUserId?: string,
): ConversationTitleParticipant | undefined {
  const current = currentUserId?.trim();
  const participants = [...(item.memberPreview ?? []), ...(item.participants ?? [])];
  return participants.find((participant) => {
    const userId = participant.userId?.trim();
    return Boolean(userId && userId !== current);
  }) ?? participants.find((participant) => Boolean(participant.userId?.trim()));
}

function firstText(...values: Array<string | undefined>): string {
  for (const value of values) {
    const trimmed = value?.trim();
    if (trimmed) return trimmed;
  }
  return "";
}

function buildGroupMemberTitle(item: ConversationTitleSource): string | undefined {
  const labels = collectGroupMemberLabels(item);
  const separator = translateFlare("title.memberSeparator");
  return labels.length >= 2
    ? translateFlare("title.groupMembers", { names: labels.join(separator) })
    : undefined;
}

function isMemberOnlyGroupTitle(displayName: string, item: ConversationTitleSource): boolean {
  const labels = collectGroupMemberLabels(item);
  return labels.length >= 2 && labels.includes(displayName);
}

function collectGroupMemberLabels(item: ConversationTitleSource): string[] {
  const labels = [
    ...channelUserIds(item.channelId),
    ...(item.memberPreview ?? []).map(participantLabel),
    ...(item.participants ?? []).map(participantLabel),
  ].filter((label): label is string => Boolean(label));
  return [...new Set(labels)];
}

function participantLabel(participant: ConversationTitleParticipant): string | undefined {
  return firstText(participant.nickname, participant.userId);
}

function channelUserIds(channelId: string | undefined): string[] {
  const channel = channelId?.trim();
  if (!channel?.startsWith("users:")) return [];
  return channel
    .slice("users:".length)
    .split(/[\s,，、;；|]+/)
    .map((id) => id.trim())
    .filter((id) => id.length > 0);
}
