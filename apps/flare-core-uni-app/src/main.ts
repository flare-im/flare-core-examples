import { createSSRApp } from "vue";
import { FlareCoreSdk } from "@flare-im/sdk/uni-app";
import App from "../App.vue";
import { router } from "./router";
import { configureReferenceApp } from "../../../shared/vue-reference/bootstrap";
import { createUniPlatformAdapter, installUniFlarePlatformAdapters } from "./platform/uniFlarePlatform";

export function createApp() {
  const uniPlatform = (globalThis as { uni?: { getSystemInfoSync?(): { uniPlatform?: string } } })
    .uni?.getSystemInfoSync?.().uniPlatform;
  configureReferenceApp({
    id: "uni",
    label: "uni-app",
    runtimeStatus: uniPlatform && uniPlatform !== "web" && uniPlatform !== "h5" ? "uni-native" : "browser-wasm",
    createClient: () => FlareCoreSdk.createClient(),
    platform: { kind: "web", adapter: createUniPlatformAdapter() },
  });
  installUniFlarePlatformAdapters();
  return { app: createSSRApp(App).use(router) };
}
