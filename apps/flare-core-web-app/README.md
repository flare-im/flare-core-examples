# Flare Core Web Reference App

## What This Demonstrates

The functional reference for real browser IM: Vue 3, Vue Router, TypeScript,
Vite and the Web/WASM SDK. This is an official Flare design consumer undergoing
canonical UI migration, not a claim that every screen is already migrated.

## Architecture

`src/App.vue` mounts `../shared/vue-reference/ReferenceApp.vue`. Web and Tauri
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

Browser IndexedDB, File/Blob upload, microphone permissions, clipboard, download
and WASM loading stay in the host. For local-to-remote validation use the existing
Vite API proxy when the server does not permit browser cross-origin requests:

```bash
VITE_MEDIA_API_PROXY_TARGET=https://your-server/api npm run dev:web -- --port 1431
```

Set HTTP gateway to `http://127.0.0.1:1431/__flare-media-api`; WebSocket remains
the real server's `wss://...` endpoint. Do not disable browser CORS protections.

## Migration Status

Web/Tauri now share the full real workbench, not the earlier simplified demo.
Some account/search/menu composition and legacy kit workbench classes remain;
canonical ownership is not yet complete. Run the three `reference-app-*` gates
from the SDK root and consult the report before making completion claims.
