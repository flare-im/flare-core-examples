import path from "node:path";
import { fileURLToPath } from "node:url";

import vue from "@vitejs/plugin-vue";
import { defineConfig } from "vitest/config";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, "../../..");
const typeScriptSdkRoot = path.resolve(__dirname, "../../packages/flare-core-typescript-sdk/src");
const vueImUiRoot = path.resolve(__dirname, "../../../flare-im-design/packages/vue-im-ui/src");

export default defineConfig({
  plugins: [vue()],
  resolve: {
    dedupe: ["vue", "vue-router", "naive-ui", "@vicons/ionicons5", "markdown-it", "protobufjs"],
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
      {
        find: "@flare-im/vue-ui/composables",
        replacement: path.join(vueImUiRoot, "composables/index.ts"),
      },
      {
        find: "@flare-im/vue-ui/icon-glyphs",
        replacement: path.join(vueImUiRoot, "shared/icon-glyphs.ts"),
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
      // Shared reference-app tests (../shared/vue-reference) mount components; the
      // DOM test utils live in this app's node_modules, outside their lookup path.
      {
        find: "@vue/test-utils",
        replacement: path.join(__dirname, "node_modules/@vue/test-utils"),
      },
      // vitest resolves SSR-style (no `resolve.dedupe`): pin `vue` to this app's copy
      // so kit source, its @lucide/vue icons and the test utils share one runtime.
      {
        find: /^vue$/,
        replacement: path.join(__dirname, "node_modules/vue"),
      },
      // The kit's icons import @lucide/vue from the kit's node_modules; without this
      // alias vitest externalizes its CJS build, which requires the kit's own Vue copy.
      {
        find: /^@lucide\/vue$/,
        replacement: path.resolve(vueImUiRoot, "../../../node_modules/@lucide/vue/dist/esm/lucide-vue.mjs"),
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
    // The kit's icon runtime lives in flare-im-design/node_modules; inline it so
    // its `vue` import goes through the alias above instead of Node resolution.
    server: { deps: { inline: [/node_modules\/@lucide\/vue\//] } },
    include: [
      "src/**/*.test.ts",
      "../shared/vue-reference/**/*.test.ts",
      "../../packages/flare-core-typescript-sdk/src/**/*.test.ts",
    ],
  },
});
