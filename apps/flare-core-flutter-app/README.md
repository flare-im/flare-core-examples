# Flare Core Flutter Reference App

## What This Demonstrates

An official Flare design consumer under active canonical UI migration.
Flutter, Riverpod and GoRouter on mobile and desktop.

## Architecture

`SdkWrapper` owns the public `FlareCoreSdk.createClient()` client. Repositories,
Riverpod providers and SDK event scopes expose view state; message/composer
adapters translate contracts and callbacks for public kit widgets.

## flare-im-design Package Used

`flare_im_ui` from the relative `flare-im-design/packages/flutter-im-ui` path.

`FlareIMAppKit`, `FlareConversationRow`, `FlareConversationHeader`,
`FlareMessageBubble`, `FlareComposer`, `FlareReactionSummary`, context menu and
image preview are integrated. Some timeline/composer/menu widgets still own
reusable presentation and must be migrated; wrapper names do not prove purity.

## SDK Adapter

SDK authentication, persistence, event subscriptions, lifecycle transitions,
retry and media transfer stay in the SDK/application layer. Public kit data
contracts and intents form the visual boundary; do not import private renderers.

## Run

```bash
flutter pub get
flutter analyze
flutter test
flutter build macos --debug
flutter run -d macos
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

FFI artifact loading, Riverpod lifecycle, GoRouter navigation, file/photo
picking, microphone permissions, local/authenticated media resolution and
platform sharing stay in the host. `scripts/sync_ffi.sh` installs matching
native SDK artifacts. This Core reference app ships no audio/video calls; calls
are the managed `flare.call` plugin, integrated by product apps.

## Migration Status

71 application tests and analyze pass; macOS debug build passes. The kit
reaction regression verifies keyboard activation, selected semantics and a
48-point target. Fixed-light legacy aliases and local composer/search/detail
surfaces remain. Mobile device UI, all six themes and native media flows are
not fully verified.

The [migration report](../CANONICAL_UI_MIGRATION_REPORT.md) records the current
feature matrix, test evidence and outstanding P1/P2 work. Reusable UI fixes
belong in the design kit, not in local visual overrides.
