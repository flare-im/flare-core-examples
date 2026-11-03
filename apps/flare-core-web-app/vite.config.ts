import path from "node:path";
import { existsSync } from "node:fs";
import { fileURLToPath } from "node:url";

import vue from "@vitejs/plugin-vue";
import { createFlareCoreWebAppViteConfig } from "@flare-im/sdk/devtools/vite";
import { defineConfig, loadEnv, type UserConfig } from "vite";
import type { OutputOptions } from "rollup";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const typeScriptSdkRoot = path.resolve(__dirname, "../../packages/flare-core-typescript-sdk/src");

export default createFlareCoreWebAppViteConfig({
  appDir: __dirname,
  serverPort: 1430,
  defineConfig: (factory) => defineConfig((context) => {
    const config = factory(context) as UserConfig;
    const configuredOutput = config.build?.rollupOptions?.output;
    const output = (Array.isArray(configuredOutput) ? configuredOutput[0] : configuredOutput) ?? {};
    const originalChunks = output.manualChunks;
    const themeOutput: OutputOptions = {
      ...output,
      manualChunks(id, api) {
        const normalized = id.replace(/\\/g, "/");
        if (normalized.includes("/naive-ui/") && /\/(styles|themes)\/dark(?:\.|\/)/.test(normalized)) return "naive-dark-theme";
        return typeof originalChunks === "function" ? originalChunks(id, api) : undefined;
      },
    };
    return {
      ...config,
      build: {
        ...config.build,
        rollupOptions: {
          ...config.build?.rollupOptions,
          output: themeOutput,
        },
      },
    };
  }),
  loadEnv,
  vuePlugin: vue,
  extraAliases: [
    ...(process.env.FLARE_USE_PUBLISHED_KIT !== "true" && existsSync(path.resolve(__dirname, "../../../flare-im-design/tokens/dist/tokens.js")) ? [
      { find: "@flare-im/tokens/tokens.css", replacement: path.resolve(__dirname, "../../../flare-im-design/tokens/dist/tokens.css") },
      { find: "@flare-im/tokens/theme", replacement: path.resolve(__dirname, "../../../flare-im-design/tokens/theme.js") },
      { find: "@flare-im/tokens", replacement: path.resolve(__dirname, "../../../flare-im-design/tokens/dist/tokens.js") },
    ] : []),
    {
      find: "@flare-im/sdk/transport",
      replacement: path.join(typeScriptSdkRoot, "adapters/_shared/transportProfile.ts"),
    },
  ],
});
