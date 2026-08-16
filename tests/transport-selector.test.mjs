import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const appRoot = join(import.meta.dirname, "..");
const clientSdkRoot = join(appRoot, "../..");
const monorepoRoot = join(clientSdkRoot, "..");

function readFromApp(path) {
  return readFileSync(join(appRoot, path), "utf8");
}

function readFromClientSdk(path) {
  return readFileSync(join(clientSdkRoot, path), "utf8");
}

function readFromMonorepo(path) {
  return readFileSync(join(monorepoRoot, path), "utf8");
}

test("tauri enables native transport protocol selection while web and electron stay websocket-only", () => {
  const tauriMain = readFromApp("src/main.ts");
  const electronMain = readFromClientSdk("examples/flare-core-electron-app/src/main.ts");
  const uniMain = readFromClientSdk("examples/flare-core-uni-app/src/main.ts");
  const webMain = readFromClientSdk("examples/flare-core-web-app/src/main.ts");
  const retiredTauriPackage = ["flare-core", "tauri-sdk"].join("-");

  assert.match(tauriMain, /configureAppTransportSelector/);
  assert.match(tauriMain, /@flare-im\/sdk\/tauri/);
  assert.doesNotMatch(tauriMain, new RegExp(retiredTauriPackage));
  assert.equal(existsSync(join(clientSdkRoot, "packages", retiredTauriPackage)), false);
  assert.match(tauriMain, /configureAppTransportSelector\(\{\s*enabled:\s*true,/s);
  assert.match(tauriMain, /runtimeStatus:\s*"tauri-native"/);
  assert.match(tauriMain, /tlsCaCertPath:/);
  assert.doesNotMatch(electronMain, /configureAppTransportSelector/);
  assert.match(electronMain, /WebSocket\); WASM has no QUIC/);
  assert.match(uniMain, /isUniNativeTransportRuntime/);
  assert.match(uniMain, /UNI_PLATFORM/);
  assert.match(uniMain, /runtimeStatus:\s*"uni-native"/);
  assert.doesNotMatch(webMain, /configureAppTransportSelector/);
});

test("tauri renderer vite config is loaded as ESM for SDK devtools imports", () => {
  const packageJson = JSON.parse(readFromApp("package.json"));
  const viteConfig = readFromApp("vite.config.ts");

  assert.equal(packageJson.type, "module");
  assert.match(viteConfig, /@flare-im\/sdk\/devtools\/vite/);
});

test("tauri passes the flare-im-core server certificate path into native TLS config", () => {
  const tauriMain = readFromApp("src/main.ts");
  const viteConfig = readFromApp("vite.config.ts");

  assert.match(viteConfig, /flare-im-core\/certs\/server\.crt/);
  assert.match(viteConfig, /defineFlareTauriConfig/);
  assert.match(viteConfig, /define:\s*\{/);
  assert.match(viteConfig, /__FLARE_DEV_CA_CERT_PATH__/);
  assert.match(tauriMain, /VITE_FLARE_TLS_CA_CERT_PATH/);
  assert.match(tauriMain, /typeof __FLARE_DEV_CA_CERT_PATH__ === "string"/);
  assert.match(tauriMain, /__FLARE_DEV_CA_CERT_PATH__/);
  assert.doesNotMatch(tauriMain, /src-tauri\/certs\/server\.crt/);
  assert.equal(existsSync(join(appRoot, "src-tauri/certs/server.crt")), false);
});

test("shared login UI only renders QUIC and racing choices when the host enables native transport selection", () => {
  const appIndex = readFromMonorepo("flare-im-design/vue-im-ui/src/app/index.ts");
  const loginView = readFromMonorepo("flare-im-design/vue-im-ui/src/app/components/FlareLoginScreen.vue");
  const authScreen = readFromMonorepo("flare-im-design/vue-im-ui/src/components/shell/FlareAuthScreen.vue");

  assert.match(appIndex, /configureAppTransportSelector/);
  assert.match(appIndex, /isAppTransportSelectorEnabled/);
  assert.match(loginView, /show-transport-selector/);
  assert.match(loginView, /isAppTransportSelectorEnabled\(\)/);
  assert.match(authScreen, /showTransportSelector/);
  assert.match(authScreen, /v-if="showTransportSelector"/);
});

test("tauri native SDK enables the QUIC cargo feature chain", () => {
  const tauriCargo = readFromApp("src-tauri/Cargo.toml");
  const tauriBindingCargo = readFromMonorepo("flare-im-core-sdk/bindings/tauri/Cargo.toml");
  const sdkCargo = readFromMonorepo("flare-im-core-sdk/Cargo.toml");

  assert.match(tauriCargo, /flare-im-core-sdk-tauri\s*=\s*\{[^}]*features\s*=\s*\[[^\]]*"quic"/s);
  assert.match(tauriBindingCargo, /quic\s*=\s*\[[^\]]*"flare-im-core-sdk\/quic"/s);
  assert.match(sdkCargo, /quic\s*=\s*\[[^\]]*"flare-core\/quic"/s);
});

test("tauri shell exposes a status bar tray icon with unread badge text", () => {
  const desktopNotifications = readFromApp("src/desktopNotifications.ts");
  const capabilities = JSON.parse(readFromApp("src-tauri/capabilities/default.json"));

  assert.match(desktopNotifications, /TrayIcon/);
  assert.match(desktopNotifications, /defaultWindowIcon/);
  assert.match(desktopNotifications, /ensureTrayIcon/);
  assert.match(desktopNotifications, /tray\.setTitle/);
  assert.match(desktopNotifications, /tray\.setTooltip/);
  assert.match(desktopNotifications, /getCurrentWindow\(\)\.setBadgeCount/);
  assert.match(desktopNotifications, /badgeLabel\(count\)/);
  assert.ok(capabilities.permissions.includes("core:default"));
});
