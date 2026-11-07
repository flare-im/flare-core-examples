# Flare Core Web Reference App

## What This Demonstrates

The functional reference for real browser IM: Vue 3, Vue Router, TypeScript,
Vite and the Web/WASM SDK. This is an official Flare design consumer undergoing
canonical UI migration, not a claim that every screen is already migrated.

## Architecture

`src/App.vue` mounts `../../../flare-core-sdk/examples/shared/vue-reference/ReferenceApp.vue`. Web and Tauri
share routing, SDK-to-UI adapters and workbench composition under
`examples/shared/vue-reference/workbench`. Reusable presentation belongs in
`flare-im-design`; moving code into shared composition does not exempt it from
ownership checks. No Web-specific screen implementation is imported by Tauri.

## flare-im-design Package Used

Public `@flare-im/vue-ui` entries and `@flare-im/tokens` at `2.0.0-rc.1`, via
relative workspace dependencies. Vite resolves local kit sources for dev/HMR.
The workbench uses public Shell, ChatWorkspace, ConversationHeader, MessageList,
Composer, preview, form, forward picker, settings and status components.

## SDK Adapter

`src/integration/referenceRuntime.ts` supplies the Web client factory through
`WebProductionBridge`. Shared `bootstrap.ts` registers it before mounting;
`workbench/app/sdk/flareSdkContext.ts` and `useFlareCoreClient.ts` own SDK state,
subscriptions and commands. The kit receives presentation contracts and intents.

## Run

```bash
npm install
npm run dev:web
npm run typecheck
npm test -- --maxWorkers=1
npm run test:e2e
npm run build
```

Default URL: `http://127.0.0.1:1430`. WASM bindings must be available at the SDK
path configured by the Vite helper; dev/build serves a matched JS/WASM pair.
For bounded unit-test execution use `npx vitest run --maxWorkers=1 --no-file-parallelism`.

## Demo Mode

The runnable app uses the real SDK. There is no automatic fake-data fallback.
Unit/widget fixtures are test inputs, not a supported product demo mode.

## Real SDK Mode

Enter a test user ID on the login screen. Where the app connects is fixed when it
is built: the login screen has no server settings. With only a user ID the SDK
issues and renews the connect token through the core API (start the API gateway
with `FLARE_API_GATEWAY_AUTH_DEV_ISSUE=true` locally); do not put signing keys in
UI code. Use isolated test accounts for destructive or send workflows.

## Access Configuration

The core SDK's `access` object comes from `VITE_FLARE_ACCESS_JSON` at build time
(`../../../flare-core-sdk/examples/shared/vue-reference/workbench/app/runtime/access.ts`):

- unset, `npm run dev:web` connects to the local stack in development mode:
  IM `ws://127.0.0.1:60051` (access-gateway), core API and media
  `http://127.0.0.1:50050` (api-gateway);
- unset, a production build shows that it has no access configuration and offers
  no sign-in; it never falls back to development endpoints;
- set, the object is handed to the SDK as it is: a signed seed
  (`bootstrapId`, `trustRoots`, `seed`, `trustMode: "production"`) for releases,
  or development endpoints for labs. A second access point of the same cell goes
  under `developmentEndpoints.accessPoints` (local failover drills):

```bash
VITE_FLARE_ACCESS_JSON='{"trustMode":"development","developmentEndpoints":{
  "wsUrl":"ws://127.0.0.1:60051","coreApiUrl":"http://127.0.0.1:50050","mediaUrl":"http://127.0.0.1:50050",
  "accessPoints":[{"id":"dev-b","wsUrl":"ws://127.0.0.1:61051","coreApiUrl":"http://127.0.0.1:51050","mediaUrl":"http://127.0.0.1:51050"}]}}' \
  npm run dev:web
```

The browser has no QUIC: `quicUrl` entries are ignored by the Web/WASM runtime.
`VITE_FLARE_TENANT_ID` sets the tenant (default `0`); `VITE_FLARE_APP_BUILD` the
integer build reported on CONNECT (the version is this package's `version`);
`VITE_FLARE_APP_CHANNEL` the update channel (default `stable`).
Network and page-visibility changes are reported by the SDK itself, and the one
connection notice follows `connection://status`.

## Web Updates

A production build also writes `sw.js`, `asset-manifest.json` and
`builds/<buildId>/` into `dist/`. `VITE_FLARE_WEB_BUILD_ID` names the build;
without it the build makes one from the day. The build log prints the manifest's
SHA-256 for the release manifest, whose `urls` point at
`builds/<buildId>/asset-manifest.json`.

Deployments must keep `builds/` and the hashed files of `assets/` of the releases
still on offer: a rollback fetches them. `flare-web-retain-builds` carries them
into a new `dist/` (see the `@flare-im/sdk` README). Serve `sw.js`, `index.html`
and `asset-manifest.json` with `no-cache`, and the rest of those two directories
as immutable.

## Supported Features

Conversation/message flows are the Core scope: session initialization, list,
opening a conversation, timeline, composer, send/retry, message actions, search,
media and SDK diagnostics. Integration and canonical-renderer coverage differ by
platform. See the [UI reuse policy](https://github.com/flare-im/flare-im-design/blob/main/docs/ui-component-reuse-policy.md) for component ownership.
Contact-directory, group-directory and relationship navigation require a Social
adapter. Group conversations are messaging targets, not group administration.

## Platform-Specific Integration

Browser IndexedDB, File/Blob upload, microphone permissions, clipboard, download
and WASM loading stay in the host. The core API gateway answers cross-origin
requests itself, so development endpoints point straight at it; do not disable
browser CORS protections.
