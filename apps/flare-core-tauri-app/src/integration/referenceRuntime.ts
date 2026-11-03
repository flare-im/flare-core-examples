import { FlareCoreSdk } from "@flare-im/sdk/tauri";
import { convertFileSrc } from "@tauri-apps/api/core";
import { revealItemInDir } from "@tauri-apps/plugin-opener";
import type { ReferenceRuntime } from "../../../../../flare-core-sdk/examples/shared/vue-reference/runtime";
import { notifyDesktop, setDesktopUnreadCount } from "../desktopNotifications";
import {
  configureAppMediaLocalPathResolver,
  configureAppTransportSelector,
  configureDesktopNotifications,
  configureDownloadDirectoryPicker,
  configureNativeMediaActions,
} from "../../../../../flare-core-sdk/examples/shared/vue-reference/workbench/app";
import { createTauriPlatformAdapter, pickDirectory } from "./platformAdapter";

declare const __FLARE_DEV_CA_CERT_PATH__: string;

export const referenceRuntime: ReferenceRuntime = {
  id: "tauri",
  label: "Tauri native",
  createClient: () => FlareCoreSdk.createClient(),
  // Desktop host: fine pointer, hover, context menus and shortcuts; the dialog
  // plugin backs the pickers, nothing backs share.
  platform: {
    kind: "tauri",
    adapter: createTauriPlatformAdapter(),
    capabilities: { pointer: "fine", hover: true, contextMenu: true, keyboardShortcut: true, safeArea: false },
  },
};

export function configureNativeReferenceBridges(): void {
  configureAppMediaLocalPathResolver(convertFileSrc);
  // 「下载位置」用系统的选文件夹对话框；保存好的文件能在访达 / 资源管理器里显示。
  configureDownloadDirectoryPicker(pickDirectory);
  configureNativeMediaActions({
    revealDownloadedFile: async (path) => {
      await revealItemInDir(path);
      return true;
    },
  });
  configureDesktopNotifications({ notify: notifyDesktop, setUnreadCount: setDesktopUnreadCount });
  configureAppTransportSelector({
    enabled: true,
    runtimeStatus: "tauri-native",
    tlsCaCertPath: __FLARE_DEV_CA_CERT_PATH__,
  });
}
