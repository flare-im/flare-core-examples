# Flare Core iOS Reference App

English · [Simplified Chinese](README.zh-CN.md)

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
swift build
swift test
xcodegen generate
xcodebuild -project FlareImApp.xcodeproj -scheme FlareImExampleApp -destination 'generic/platform=iOS Simulator' ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
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
- Release builds require `baseUrl` and `websocketUrl` in `FLARE_CORE_ENDPOINTS_JSON`. `quicUrl` and `mediaBaseUrl` are optional.

## Push Notifications

APNs pushes arrive through `FlarePlatformPush` (a product of `flare-core-apple-sdk`), whose host is the core client
(`CorePushHost`). Presentation, de-duplication and the badge are the module's and the core's; the app wires:

- `FlareImAppDelegate`, installed by the runner with `@UIApplicationDelegateAdaptor`: starts the module before launch
  returns (so a tap that launched the app is not lost) and forwards the APNs token and silent-push callbacks. It also
  restores the saved session at launch, without any UI, on the process's one `FlareAppStore` (`FlareAppStore.shared`,
  holding the one client): a process that a background refresh or a silent push started cold has no UI, and the push
  host is attached as soon as the local store is open. The UI uses the same store afterwards. A silent push that
  arrives while that restore is still running waits for it (at most 2 s) so the core can wake and sync.
- `PushNotifications`: attaches the client once a sign-in or a session restore succeeds, and hands logout or dispose to
  the module's `signOut()`, which detaches it and clears this SDK's notifications and the badge. Token registration
  carries the app's language (`setLocale`).
- Permission: the status comes from the module's `permissionChanges()`. When a signed-in account reaches the
  conversation list with notifications off, the kit soft-ask (`flarePermissionPrompt`) explains why in a sheet: Turn on
  notifications shows the system prompt while the system has not asked yet, Open Settings once they are off. Any
  choice is remembered for that account. Settings shows the kit `NotificationDeliverySettingsView`: tapping New message
  notifications asks when the system never has, and opens the app's notification settings otherwise.
- Taps open the conversation, including a tap that launched the app before the session was restored.
- While the app is open, the engine decides each alert and hands in-app ones over as `notification.present` (surface
  `inApp`): `MessageAlerts` feeds them to the kit `InAppNotificationHost` at the root (tapping a banner opens the
  conversation like a notification tap) and plays the system message sound when the engine asks. The chat page reports
  the conversation on screen (`notification.setFocus`, cleared in the background). Settings adds the kit
  `NotificationAlertSettingsView`: quiet hours, preview and the other-device behaviour, shared by the account's
  devices, saved through `notification.updateSettings` (shown at once, rolled back and read again when a save fails).
- `NotificationService`, an app extension subclassing `FlareNotificationServiceBase` (product
  `FlareNotificationService`): re-renders alert titles and sender names from the snapshot the engine writes into the
  App Group `group.com.flare.im.example.app`, applies the local preview setting and records arrival receipts.
  `PushNotifications.configuration` gives the push module the same App Group, declares the extension (token
  registration then carries `serviceExtension`, so the server marks alerts `mutable-content`) and names the background
  refresh task `com.flare.im.example.app.refresh`, which prefetches new messages at most every 15 minutes while signed
  in.

To receive pushes:

1. In the platform console, the application's APNs credential (team ID, key ID and the `.p8` auth key) lists this
   app's bundle ID, `com.flare.im.example.app`, in its topics. A deployment without the console puts the same record
   in the push worker's `flare.mobile-push-applications/v2` file (see `docs/offline-push-delivery.md` in
   `flare-core-server`). One key serves both APNs environments; each device registers its own.
2. Sign with a team whose App ID has Push Notifications enabled, using a provisioning profile that includes it.
   `Resources/FlareImApp.entitlements` (generated from `project.yml`) carries `aps-environment: development`, and
   automatic signing adds the capability to the App ID. The module reads the environment from the embedded profile at
   run time: development-signed builds register as `sandbox`, App Store and TestFlight builds as `production`. A new
   `PRODUCT_BUNDLE_IDENTIFIER` has to be added to the credential's topics as well.
3. Run on a device, or on a simulator on an Apple silicon Mac; simulator builds always register as `sandbox`.
4. The extension (`com.flare.im.example.app.NotificationService`) is signed by the same team, and both App IDs need the
   App Groups capability with `group.com.flare.im.example.app` (automatic signing registers it; with manual signing
   add the group to both profiles). Another bundle ID changes the App Group, the task identifier and the extension's
   bundle ID together, in `project.yml`, `PushNotifications.configuration` and
   `NotificationService/NotificationService.swift`. Without the App Group pushes still arrive, with the server's text
   and no arrival receipts.

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

## Localization integration

Kit strings follow the app language. Swift custom strings use the configuration closure. See [native localization integration](../../docs/native-localization.md) for the migration, generated resources, and platform adapters.

For the arm64 Simulator link, prepare `FFI/ios/aarch64-apple-ios-sim/libflare_im_core_sdk_ffi.a` from the Core SDK engine. The Swift package tests exercise adapters without that Simulator binary; optional FFI and service tests name their required environment variables in their skip messages.
