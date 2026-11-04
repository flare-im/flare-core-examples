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
Unit/widget fixtures are test inputs, not a supported product demo mode.

## Real SDK Mode

Enter a test user ID and the WebSocket and HTTP gateway endpoints on the login
screen. Credentials are issued by the configured gateway; do not put signing
keys in UI code. Use isolated test accounts for destructive or send workflows.

## Supported Features

Conversation/message flows are the Core scope: session initialization, list,
opening a conversation, timeline, composer, send/retry, message actions, search,
media and SDK diagnostics. Integration and canonical-renderer coverage differ by
platform. See the [UI reuse policy](https://github.com/flare-im/flare-im-design/blob/main/docs/ui-component-reuse-policy.md) for component ownership.
Contact-directory, group-directory and relationship navigation require a Social
adapter. Group conversations are messaging targets, not group administration.

## Platform-Specific Integration

Activity lifecycle, system back, IME, navigation, permissions, file/camera
selection and JNI loading are host responsibilities. Use `scripts/sync_ffi.sh`
after building the matching native SDK artifacts.
