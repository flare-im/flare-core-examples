import path from "node:path";
import { fileURLToPath } from "node:url";

import vue from "@vitejs/plugin-vue";
import { createFlareCoreWebAppViteConfig } from "@flare-im/sdk/devtools/vite";
import { defineConfig, loadEnv } from "vite";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const monorepoRoot = path.resolve(__dirname, "../../..");
const typeScriptSdkRoot = path.resolve(__dirname, "../../packages/flare-core-typescript-sdk/src");
const flareCoreDevCaCertPath = path.resolve(monorepoRoot, "flare-im-core/certs/server.crt");

function normalizedBuildId(id: string): string {
  return id.replace(/\\/g, "/");
}

function tauriManualChunks(id: string): string | undefined {
  const normalized = normalizedBuildId(id);
  if (normalized.includes("node_modules/vue/") || normalized.includes("node_modules/@vue/") || normalized.includes("node_modules/vue-router")) {
    return "vue-runtime";
  }
  if (normalized.includes("node_modules/@vicons")) {
    return "icon-runtime";
  }
  if (normalized.includes("@flare-im/sdk") || normalized.includes("flare-im-core-sdk/bindings")) {
    return "flare-sdk";
  }
  if (normalized.includes("@flare-im/vue-ui") || normalized.includes("node_modules")) {
    return "ui-runtime";
  }
  return undefined;
}

function defineFlareTauriConfig(configFactory: (context: { mode: string }) => Record<string, unknown>): unknown {
  return defineConfig((context) => {
    const baseConfig = configFactory(context) as Record<string, unknown> & {
      build?: Record<string, unknown> & {
        rollupOptions?: Record<string, unknown> & {
          output?: Record<string, unknown>;
        };
      };
      define?: Record<string, unknown>;
    };
    const rollupOptions = baseConfig.build?.rollupOptions ?? {};
    const rollupOutput = rollupOptions.output ?? {};
    return {
      ...baseConfig,
      base: "./",
      build: {
        ...(baseConfig.build ?? {}),
        chunkSizeWarningLimit: 1400,
        rollupOptions: {
          ...rollupOptions,
          output: {
            ...rollupOutput,
            manualChunks: tauriManualChunks,
          },
        },
      },
      define: {
        ...(baseConfig.define ?? {}),
        __FLARE_DEV_CA_CERT_PATH__: JSON.stringify(flareCoreDevCaCertPath),
      },
    };
  });
}

export default createFlareCoreWebAppViteConfig({
  appDir: __dirname,
  serverPort: 1432,
  defineConfig: defineFlareTauriConfig,
  loadEnv,
  vuePlugin: vue,
  extraAliases: [
    {
      find: "@flare-im/sdk/transport",
      replacement: path.join(typeScriptSdkRoot, "adapters/_shared/transportProfile.ts"),
    },
    {
      find: "@flare-im/sdk/tauri",
      replacement: path.join(typeScriptSdkRoot, "adapters/tauri/index.ts"),
    },
  ],
});
