import {
  WebFlareImClient,
  WebProductionBridge,
  wrapWebHostBridge,
  type FlareWasmRuntime,
} from "@flare-im/sdk/web";
import { webAppInfoFromBuild } from "@flare-im/sdk/lifecycle";
import { createWebUpdateInstaller, registerFlareServiceWorker } from "@flare-im/sdk/update";
import type { ReferenceRuntime } from "../../../../../flare-core-sdk/examples/shared/vue-reference/runtime";
import { createWebPlatformAdapter } from "@flare-im/vue-ui/composables";

type WasmModule = {
  default?: (options?: { module_or_path?: string | URL | Request }) => Promise<unknown> | unknown;
  createWasmRuntime: () => FlareWasmRuntime;
};

const buildId = String(import.meta.env.VITE_FLARE_WASM_BUILD_ID ?? "").trim();
/** The web build this page runs; the dev server has none, and so no Service Worker. */
const webBuildId = webAppInfoFromBuild().buildId;

function assetUrl(fileName: string): string {
  const base = import.meta.env.BASE_URL.endsWith("/") ? import.meta.env.BASE_URL : `${import.meta.env.BASE_URL}/`;
  const value = `${base}flare-core-wasm/${fileName}`;
  return buildId ? `${value}?v=${encodeURIComponent(buildId)}` : value;
}

async function loadRuntime(): Promise<{ runtime: FlareWasmRuntime }> {
  const moduleUrl = assetUrl("flare_im_core_sdk.js");
  const module = await import(/* @vite-ignore */ moduleUrl) as WasmModule;
  await module.default?.({ module_or_path: assetUrl("flare_im_core_sdk_bg.wasm") });
  if (typeof module.createWasmRuntime !== "function") {
    throw new Error("WASM runtime does not export createWasmRuntime()");
  }
  return { runtime: module.createWasmRuntime() };
}

export const referenceRuntime: ReferenceRuntime = {
  id: "web",
  label: "Web/WASM",
  runtimeStatus: "browser-wasm",
  // Browser host: pointer / hover detected by the kit, pickers through the DOM file input.
  platform: { kind: "web", adapter: createWebPlatformAdapter() },
  // Where to connect is the build's VITE_FLARE_ACCESS_JSON (see the shared runtime/access.ts); the bridge adds the
  // build-time app version and build, and the SDK installs the browser's network and visibility lifecycle at init.
  createClient: () => new WebFlareImClient(wrapWebHostBridge(new WebProductionBridge({ loadRuntime }))),
  createUpdateInstaller: (client, isInputEmpty) => createWebUpdateInstaller({
    buildId: webBuildId ?? "",
    scriptUrl: `${import.meta.env.BASE_URL}sw.js`,
    scope: import.meta.env.BASE_URL,
    session: {
      setAppState: (request) => client.lifecycle.setAppState(request),
      disconnect: () => client.connection.disconnect(),
    },
    isInputEmpty,
    onError: (error) => console.warn("[update]", error),
  }),
  openUrl: (url) => {
    window.open(url, "_blank", "noopener");
  },
};

/** Registers this build's Service Worker. It waits for the first screen itself; only the update flow moves it on. */
export function registerWebBundleWorker(): void {
  if (!webBuildId) return;
  const base = import.meta.env.BASE_URL;
  void registerFlareServiceWorker({
    buildId: webBuildId,
    scriptUrl: `${base}sw.js`,
    scope: base,
    assetManifestUrl: `${base}asset-manifest.json`,
    onError: (error) => console.warn("[update] registering the service worker failed", error),
  });
}
