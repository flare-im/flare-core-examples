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
registers native file-path resolution, scoped file picking, transport capability,
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
Unit/widget fixtures are test inputs, not a supported product demo mode. Shared
scenario-driven offline data and complete five-platform feature parity remain
tracked in [the migration report](../CANONICAL_UI_MIGRATION_REPORT.md).

## Real SDK Mode

Enter a test user ID and the WebSocket and HTTP gateway endpoints on the login
screen. Credentials are issued by the configured gateway; do not put signing
keys in UI code. Use isolated test accounts for destructive or send workflows.

## Supported Features

Conversation/message flows are the Core scope: session initialization, list,
opening a conversation, timeline, composer, send/retry, message actions, search,
media and SDK diagnostics. Integration and canonical-renderer coverage differ by
platform; see the [feature matrix and remaining gaps](../CANONICAL_UI_MIGRATION_REPORT.md).
Contact-directory, group-directory and relationship navigation require a Social
adapter. Group conversations are messaging targets, not group administration.

## Platform-Specific Integration

Native filesystem paths, file dialog, tray, window lifecycle, notifications,
unread badge, permissions and certificate paths stay in Tauri. The transport
selector is capability-driven; unsupported transports are not simulated.

## Migration Status

Frontend tests/build and Rust check pass. Native GUI send/receive, permission,
notification and file-bridge E2E were not executed in this migration. Shared
composition parity is not proof of native runtime parity.
