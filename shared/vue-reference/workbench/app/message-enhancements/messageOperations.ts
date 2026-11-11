import { ref } from "vue";
import { translateFlare } from "@flare-im/vue-ui/i18n";
import type { BatchOperationResult, ComposerPayloadRequest, ForwardRequest, MessageOperationSdk, MessagePinScope } from "./types";

export type MessageOperationAdapter = ReturnType<typeof createMessageOperationAdapter>;

function errorText(error: unknown): string {
  return error instanceof Error ? error.message : String(error || translateFlare("error.operationFailed"));
}

function emptyResult(total: number): BatchOperationResult {
  return { total, succeeded: [], failed: [] };
}

export function createMessageOperationAdapter(sdk: MessageOperationSdk) {
  const busyKeys = ref<Set<string>>(new Set());

  function setBusy(key: string, busy: boolean): void {
    const next = new Set(busyKeys.value);
    if (busy) next.add(key);
    else next.delete(key);
    busyKeys.value = next;
  }

  function isBusy(key: string): boolean {
    return busyKeys.value.has(key);
  }

  function dispose(): void {
    busyKeys.value = new Set();
  }

  async function sendComposerPayload(request: ComposerPayloadRequest): Promise<void> {
    const conversationId = sdk.activeConversationId.value.trim();
    if (!conversationId) throw new Error(translateFlare("error.selectConversationFirst"));
    const key = `send:${request.kind}`;
    setBusy(key, true);
    try {
      await sdk.buildAndSendMessage(request.op, request.params);
    } finally {
      setBusy(key, false);
    }
  }

  async function toggleReaction(messageId: string, emoji: string): Promise<void> {
    const key = `reaction:${messageId}:${emoji}`;
    setBusy(key, true);
    try {
      await sdk.toggleReaction(messageId, emoji);
    } finally {
      setBusy(key, false);
    }
  }

  async function forwardMessages(request: ForwardRequest): Promise<BatchOperationResult> {
    const ids = [...request.messageIds].filter(Boolean);
    const result = emptyResult(ids.length);
    if (!request.targetConversationId) throw new Error(translateFlare("error.selectForwardTarget"));
    if (!ids.length) return result;
    const key = `forward:${request.mode}`;
    setBusy(key, true);
    try {
      if (request.mode === "merged") {
        try {
          await sdk.forwardMessagesToConversation({
            conversationId: request.targetConversationId,
            messageIds: ids,
            merge: true,
            title: request.title || translateFlare("forward.chatHistoryCount", { count: ids.length }),
          });
          result.succeeded.push(...ids);
        } catch (error) {
          result.failed.push(...ids.map((messageId) => ({ messageId, reason: errorText(error) })));
        }
      } else {
        for (const messageId of ids) {
          try {
            await sdk.forwardMessagesToConversation({
              conversationId: request.targetConversationId,
              messageIds: [messageId],
              merge: false,
              title: request.title || translateFlare("forward.defaultTitle"),
            });
            result.succeeded.push(messageId);
          } catch (error) {
            result.failed.push({ messageId, reason: errorText(error) });
          }
        }
      }
      await sdk.refreshActiveChat();
      return result;
    } finally {
      setBusy(key, false);
    }
  }

  async function deleteMessagesForSelf(messageIds: readonly string[]): Promise<BatchOperationResult> {
    const ids = [...messageIds].filter(Boolean);
    const result = emptyResult(ids.length);
    setBusy("delete", true);
    try {
      for (const messageId of ids) {
        try {
          await sdk.deleteMessageForSelf(messageId);
          result.succeeded.push(messageId);
        } catch (error) {
          result.failed.push({ messageId, reason: errorText(error) });
        }
      }
      return result;
    } finally {
      setBusy("delete", false);
    }
  }

  async function setMessagesPinned(
    messageIds: readonly string[],
    pinned: boolean,
    scope: MessagePinScope = "conversation",
  ): Promise<BatchOperationResult> {
    const ids = [...messageIds].filter(Boolean);
    const result = emptyResult(ids.length);
    setBusy(pinned ? "pin" : "unpin", true);
    try {
      for (const messageId of ids) {
        try {
          await sdk.setMessagePinned(messageId, pinned, { scope });
          result.succeeded.push(messageId);
        } catch (error) {
          result.failed.push({ messageId, reason: errorText(error) });
        }
      }
      await sdk.refreshActiveChat();
      return result;
    } finally {
      setBusy(pinned ? "pin" : "unpin", false);
    }
  }

  return {
    busyKeys,
    isBusy,
    sendComposerPayload,
    toggleReaction,
    forwardMessages,
    deleteMessagesForSelf,
    setMessagesPinned,
    dispose,
  };
}
