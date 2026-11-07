import { FlareCoreSdk } from "@flare-im/sdk/tauri";
import { followRecoveryLinks, webAppInfoFromBuild } from "@flare-im/sdk/lifecycle";
import { createTauriUpdateInstaller, isStoreDistribution } from "@flare-im/sdk/update";
import { convertFileSrc } from "@tauri-apps/api/core";
import { getCurrent, onOpenUrl } from "@tauri-apps/plugin-deep-link";
import { openUrl, revealItemInDir } from "@tauri-apps/plugin-opener";
import { relaunch } from "@tauri-apps/plugin-process";
import { check } from "@tauri-apps/plugin-updater";
import type { ReferenceRuntime } from "../../../../../flare-core-sdk/examples/shared/vue-reference/runtime";
import { notifyDesktop, setDesktopUnreadCount } from "../desktopNotifications";
import {
  configureAppMediaLocalPathResolver,
  configureDesktopNotifications,
  configureDownloadDirectoryPicker,
  configureNativeMediaActions,
} from "../../../../../flare-core-sdk/examples/shared/vue-reference/workbench/app";
import { createTauriPlatformAdapter, pickDirectory } from "./platformAdapter";

declare const __FLARE_DEV_CA_CERT_PATH__: string;

/**
 * The private CA the native runtime trusts for TLS endpoints (a local gateway's self-signed QUIC, say):
 * `VITE_FLARE_TLS_CA_CERT_PATH`, else on the dev server the repository's development certificate. Where to
 * connect is not here: that is the build's VITE_FLARE_ACCESS_JSON (see the shared runtime/access.ts).
 */
function tlsCaCertPath(): string | undefined {
  const configured = String(import.meta.env.VITE_FLARE_TLS_CA_CERT_PATH ?? "").trim();
  if (configured) return configured;
  return import.meta.env.DEV ? __FLARE_DEV_CA_CERT_PATH__ : undefined;
}

/** The distribution of a store build; the Tauri binding reports `tauri` without one. */
const distribution = String(import.meta.env.VITE_FLARE_DISTRIBUTION ?? "").trim();

/**
 * Whether this build has an updater; a store build never does. Without one the installer answers `update.noArtifact`,
 * and the prompt offers the website.
 */
const updaterConfigured = import.meta.env.VITE_FLARE_UPDATER_ENABLED === "1" && !isStoreDistribution(distribution);

export const referenceRuntime: ReferenceRuntime = {
  id: "tauri",
  label: "Tauri native",
  runtimeStatus: "tauri-native",
  // The Tauri binding adds the app version and desktop target, and the distribution a build does not name; the SDK
  // installs the webview's network and visibility lifecycle at init.
  createClient: () => FlareCoreSdk.createClient(),
  sdkConfig: () => {
    const path = tlsCaCertPath();
    const { build, channel } = webAppInfoFromBuild();
    return { ...(path ? { tlsCaCertPath: path } : {}), app: { build, channel, ...(distribution ? { distribution } : {}) } };
  },
  createUpdateInstaller: () => createTauriUpdateInstaller({
    check: updaterConfigured ? () => check() : async () => null,
    relaunch,
    openUrl,
    onError: (error) => console.warn("[update]", error),
  }),
  openUrl: (url) => openUrl(url),
  followRecoveryLinks: (onLink) => followRecoveryLinks({ getCurrent, onOpenUrl }, onLink),
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
}
