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

NavigationStack, sheet/fullScreenCover, file/photo pickers, microphone
permissions, sharing and FFI artifact loading stay native. Xcode selects the
static library by SDK and architecture: `aarch64-apple-ios` for arm64 devices,
`aarch64-apple-ios-sim` for arm64 simulators and `x86_64-apple-ios` for Intel
simulators. All three synced slices are required for generic iOS builds.

## Migration Status

Swift tests: 53 executed, 6 environment-gated skipped, zero failures. An iPhone
17 Pro simulator build succeeds with signing disabled. This is compilation,
not completed VoiceOver or device interaction testing. Local surfaces and
six-brand/theme integration remain incomplete.

The [migration report](../CANONICAL_UI_MIGRATION_REPORT.md) records the current
feature matrix, test evidence and outstanding P1/P2 work. Reusable UI fixes
belong in the design kit, not in local visual overrides.
