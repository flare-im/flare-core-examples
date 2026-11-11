import type { useFlareCoreClient } from "./composables/useFlareCoreClient";

type Workbench = ReturnType<typeof useFlareCoreClient>;

type RequiredWorkbenchCapability =
  | "initializeAndLogin"
  | "resumeSavedSession"
  | "hasSavedSession"
  | "syncHomeBeforeEnter"
  | "logout"
  | "selectConversation"
  | "setConversationFilter"
  | "sendText"
  | "sendTypedMessage"
  | "buildAndSendMessage"
  | "buildFromComposerAction"
  | "resendFailedMessage"
  | "forwardMessagesToConversation"
  | "sendEmoji"
  | "sendSticker"
  | "addReaction"
  | "removeReaction"
  | "toggleReaction"
  | "editMessageText"
  | "setMessagePinned"
  | "deleteMessageForSelf"
  | "recallMessageById"
  | "saveActiveDraft"
  | "clearConversationDraft"
  | "sendTyping"
  | "searchActiveMessages"
  | "runDispatch"
  | "syncActiveConversation"
  | "syncConversationsFromServer"
  | "loadOlderMessages"
  | "searchConversationsWithKeyword"
  | "deleteActiveConversation"
  | "runSessionDiagnostics"
  | "openPeerConversation"
  | "runConversationOperation"
  | "runSyncOperation"
  | "runPresenceOperation"
  | "runMediaOperation"
  | "runCapabilityOperation"
  | "runConnectionOperation"
  | "runSessionOperation"
  | "runEventOperation";

type MissingCapability = Exclude<RequiredWorkbenchCapability, keyof Workbench>;

export const fullWorkbenchCapabilityContract: MissingCapability extends never ? true : never = true;
