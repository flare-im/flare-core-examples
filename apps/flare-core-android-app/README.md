# Flare Core Android Reference App

## What This Demonstrates

An official Flare design consumer under active canonical UI migration.
Kotlin, Compose, Android Navigation and lifecycle-aware ViewModels.

## Architecture

`AppSession` owns the public `FlareImClient`; repositories and ViewModels
map SDK state into conversation, lifecycle, message and capability contracts.
Screens compose kit components and invoke SDK actions through their adapters.

## flare-im-design Package Used

`com.flare.im:im-ui-compose:2.0.0-rc.1`, substituted by the relative workspace composite build.

Public `IMAppKit`, `ConversationRow`, `ConversationHeader`, `MessageBubble`,
`Composer` and `ImagePreview` are integrated. The old hand-drawn chat header
is removed. Search sheets, conversation menus and other local composables
are still migration work, not already canonical.

## SDK Adapter

SDK authentication, persistence, event subscriptions, lifecycle transitions,
retry and media transfer stay in the SDK/application layer. Public kit data
contracts and intents form the visual boundary; do not import private renderers.

## Run

```bash
export ANDROID_HOME=/path/to/android/sdk
../flare-core-flutter-app/android/gradlew :app:testDebugUnitTest :app:lintDebug :app:assembleDebug
../flare-core-flutter-app/android/gradlew :app:compileDebugAndroidTestKotlin
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

Activity lifecycle, system back, IME, navigation, permissions, file/camera
selection and JNI loading are host responsibilities. Use `scripts/sync_ffi.sh`
after building the matching native SDK artifacts.

## Migration Status

Unit-test/lint/assemble tasks pass. Instrumentation compile reports NO-SOURCE;
that is not a Compose UI test pass. No Android device was attached. Typography
and spacing aliases now use kit tokens, but native menu/workspace and six-brand
integration remain incomplete.

The [migration report](../CANONICAL_UI_MIGRATION_REPORT.md) records the current
feature matrix, test evidence and outstanding P1/P2 work. Reusable UI fixes
belong in the design kit, not in local visual overrides.
