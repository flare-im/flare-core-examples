# Flare Core Web Reference App

## What This Demonstrates

The functional reference for real browser IM: Vue 3, Vue Router, TypeScript,
Vite and the Web/WASM SDK. This is an official Flare design consumer undergoing
canonical UI migration, not a claim that every screen is already migrated.

## Architecture

`src/App.vue` mounts `../../shared/vue-reference/ReferenceApp.vue`. Web and Tauri
share routing, SDK-to-UI adapters and workbench composition under
`shared/vue-reference/workbench`. Reusable presentation belongs in
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

`src/notifications/MessageAlerts.vue`, mounted inside the reference app (its default slot), shows
what the engine decided: browser notifications through the SDK notifier
(`startSystemNotifications`, the browser presenter; a click opens the
conversation) and the kit in-app banner for surface `inApp` with the app's
message sound. It reports the open chat of a focused window
(`notification.setFocus`) and asks for the notification permission once per
account from the conversation list with the kit `PermissionPrompt` soft-ask.
The same permission (`src/notifications/permission.ts`) is the "New message
notifications" row of the workbench settings sheet, next to quiet hours,
notification preview and the multi-device policy (the core's
`notification.getSettings` / `updateSettings`).

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

## Endpoint configuration

Set `VITE_FLARE_CORE_API_URL` and `VITE_FLARE_WEBSOCKET_URL` for a production build. `VITE_FLARE_MEDIA_BASE_URL` is optional and defaults to the Core API. Development runs use the local stack at `http://127.0.0.1:50050` and `ws://127.0.0.1:60051`. The sign-in screen uses the addresses supplied by the build.

`VITE_FLARE_TENANT_ID` sets the tenant (default `0`). `VITE_FLARE_APP_BUILD` and `VITE_FLARE_APP_CHANNEL` set the application build number and channel.

## Web Updates

A production build also writes `sw.js`, `asset-manifest.json` and
`builds/<buildId>/` into `dist/`. `VITE_FLARE_WEB_BUILD_ID` names the build;
without it the build makes one from the day. The build log prints the manifest's
SHA-256 for the release manifest, whose `urls` point at
`builds/<buildId>/asset-manifest.json`.

Deployments must keep `builds/` and the hashed files of `assets/` of the releases
still on offer: a rollback fetches them. `flare-web-retain-builds` carries them
into a new `dist/` (see the `@flare-im/core-web-update` README). Serve `sw.js`, `index.html`
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
