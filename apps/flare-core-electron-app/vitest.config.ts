import path from "node:path";
import { fileURLToPath } from "node:url";

import vue from "@vitejs/plugin-vue";
import { defineConfig } from "vitest/config";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "../../..");
const typeScriptSdkRoot = path.resolve(__dirname, "../../../flare-core-sdk/packages/flare-core-typescript-sdk/src");
const vueImUiRoot = path.resolve(__dirname, "../../../flare-im-design/packages/vue-im-ui/src");

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: [
      {
        find: "@flare-im/sdk/web",
        replacement: path.join(typeScriptSdkRoot, "adapters/web/index.ts"),
      },
      {
        find: /^@flare-im\/sdk\/(.+)$/,
        replacement: path.join(typeScriptSdkRoot, "$1"),
      },
      {
        find: "@flare-im/vue-ui/style.css",
        replacement: path.join(vueImUiRoot, "design-system/styles/index.css"),
      },
      {
        find: "@flare-im/vue-ui/theme",
        replacement: path.join(vueImUiRoot, "design-system/theme/index.ts"),
      },
      {
        find: "@flare-im/vue-ui/i18n",
        replacement: path.join(vueImUiRoot, "shared/i18n/index.ts"),
      },
      {
        find: "@flare-im/vue-ui/components",
        replacement: path.join(vueImUiRoot, "components/index.ts"),
      },
      {
        find: "@flare-im/vue-ui/utils",
        replacement: path.join(vueImUiRoot, "utils/index.ts"),
      },
      // 更具体的子路径要排在 `/composables` 前面（字符串 find 是前缀匹配）。
      {
        find: "@flare-im/vue-ui/composables/sdk",
        replacement: path.join(vueImUiRoot, "composables/sdk.ts"),
      },
      {
        find: "@flare-im/vue-ui/composables",
        replacement: path.join(vueImUiRoot, "composables/index.ts"),
      },
      {
        find: "@flare-im/vue-ui/contracts",
        replacement: path.join(vueImUiRoot, "shared/contracts/index.ts"),
      },
      {
        find: "@flare-im/vue-ui",
        replacement: path.join(vueImUiRoot, "index.ts"),
      },
      {
        find: "@flare-im/sdk",
        replacement: path.join(typeScriptSdkRoot, "index.ts"),
      },
    ],
  },
  server: {
    fs: {
      allow: [repoRoot],
    },
  },
  test: {
    environment: "node",
    include: ["../../../flare-core-sdk/packages/flare-core-typescript-sdk/src/**/*.test.ts"],
  },
});
