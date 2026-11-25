import {
  WebFlareImClient,
  WebProductionBridge,
  wrapWebHostBridge,
  type FlareWasmRuntime,
} from "@flare-im/sdk/web";
import { createWebPlatformAdapter } from "@flare-im/vue-ui/composables";
import type { ReferenceRuntime } from "@reference/runtime";

type WasmModule = {
  default(options: { module_or_path: string }): Promise<unknown>;
  createWasmRuntime(): FlareWasmRuntime;
};

function assetUrl(name: string): string {
  const path = `${import.meta.env.BASE_URL}flare-core-wasm/${name}`;
  const buildId = import.meta.env.VITE_FLARE_WASM_BUILD_ID;
  return buildId ? `${path}?v=${encodeURIComponent(buildId)}` : path;
}

async function loadRuntime() {
  const moduleUrl = assetUrl("flare_im_core_sdk.js");
  const binding: WasmModule = await import(/* @vite-ignore */ moduleUrl);
  await binding.default({ module_or_path: assetUrl("flare_im_core_sdk_bg.wasm") });
  return { runtime: binding.createWasmRuntime() };
}

export const referenceRuntime: ReferenceRuntime = {
  id: "web",
  label: "Web/WASM",
  runtimeStatus: "browser-wasm",
  platform: { kind: "web", adapter: createWebPlatformAdapter() },
  createClient: () => new WebFlareImClient(wrapWebHostBridge(new WebProductionBridge({ loadRuntime }))),
  openUrl: (url) => { window.open(url, "_blank", "noopener"); },
};
