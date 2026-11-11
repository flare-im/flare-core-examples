import { WebFlareImClient, WebProductionBridge, wrapWebHostBridge, type FlareWasmRuntime } from "@flare-im/sdk/web";
import { createWebPlatformAdapter } from "@flare-im/vue-ui/composables";
import type { ReferenceRuntime } from "../../../../shared/vue-reference/runtime";
import { createSqliteOpfsStorageHost } from "../storage/sqliteOpfsStorageHost";

type WasmModule = {
  default?: (options?: { module_or_path?: string | URL | Request }) => Promise<unknown> | unknown;
  createWasmRuntime: () => FlareWasmRuntime;
};

const buildId = String(import.meta.env.VITE_FLARE_WASM_BUILD_ID ?? "").trim();

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
  id: "electron",
  label: "Electron/WASM",
  runtimeStatus: "browser-wasm",
  platform: { kind: "web", adapter: createWebPlatformAdapter() },
  createClient: () => {
    const desktop = window.flareDesktop?.runtime === "electron";
    return new WebFlareImClient(wrapWebHostBridge(new WebProductionBridge({
      loadRuntime,
      ...(desktop ? { createStorageHost: createSqliteOpfsStorageHost } : {}),
    })));
  },
  openUrl: (url) => { window.open(url, "_blank", "noopener"); },
};
