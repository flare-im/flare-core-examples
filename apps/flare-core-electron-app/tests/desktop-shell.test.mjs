import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const appRoot = join(import.meta.dirname, "..");

function readFromApp(path) {
  return readFileSync(join(appRoot, path), "utf8");
}

test("electron shell exposes a menu bar tray icon with unread badge text", () => {
  const main = readFromApp("electron/main.ts");
  const packageJson = JSON.parse(readFromApp("package.json"));

  assert.match(main, /Tray/);
  assert.match(main, /nativeImage/);
  assert.match(main, /function createTray\(\)/);
  assert.match(main, /tray\.setContextMenu/);
  assert.match(main, /tray\.on\("click", showMainWindow\)/);
  assert.match(main, /app\.setBadgeCount\(count\)/);
  assert.match(main, /currentTray\.setTitle\(label\)/);
  assert.match(main, /currentTray\.setToolTip/);
  assert.ok(packageJson.build.files.includes("assets/icons/**"));
});

test("electron renderer keeps unread count flowing through the desktop bridge", () => {
  const preload = readFromApp("electron/preload.ts");
  const rendererBridge = readFromApp("src/desktopNotifications.ts");

  assert.match(preload, /flare:set-unread-count/);
  assert.match(preload, /setUnreadCount\(count: number\)/);
  assert.match(rendererBridge, /configureDesktopNotifications/);
  assert.match(rendererBridge, /bridge\.setUnreadCount/);
});

test("electron renderer vite config stays ESM while main process stays CommonJS", () => {
  const packageJson = JSON.parse(readFromApp("package.json"));
  const tsconfig = readFromApp("tsconfig.json");
  const electronTsconfig = readFromApp("tsconfig.electron.json");
  const viteConfig = readFromApp("vite.config.mts");

  assert.equal(packageJson.type, undefined);
  assert.equal(packageJson.main, "dist-electron/main.js");
  assert.match(tsconfig, /vite\.config\.mts/);
  assert.doesNotMatch(tsconfig, /vite\.config\.ts/);
  assert.match(electronTsconfig, /"module":\s*"CommonJS"/);
  assert.match(viteConfig, /@flare-im\/sdk\/devtools\/vite/);
  assert.match(viteConfig, /import\.meta\.url/);
});
