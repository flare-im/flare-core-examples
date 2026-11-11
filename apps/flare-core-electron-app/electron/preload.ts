import { contextBridge, ipcRenderer } from "electron";

type FlareDesktopInfo = {
  name: string;
  version: string;
  platform: NodeJS.Platform;
  arch: string;
  isPackaged: boolean;
};

type FlareDesktopNotificationPayload = {
  kind: "message" | "call";
  title: string;
  body: string;
  conversationId?: string;
  messageId?: string;
  senderId?: string;
  unreadCount?: number;
  requireAttention?: boolean;
  playSound?: boolean;
  dedupeKey?: string;
};

contextBridge.exposeInMainWorld("flareNativeMediaActions", {
  revealDownloadedFile(filePath: string): Promise<boolean> {
    return ipcRenderer.invoke("flare:reveal-downloaded-file", filePath);
  },
});

contextBridge.exposeInMainWorld("flareDesktop", {
  runtime: "electron",
  platform: process.platform,
  versions: {
    electron: process.versions.electron,
    chrome: process.versions.chrome,
  },
  getAppInfo(): Promise<FlareDesktopInfo> {
    return ipcRenderer.invoke("flare:app-info");
  },
  notify(payload: FlareDesktopNotificationPayload): Promise<boolean> {
    return ipcRenderer.invoke("flare:desktop-notify", payload);
  },
  setUnreadCount(count: number): Promise<boolean> {
    return ipcRenderer.invoke("flare:set-unread-count", count);
  },
});
