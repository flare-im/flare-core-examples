# Flare Core iOS Reference App

## What This Demonstrates

An official Flare design consumer under active canonical UI migration.
Swift 6, SwiftUI, SwiftPM and the Apple SDK (iOS 16+; macOS package host).

## Architecture

`AppSession` owns `FlareImClientProtocol`. `ViewDataRepository`, feature
view models and SDK mappers handle session/events, paging, commands, media
resolution and capability decisions. SwiftUI owns native navigation and sheets.

## flare-im-design Package Used

`FlareIMUI` from the relative workspace package at `2.0.0-rc.1`.

Public `IMAppKitView`, `ConversationHeaderView`, `MessageBubbleView`,
`ComposerView` and `ImagePreviewView` are integrated. The local chat header and
action-overlay backdrop are removed; native sheet presentation is retained.
Local message action content, menu/panel modifiers and composer forms still
need canonical library integration.

## SDK Adapter

SDK authentication, persistence, event subscriptions, lifecycle transitions,
retry and media transfer stay in the SDK/application layer. Public kit data
contracts and intents form the visual boundary; do not import private renderers.

## Run

```bash
bash scripts/sync_ffi.sh
swift build
swift test
xcodegen generate
xcodebuild -project FlareImApp.xcodeproj -scheme FlareImExampleApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Demo Mode

The runnable app uses the real SDK. There is no automatic fake-data fallback.
Unit/widget fixtures are test inputs, not a supported product demo mode.

## Real SDK Mode

Enter a test user ID on the login screen. Where the app connects is not a login
setting: the build hands the SDK an `access` configuration (`AppAccess`), and the
SDK chooses the access point and protocol, reconnects, and reports network and
foreground changes itself. Values are read from the process environment first
(`SIMCTL_CHILD_` + the name on a simulator), then from Info.plist (the build
settings in `project.yml`):

- Debug builds run in development mode. With nothing set they use the local
  stack: IM `ws://127.0.0.1:60051`, Core HTTP and media `http://127.0.0.1:50050`.
  Override single entries with `FLARE_DEV_WS_URL`, `FLARE_DEV_QUIC_URL` (QUIC
  only when given; a self-signed server also needs `FLARE_TLS_CA_CERT`),
  `FLARE_DEV_CORE_API_URL` and `FLARE_DEV_MEDIA_URL`, for example
  `xcodebuild ... FLARE_DEV_WS_URL=ws://192.168.1.20:60051`.
- `FLARE_ACCESS_JSON` replaces all of them with a whole `access` object, for
  example a second access point for failover drills:
  `{"trustMode":"development","developmentEndpoints":{"wsUrl":"ws://127.0.0.1:60051","coreApiUrl":"http://127.0.0.1:50050","mediaUrl":"http://127.0.0.1:50050","accessPoints":[{"id":"dev-b","wsUrl":"ws://127.0.0.1:61051","coreApiUrl":"http://127.0.0.1:51050","mediaUrl":"http://127.0.0.1:51050"}]}}`
  (use the second entry's real ports).
- Release builds read only `FLARE_ACCESS_JSON` (the production `bootstrapId`,
  `trustRoots`, `seed` and `trustMode: production`) and stop at launch without
  it; they never fall back to development mode.

Connect tokens are SDK-managed (`"auth": {}` in every build): the SDK issues and
renews them on the Core API of the access point it uses, which in development is
the Core HTTP entry above. A token pasted in Settings is passed to login as
given. Do not put signing keys in UI code. Use isolated test accounts for destructive or send
workflows.

## Supported Features

Conversation/message flows are the Core scope: session initialization, list,
opening a conversation, timeline, composer, send/retry, message actions, search,
media and SDK diagnostics. Integration and canonical-renderer coverage differ by
platform. See the [UI reuse policy](https://github.com/flare-im/flare-im-design/blob/main/docs/ui-component-reuse-policy.md) for component ownership.
Contact-directory, group-directory and relationship navigation require a Social
adapter. Group conversations are messaging targets, not group administration.

## Platform-Specific Integration

NavigationStack, sheet/fullScreenCover, file/photo pickers, microphone
permissions, sharing and FFI artifact loading stay native. Xcode selects the
static library by SDK and architecture: `aarch64-apple-ios` for arm64 devices,
`aarch64-apple-ios-sim` for arm64 simulators and `x86_64-apple-ios` for Intel
simulators. All three synced slices are required for generic iOS builds.
