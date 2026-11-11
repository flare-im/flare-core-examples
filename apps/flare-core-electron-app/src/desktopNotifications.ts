import {
  configureDesktopNotifications,
  playDesktopNotificationSound,
  type DesktopNotificationPayload,
} from "../../../shared/vue-reference/workbench/app";

type ElectronDesktopBridge = {
  notify(payload: DesktopNotificationPayload): Promise<boolean>;
  setUnreadCount(count: number): Promise<boolean>;
};

declare global {
  interface Window {
    flareDesktop?: {
      runtime?: string;
      notify?: ElectronDesktopBridge["notify"];
      setUnreadCount?: ElectronDesktopBridge["setUnreadCount"];
    };
  }
}

export function configureElectronDesktopNotifications(): void {
  const bridge = window.flareDesktop;
  if (bridge?.runtime !== "electron" || !bridge.notify) return;
  configureDesktopNotifications({
    async notify(payload) {
      if (payload.playSound !== false) {
        await playDesktopNotificationSound(payload.kind);
      }
      await bridge.notify?.(payload);
    },
    async setUnreadCount(count) {
      await bridge.setUnreadCount?.(count);
    },
  });
}
