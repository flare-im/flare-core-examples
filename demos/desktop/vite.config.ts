import path from "node:path";
import { fileURLToPath } from "node:url";
import vue from "@vitejs/plugin-vue";
import { createFlareCoreWebAppViteConfig } from "@flare-im/sdk/devtools/vite";
import { defineConfig, loadEnv } from "vite";
import { readFileSync } from "node:fs";

const appDir = path.dirname(fileURLToPath(import.meta.url));
const { demoPlatform } = JSON.parse(readFileSync(path.join(appDir, "package.json"), "utf8"));
const workspaceRoot = path.join(appDir, ".flare/sources");
const tokens = path.join(workspaceRoot, "flare-im-design/tokens");

export default createFlareCoreWebAppViteConfig({
  appDir,
  workspaceRoot,
  wasmBindingRoot: demoPlatform === "tauri" ? null : path.join(appDir, ".flare/artifacts/wasm"),
  appDistribution: demoPlatform,
  serverPort: { electron: 1433, tauri: 1432, web: 1430 }[demoPlatform as "electron" | "tauri" | "web"],
  defineConfig,
  loadEnv,
  vuePlugin: vue,
  extraAliases: [
    { find: "@reference", replacement: path.join(appDir, "reference") },
    { find: "@", replacement: path.join(appDir, "src") },
    { find: "@flare-im/tokens/tokens.css", replacement: path.join(tokens, "dist/tokens.css") },
    { find: "@flare-im/tokens/theme", replacement: path.join(tokens, "theme.js") },
    { find: /^@flare-im\/tokens$/, replacement: path.join(tokens, "dist/tokens.js") },
  ],
});
