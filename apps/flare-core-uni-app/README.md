# flare-core-uni-app

English · [中文](README.zh-CN.md)

The **uni-app** IM workbench template for `@flare-im/sdk`.

This example no longer maintains a duplicate uni-specific UI. uni-app is responsible for platform launch, page entry points, `src/router.ts` route registration, and the SDK client factory; the login, home-page sync, conversation list, chat, message building, media, capabilities, diagnostics, and SDK Lab feature surfaces reuse the components and business functions exposed by `shared/vue-reference/workbench/app`, and SDK calls go through the `uni-app` adapter of `packages/@flare-im/sdk`.

## SDK

- Package: `packages/@flare-im/sdk`
- Adapter: `src/adapters/uni-app`
- UI/workbench blocks: `shared/vue-reference/workbench/app`

## Transport and storage

The uni-app adapter automatically splits by runtime (`configureReferenceApp` in `src/main.ts` +
`FlareCoreSdk.createClient()`):

| Runtime | Bridge | Transport | Storage |
| --- | --- | --- | --- |
| **H5 / web** | WASM | WebSocket | IndexedDB |
| **App (Android / iOS)** | FFI (`bindings/c` TurboModule) → native core | WebSocket + QUIC protocol race | SQLite |

- There is no transport selector: the core races QUIC and WebSocket per access point where the runtime has QUIC; H5 has WebSocket only.
- Where to connect is the SDK `access` configuration (signed seed or development endpoints), not a sign-in setting.
- The App side relies on a native plugin to expose `bindings/c` as `globalThis.__FLARE_IM_CORE_NATIVE__` (TurboModule).
- The race algorithm and the SQLite engine belong to the Rust core. See
  [runtime boundaries](../../../flare-core-sdk/docs/design/transport-storage-multiruntime.md) for details.
- This host mounts the current application-owned reference workbench and its access configuration. Native uni-app bridge installation remains host-specific.

## Directory structure

```text
App.vue                # Global style entry point
src/main.ts            # uni-app createSSRApp + TS SDK uni adapter configuration
src/FlareCoreApp.vue   # Root IM workbench component mounted inside the uni page
src/router.ts          # uni-side route table, route guard, and page registration
src/platform/          # uni-platform media picking, local path resolution, and Flutter-aligned capability list
pages/index/index.vue  # Single-page entry point that mounts the uni-side workbench root component
tests/                 # uni-app / H5 / Flutter parity constraints
```

See the full specification in [`docs/STRUCTURE.md`](../../docs/STRUCTURE.md).

## Capability list

- SDK initialization, login, logout, and token update
- Home-page sync gate, conversation list, conversation open, pin, do-not-disturb, archive, draft, read
- Chat window, message search, and text/emoji/sticker/rich-text/media/structured message building
- Message edit, delete, reaction, quote, pin, forward, resend, and batch-selection entries
- diagnostics, connection/session, media cache, presence, capability, events SDK Lab

The feature surface is aligned with the workbench goals of `apps/flare-core-flutter-app`; the Vue/uni side reuses components, state functions, and platform adapter hooks through `shared/vue-reference/workbench/app`, while keeping the application shell and routing inside the uni example to avoid the shared package becoming a fixed application.

## Development

```bash
cd apps/flare-core-uni-app
npm install
npm run typecheck
npm run test
npm run verify
```
