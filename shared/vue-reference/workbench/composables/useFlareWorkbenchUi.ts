import { inject, provide, type InjectionKey, type Ref } from "vue";

export type FlareWorkbenchUiContext = {
  messageLocation?: Ref<{ conversationId: string; messageId: string } | null>;
  openMore: () => void;
  openStartChat: () => void;
  openSdkBuild: () => void;
  openChatSearch: () => void;
  openPreview: (messageId: string) => void;
};

const workbenchUiKey: InjectionKey<FlareWorkbenchUiContext> = Symbol("flare-workbench-ui");

export function provideFlareWorkbenchUi(context: FlareWorkbenchUiContext): void {
  provide(workbenchUiKey, context);
}

export function useFlareWorkbenchUi(): FlareWorkbenchUiContext {
  const ctx = inject(workbenchUiKey);
  if (!ctx) {
    throw new Error("useFlareWorkbenchUi() requires provideFlareWorkbenchUi() in a parent layout.");
  }
  return ctx;
}

export type FlareWorkbenchModalRefs = {
  moreOpen: Ref<boolean>;
  startChatOpen: Ref<boolean>;
  sdkBuildOpen: Ref<boolean>;
  chatSearchOpen: Ref<boolean>;
  previewOpen: Ref<boolean>;
  previewMessageId: Ref<string>;
};
