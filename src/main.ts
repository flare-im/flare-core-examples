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
import { applyFlareTheme } from "@flare-im/vue-ui/theme";

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


// 显式声明主题，且必须在挂载前调用。
//
// kit 的 token 带一层 `@media (prefers-color-scheme: dark)` 兜底：没有人显式
// 定下主题时，它跟着**系统**走。这个 app 的样式几乎全部来自 kit，本身没有
// 对应的深色版式，于是在深色系统下会进入半暗态——文字 token 变白、背景仍浅，
// 会话列表标题一类的文字直接白字白底看不见（tauri app 上已实测复现）。
//
// applyFlareTheme 会注入 token 并同时写 data-theme 与 data-flare-theme，
// 两个属性缺一不可：只设其一会让 --flare-color-* 停在另一套里，仍是半暗态。
//
// 等这个 app 补齐深色版式后，换成 useFlareThemeProvider 跟随用户选择即可；
// 在那之前，声明一个真正实现了的主题，比跟随一个没实现的更诚实。
applyFlareTheme(false, "default");

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
