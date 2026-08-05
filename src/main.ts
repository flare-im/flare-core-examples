import { createApp } from "vue";
import { FlareCoreSdk } from "@flare-im/sdk/tauri";
import App from "./App.vue";
import { router } from "./router";
import {
  sdkMediaProxyFields,
  configureProductionAppClientFactory,
  configureAppTransportSelector,
  configureAppMediaLocalPathResolver,
  configureAppMediaPathPicker,
} from "@flare-im/vue-ui/app";
import { configureMediaProxy } from "@flare-im/vue-ui/utils";
import { convertFileSrc } from "@tauri-apps/api/core";
import { open } from "@tauri-apps/plugin-dialog";
import { revealItemInDir } from "@tauri-apps/plugin-opener";
import { configureTauriDesktopNotifications } from "./desktopNotifications";
import "@flare-im/vue-ui/app/style.css";

declare const __FLARE_DEV_CA_CERT_PATH__: string;

const defaultTlsCaCertPath = typeof __FLARE_DEV_CA_CERT_PATH__ === "string"
  ? __FLARE_DEV_CA_CERT_PATH__
  : "";

configureMediaProxy(sdkMediaProxyFields());
configureAppTransportSelector({
  enabled: true,
  runtimeStatus: "tauri-native",
  tlsCaCertPath: import.meta.env.VITE_FLARE_TLS_CA_CERT_PATH || defaultTlsCaCertPath,
});
configureTauriDesktopNotifications();
configureAppMediaLocalPathResolver((path) => convertFileSrc(path));
configureAppMediaPathPicker(async ({ kind, multiple }) => {
  const selected = await open({
    multiple,
    filters: mediaFilters(kind),
    pickerMode: kind === "image" || kind === "imageGroup" ? "image" : kind === "video" ? "video" : "document",
    fileAccessMode: "scoped",
  });
  if (!selected) return [];
  return Array.isArray(selected) ? selected : [selected];
});
window.flareNativeMediaActions = {
  async revealDownloadedFile(path: string): Promise<boolean> {
    await revealItemInDir(path);
    return true;
  },
};
configureProductionAppClientFactory(() => FlareCoreSdk.createClient());

const app = createApp(App);
app.use(router);
app.mount("#app");

function mediaFilters(kind: string): { name: string; extensions: string[] }[] {
  if (kind === "image" || kind === "imageGroup") {
    return [{ name: "Images", extensions: ["png", "jpg", "jpeg", "gif", "webp", "heic", "heif"] }];
  }
  if (kind === "video") {
    return [{ name: "Videos", extensions: ["mp4", "mov", "m4v", "webm", "mkv"] }];
  }
  if (kind === "audio") {
    return [{ name: "Audio", extensions: ["mp3", "m4a", "aac", "wav", "ogg", "webm"] }];
  }
  return [];
}
