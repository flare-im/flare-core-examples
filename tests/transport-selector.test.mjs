import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const appRoot = join(import.meta.dirname, "..");
const clientSdkRoot = join(appRoot, "../..");
const monorepoRoot = join(clientSdkRoot, "..");

const readFromApp = (path) => readFileSync(join(appRoot, path), "utf8");
const readFromMonorepo = (path) => readFileSync(join(monorepoRoot, path), "utf8");

test("tauri reference runtime keeps native transport and file picking in the platform adapter", () => {
  const runtime = readFromApp("src/integration/referenceRuntime.ts");
  const adapter = readFromApp("src/integration/platformAdapter.ts");
  const main = readFromApp("src/main.ts");

  assert.match(runtime, /FlareCoreSdk.*@flare-im\/sdk\/tauri/s);
  assert.match(runtime, /createClient:\s*\(\)\s*=>\s*FlareCoreSdk\.createClient\(\)/);
  // Native file picking lives in the kit's platform contract: the dialog plugin
  // is reached only through the Tauri adapter the runtime hands to the provider.
  assert.match(adapter, /@tauri-apps\/plugin-dialog/);
  assert.match(adapter, /export function createTauriPlatformAdapter/);
  assert.match(adapter, /"CANCELLED"/);
  assert.match(runtime, /platform:\s*\{[\s\S]*kind:\s*"tauri"[\s\S]*adapter:\s*createTauriPlatformAdapter\(\)/);
  assert.doesNotMatch(runtime, /@tauri-apps\/plugin-dialog|configureAppMediaPathPicker/);
  assert.match(runtime, /setDesktopUnreadCount/);
  assert.match(main, /configureReferenceApp\(referenceRuntime\)/);
  assert.match(main, /configureNativeReferenceBridges\(\)/);
  assert.match(runtime, /configureAppMediaLocalPathResolver\(convertFileSrc\)/);
  assert.doesNotMatch(main, /@flare-im\/vue-ui\/(?:src|app|internal|private)/);
});

test("tauri renderer vite config is ESM and carries the development CA path", () => {
  const packageJson = JSON.parse(readFromApp("package.json"));
  const viteConfig = readFromApp("vite.config.ts");

  assert.equal(packageJson.type, "module");
  assert.match(viteConfig, /@flare-im\/sdk\/devtools\/vite/);
  assert.match(viteConfig, /flare-im-core\/certs\/server\.crt/);
  assert.match(viteConfig, /defineFlareTauriConfig/);
  assert.equal(existsSync(join(appRoot, "src-tauri/certs/server.crt")), false);
});

test("tauri consumes the latest public Vue UI package", () => {
  const packageJson = JSON.parse(readFromApp("package.json"));
  const uiPackage = JSON.parse(readFromMonorepo("flare-im-design/packages/vue-im-ui/package.json"));
  const app = readFromApp("src/App.vue");

  assert.equal(packageJson.dependencies["@flare-im/vue-ui"], "file:../../../flare-im-design/packages/vue-im-ui");
  assert.equal(uiPackage.version, "2.0.0-rc.1");
  assert.match(app, /ReferenceApp/);
});

test("tauri native SDK enables the QUIC cargo feature chain", () => {
  const tauriCargo = readFromApp("src-tauri/Cargo.toml");
  const tauriBindingCargo = readFromMonorepo("flare-im-core-sdk/bindings/tauri/Cargo.toml");
  const sdkCargo = readFromMonorepo("flare-im-core-sdk/Cargo.toml");

  assert.match(tauriCargo, /flare-im-core-sdk-tauri\s*=\s*\{[^}]*features\s*=\s*\[[^\]]*"quic"/s);
  assert.match(tauriBindingCargo, /quic\s*=\s*\[[^\]]*"flare-im-core-sdk\/quic"/s);
  assert.match(sdkCargo, /quic\s*=\s*\[[^\]]*"flare-core\/quic"/s);
});

test("tauri shell exposes a tray icon with unread badge text", () => {
  const desktopNotifications = readFromApp("src/desktopNotifications.ts");
  const capabilities = JSON.parse(readFromApp("src-tauri/capabilities/default.json"));

  assert.match(desktopNotifications, /TrayIcon/);
  assert.match(desktopNotifications, /ensureTrayIcon/);
  assert.match(desktopNotifications, /tray\.setTitle/);
  assert.match(desktopNotifications, /getCurrentWindow\(\)\.setBadgeCount/);
  assert.ok(capabilities.permissions.includes("core:default"));
});
