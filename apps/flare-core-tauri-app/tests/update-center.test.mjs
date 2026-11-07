import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const appRoot = join(import.meta.dirname, "..");
const sharedRoot = join(appRoot, "../../../flare-core-sdk/examples/shared/vue-reference");
const read = (path) => readFileSync(path, "utf8");

const conf = JSON.parse(read(join(appRoot, "src-tauri/tauri.conf.json")));
const capability = JSON.parse(read(join(appRoot, "src-tauri/capabilities/default.json")));
const rust = read(join(appRoot, "src-tauri/src/main.rs"));
const cargo = read(join(appRoot, "src-tauri/Cargo.toml"));

test("the updater key only exists at build time", () => {
  assert.equal(conf.plugins?.updater, undefined);
  assert.match(rust, /contains_key\("updater"\)/);
});

test("the app turns on no macOS private API", () => {
  assert.equal(conf.app?.macOSPrivateApi, undefined);
  assert.doesNotMatch(cargo, /macos-private-api/);
});

test("the system's deep links are recovery links, delivered to the running instance", () => {
  assert.deepEqual(conf.plugins?.["deep-link"]?.desktop?.schemes, ["flare-recover"]);
  assert.ok(rust.indexOf("tauri_plugin_single_instance::init") < rust.indexOf("tauri_plugin_deep_link::init"));
  assert.match(cargo, /tauri-plugin-single-instance = \{[^}]*"deep-link"/);
});

test("the window may use what the installer and the deep links call", () => {
  for (const permission of ["deep-link:default", "updater:default", "process:allow-restart"]) {
    assert.ok(capability.permissions.includes(permission), permission);
  }
});

test("a store build can open its store page", () => {
  const runtime = read(join(appRoot, "src/integration/referenceRuntime.ts"));
  const scoped = capability.permissions.find((permission) => permission.identifier === "opener:allow-open-url");
  assert.match(runtime, /^\s*openUrl,$/m);
  assert.deepEqual(scoped?.allow?.map((entry) => entry.url), ["macappstore://*", "ms-windows-store://*", "itms-apps://*"]);
});

test("a store build says so to the core and leaves the updater alone", () => {
  const runtime = read(join(appRoot, "src/integration/referenceRuntime.ts"));
  assert.match(runtime, /import\.meta\.env\.VITE_FLARE_DISTRIBUTION/);
  assert.match(runtime, /app: \{ build, channel, \.\.\.\(distribution \? \{ distribution \} : \{\}\) \}/);
  assert.match(runtime, /!isStoreDistribution\(distribution\)/);
});

test("the app only wires the update center", () => {
  const app = read(join(sharedRoot, "ReferenceApp.vue"));
  const login = read(join(sharedRoot, "workbench/app/components/FlareLoginScreen.vue"));
  const chat = read(join(sharedRoot, "workbench/app/components/FlareChatWorkspace.vue"));
  const layout = read(join(sharedRoot, "workbench/app/components/FlareWorkbenchLayout.vue"));
  const conversations = read(join(sharedRoot, "workbench/app/components/FlareConversationsPanel.vue"));
  assert.match(app, /update: updates\.update/);
  assert.match(login, /updates\.refresh\(\)/);
  assert.match(login, /sdk\.initBeforeSignIn\(\)/);
  assert.match(chat, /:read-only="updates\.readOnly\.value"/);
  assert.match(chat, /composer\.readOnlyUpdate/);
  assert.match(layout, /badge: updates\.badge\.value/);
  assert.match(layout, /class="more-action-dot"/);
  assert.match(conversations, /:more-dot="updates\.badge\.value"/);
  assert.match(chat, /id: 'more',.*dot: updates\.badge\.value/);
});
