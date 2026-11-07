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
registers native file-path resolution, scoped file picking, the private TLS CA,
notifications and unread-count bridges. Rust commands/plugins remain in
`src-tauri`; SDK events and outgoing operations use the shared workbench adapter.

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

## Access Configuration

The core SDK's `access` object comes from `VITE_FLARE_ACCESS_JSON` at build time
(shared `workbench/app/runtime/access.ts`, the same rule as the Web app):

- unset, `npm run tauri -- dev` connects to the local stack in development mode:
  IM `ws://127.0.0.1:60051`, core API and media `http://127.0.0.1:50050`;
- unset, a production build offers no sign-in and never falls back to
  development endpoints;
- set, the object goes to the SDK as it is. QUIC goes in `developmentEndpoints.quicUrl`,
  a second access point of the same cell in `developmentEndpoints.accessPoints`:

```bash
VITE_FLARE_ACCESS_JSON='{"trustMode":"development","developmentEndpoints":{
  "wsUrl":"ws://127.0.0.1:60051","quicUrl":"quic://127.0.0.1:60052","coreApiUrl":"http://127.0.0.1:50050",
  "accessPoints":[{"id":"dev-b","wsUrl":"ws://127.0.0.1:61051","coreApiUrl":"http://127.0.0.1:51050"}]}}' \
  npm run tauri -- dev
```

The private CA for TLS endpoints (a local gateway's self-signed QUIC) is
`VITE_FLARE_TLS_CA_CERT_PATH`; the dev server falls back to
`flare-core-server/certs/server.crt`. The Tauri binding reports the app version
and `distribution = "tauri"`; network and window-visibility changes are reported
by the SDK, and the one connection notice follows `connection://status`.

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

The app registers `flare-recover://`. A link the system delivers opens the
network page after sign-in and is imported there. macOS only delivers it to an
installed bundle.

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
