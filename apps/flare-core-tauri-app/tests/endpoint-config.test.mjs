import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { test } from "node:test";

const appRoot = join(import.meta.dirname, "..");
const monorepoRoot = join(appRoot, "../../..");
const sharedRoot = join(monorepoRoot, "flare-core-examples/shared/vue-reference");
const accessModule = join(sharedRoot, "workbench/app/runtime/endpoints.ts");

const read = (path) => readFileSync(path, "utf8");

function sources(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) sources(path, out);
    else if (/\.(ts|vue)$/.test(name) && !/\.test\.ts$/.test(name)) out.push(path);
  }
  return out;
}
const files = [...sources(join(appRoot, "src")), ...sources(sharedRoot)];
// The forbidden names are spelled from parts, so this test does not trip the repository grep gate it mirrors.

test("where the app connects comes from the host endpoint settings", () => {
  const endpoints = read(accessModule);
  assert.match(endpoints, /VITE_FLARE_CORE_API_URL/);
  assert.match(endpoints, /VITE_FLARE_WEBSOCKET_URL/);
  assert.match(endpoints, /env\.DEV === true/);
  const provider = read(join(sharedRoot, "workbench/app/sdk/flareSdkContext.ts"));
  assert.match(provider, /endpoints: resolveCoreEndpoints\(import\.meta\.env\)/);
});
test("the sign-in page has no server settings", () => {
  const auth = read(join(sharedRoot, "workbench/app/components/AuthScreen.vue"));
  const login = read(join(sharedRoot, "workbench/app/components/FlareLoginScreen.vue"));
  assert.doesNotMatch(auth, /auth-server|transportMode|tlsCaCert/);
  assert.doesNotMatch(login, /transportMode|tlsCaCert|transportFallbackNotice/);
  assert.match(login, /endpointConfigError/);
});

test("network and foreground reports are the SDK's platform lifecycle, not the app's", () => {
  const lifecycleReport = new RegExp([
    "notify" + "NetworkChange", "setHeartbeat" + "AppState", "lifecycle\\.setAppState",
    "addEventListener\\(\\s*[\"'](online|offline|visibilitychange)[\"']",
  ].join("|"));
  const wiring = files.filter((file) => lifecycleReport.test(read(file)));
  assert.deepEqual(wiring.map((file) => relative(monorepoRoot, file)), []);
});

test("one connection notice reads connection://status and carries out the kit's actions", () => {
  const app = read(join(sharedRoot, "ReferenceApp.vue"));
  assert.match(app, /<FlareConnectionNotice[\s\S]*:status="sdk\.connectionStatus\.value"/);
  assert.match(app, /@retry="sdk\.reconnectNow"/);
  assert.match(app, /@sign-in="sdk\.signInAgain"/);
  const removedEvents = new RegExp(["connected", "disconnected", "kicked_off", "token_expired"].map((name) => `im:\\/\\/${name}\\b`).join("|"));
  const oldSubscribers = files.filter((file) => removedEvents.test(read(file)) || /getConnectionState|onKickedOffline|onUserTokenExpired/.test(read(file)));
  assert.deepEqual(oldSubscribers.map((file) => relative(monorepoRoot, file)), []);
});
