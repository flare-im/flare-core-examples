# Flare Core Tauri Reference App

## What This Demonstrates

A native desktop SDK host using the same functional conversation/message
composition as the Web reference, with Vue 3, Vite and Tauri 2.

## Architecture

`src/App.vue` mounts shared `ReferenceApp.vue`; the shared router/workbench is
adapter-independent example composition, not a copied Web app. The host injects
a native SDK factory. There is no Web/WASM or fake-data fallback in Tauri.

## flare-im-design Package Used

Public `@flare-im/vue-ui` and `@flare-im/tokens`, workspace version
`2.0.0-rc.1`. Vite consumes local kit sources and deduplicates the Vue runtime.
Tauri owns no separate message/composer CSS; shared ownership gaps still count.

## SDK Adapter

`src/integration/referenceRuntime.ts` uses `FlareCoreSdk.createClient()` and
registers native file-path resolution, scoped file picking and the private TLS
CA. Rust commands/plugins remain in `src-tauri`; SDK events and outgoing
operations use the shared workbench adapter.

`src/notifications/MessageAlerts.vue`, mounted inside the reference app (its default slot), shows
what the engine decided: system notifications through the SDK notifier
(`startSystemNotifications`) with a presenter over the Tauri notification plugin
(`src/desktopNotifications.ts`), the kit in-app banner for surface `inApp` with
the app's message sound, and the dock / taskbar badge and tray title from
`notification.badge`. It reports the open chat of a focused window
(`notification.setFocus`) and asks for the notification permission once per
account from the conversation list with the kit `PermissionPrompt` soft-ask.
The same permission (`src/notifications/permission.ts`) is the "New message
notifications" row of the workbench settings sheet, next to quiet hours,
notification preview and the multi-device policy (the core's
`notification.getSettings` / `updateSettings`).

## Run

```bash
npm install
npm run typecheck
npm test
npm run build
cargo check --manifest-path src-tauri/Cargo.toml
npm run tauri -- dev
```

Use `npm run dev:renderer` only to inspect the renderer: a plain browser has no
Tauri IPC bridge and cannot substitute for native SDK testing.

## Demo Mode

The runnable app uses the real SDK. There is no automatic fake-data fallback.
Unit/widget fixtures are test inputs, not a supported product demo mode.

## Real SDK Mode

Enter a test user ID on the login screen. Where the app connects is fixed when it
is built: the login screen has no server settings. With only a user ID the SDK
issues and renews the connect token through the core API; do not put signing keys
in UI code. Use isolated test accounts for destructive or send workflows.

## Endpoint configuration

Set `VITE_FLARE_CORE_API_URL` and `VITE_FLARE_WEBSOCKET_URL` for a production build. `VITE_FLARE_MEDIA_BASE_URL` is optional and defaults to the Core API. Development runs use the local stack at `http://127.0.0.1:50050` and `ws://127.0.0.1:60051`. The sign-in screen uses the addresses supplied by the build.

`VITE_FLARE_TENANT_ID` sets the tenant (default `0`). `VITE_FLARE_APP_BUILD` and `VITE_FLARE_APP_CHANNEL` set the application build number and channel.

Tauri also accepts `VITE_FLARE_QUIC_URL` and a private CA path in `VITE_FLARE_TLS_CA_CERT_PATH`.

## Updates and Recovery Links

`VITE_FLARE_APP_BUILD` gives the integer build number, without which the core
checks for no update; `VITE_FLARE_APP_CHANNEL` the update channel (default
`stable`). The Tauri binding adds the version and desktop target.

`tauri.conf.json` holds no updater key. `yarn tauri:build` adds the updater from
the build's environment: `FLARE_UPDATER_PUBKEY` (the key's content),
`FLARE_UPDATER_ENDPOINTS` (comma separated) and the signing key `tauri build`
reads, `TAURI_SIGNING_PRIVATE_KEY`. Without them the app builds without an
updater, and an update prompt offers the website instead.

A store build names its store in `VITE_FLARE_DISTRIBUTION` (say `appstore`),
which goes to `app.distribution`; without it the distribution is `tauri`. Set it
in the build's environment, not in a `.env` file: `tauri:build` reads it too. A
store build never has an updater, whatever the variables above hold, because
stores forbid self-update; an update opens the store page instead. The window
may open `itms-apps://`, `macappstore://` and `ms-windows-store://`. The core
only derives the default address for `appstore`, other stores need `storeUrl` in
the release manifest. `macOSPrivateApi` stays off: nothing here needs a transparent
window, and the App Store does not accept the private APIs it stands for.

## Supported Features

Conversation/message flows are the Core scope: session initialization, list,
opening a conversation, timeline, composer, send/retry, message actions, search,
media and SDK diagnostics. Integration and canonical-renderer coverage differ by
platform. See the [UI reuse policy](https://github.com/flare-im/flare-im-design/blob/main/docs/ui-component-reuse-policy.md) for component ownership.
Contact-directory, group-directory and relationship navigation require a Social
adapter. Group conversations are messaging targets, not group administration.

## Platform-Specific Integration

Native filesystem paths, file dialog, tray, window lifecycle, notifications,
unread badge, permissions and certificate paths stay in Tauri. There is no
transport selector: the core races QUIC and WebSocket per access point.
