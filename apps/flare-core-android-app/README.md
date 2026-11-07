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
../flare-core-flutter-app/android/gradlew :app:testDirectDebugUnitTest :app:lintDirectDebug :app:assembleDirectDebug
../flare-core-flutter-app/android/gradlew :app:compileDirectDebugAndroidTestKotlin
```

## Demo Mode

The runnable app uses the real SDK. There is no automatic fake-data fallback.
Unit/widget fixtures are test inputs, not a supported product demo mode.

## Real SDK Mode

Enter a test user ID on the login screen. Where the SDK connects is not a login
setting: it comes from the build's access configuration (below). The SDK issues
and refreshes connect tokens itself (`auth: {}`) on the Core API of the access
point it is on; do not put signing keys in UI code.
Use isolated test accounts for destructive or send workflows.

## Access Configuration

The app hands the core SDK `sdkConfig.access` (`AppAccess.kt`) and `auth: {}`
(SDK-managed connect tokens, issued on the Core API: in development
`developmentEndpoints.coreApiUrl`, in production the access point's Core API). Each setting is read from a Gradle property first, then the
environment variable of the same name; blank counts as unset.

| Setting | Meaning |
|---|---|
| `FLARE_ACCESS_JSON` | The whole `access` object: the production one (`bootstrapId`, `trustRoots`, `seed`, `trustMode: production`), or a complete development one. Required for release builds. |
| `FLARE_DEV_WS_URL` | Development IM entry. Default `ws://10.0.2.2:60051` (the emulator reaches the host's `access-gateway.toml` port). |
| `FLARE_DEV_QUIC_URL` | Development QUIC entry; QUIC is offered only when given (for example `quic://10.0.2.2:60052`). |
| `FLARE_DEV_CORE_API_URL` | Development Core HTTP entry. Default `http://10.0.2.2:50050` (`api-gateway.toml`). |
| `FLARE_DEV_MEDIA_URL` | Development media entry. Defaults to the Core HTTP entry. |

Debug builds without `FLARE_ACCESS_JSON` build development endpoints from the
`FLARE_DEV_*` settings; the connection notice then wears the development badge.
Two access points on the local stack (failover drills) take the full object:

```bash
FLARE_ACCESS_JSON='{"trustMode":"development","developmentEndpoints":{"wsUrl":"ws://10.0.2.2:60051","coreApiUrl":"http://10.0.2.2:50050","accessPoints":[{"id":"dev-b","wsUrl":"ws://10.0.2.2:61051","coreApiUrl":"http://10.0.2.2:51050"}]}}' \
  ./gradlew :app:assembleDirectDebug
```

A release build without `FLARE_ACCESS_JSON`, or with a development one, stops
at `preDirectReleaseBuild` (`prePlayReleaseBuild` on the play flavor), and the app refuses development access at runtime.
Line choice, protocol racing, reconnecting, network changes and foreground
state are the SDK's: `FlareCoreSdk.createClient(context)` installs the platform
lifecycle after `init`, and the connection banner is the kit `ConnectionNotice`
fed by `connection://status`.

## Distribution flavors

The `distribution` dimension sets `app.distribution`, which the release manifest picks a package by.

| Flavor | For | Installs through |
|---|---|---|
| `direct` (default) | The website | A system install session. Only this flavor declares `REQUEST_INSTALL_PACKAGES`. |
| `play` | Google Play | Play In-App Updates. Only this flavor carries the Play dependency. |

Task names carry the flavor: `assembleDirectDebug`, `assemblePlayRelease`,
`compileDirectDebugKotlin`, `testDirectDebugUnitTest`. The update channel is
`stable` unless `-PFLARE_UPDATE_CHANNEL=beta` or the environment variable of
the same name says otherwise.

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
