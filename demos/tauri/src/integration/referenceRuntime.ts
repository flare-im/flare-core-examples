import { FlareCoreSdk } from "@flare-im/sdk/tauri";
import { convertFileSrc } from "@tauri-apps/api/core";
import { openUrl, revealItemInDir } from "@tauri-apps/plugin-opener";
import type { ReferenceRuntime } from "@reference/runtime";
import {
  configureAppMediaLocalPathResolver,
  configureDownloadDirectoryPicker,
  configureNativeMediaActions,
} from "@reference/workbench/app";
import { createTauriPlatformAdapter, pickDirectory } from "./platformAdapter";

export const referenceRuntime: ReferenceRuntime = {
  id: "tauri",
  label: "Tauri native",
  runtimeStatus: "tauri-native",
  createClient: () => FlareCoreSdk.createClient(),
  sdkConfig: () => {
    const tlsCaCertPath = String(import.meta.env.VITE_FLARE_TLS_CA_CERT_PATH ?? "").trim();
    return tlsCaCertPath ? { tlsCaCertPath } : {};
  },
  openUrl: (url) => openUrl(url),
  platform: {
    kind: "tauri",
    adapter: createTauriPlatformAdapter(),
    capabilities: { pointer: "fine", hover: true, contextMenu: true, keyboardShortcut: true, safeArea: false },
  },
};

export function configureNativeReferenceBridges(): void {
  configureAppMediaLocalPathResolver(convertFileSrc);
  configureDownloadDirectoryPicker(pickDirectory);
  configureNativeMediaActions({
    revealDownloadedFile: async (path) => {
      await revealItemInDir(path);
      return true;
    },
  });
}
