import { FlareCoreSdk } from "@flare-im/sdk/tauri";
import { convertFileSrc } from "@tauri-apps/api/core";
import type { ReferenceRuntime } from "../../../shared/vue-reference/runtime";
import { notifyDesktop, setDesktopUnreadCount } from "../desktopNotifications";
import {
  configureAppMediaLocalPathResolver,
  configureAppTransportSelector,
  configureDesktopNotifications,
} from "../../../shared/vue-reference/workbench/app";
import { createTauriPlatformAdapter } from "./platformAdapter";

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
  configureDesktopNotifications({ notify: notifyDesktop, setUnreadCount: setDesktopUnreadCount });
  configureAppTransportSelector({
    enabled: true,
    runtimeStatus: "tauri-native",
    tlsCaCertPath: __FLARE_DEV_CA_CERT_PATH__,
  });
}
