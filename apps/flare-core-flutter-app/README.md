# Flare Core Flutter Reference App

## What This Demonstrates

An official Flare design consumer under active canonical UI migration.
Flutter, Riverpod and GoRouter on mobile and desktop.

## Architecture

`SdkWrapper` owns the client created by `FlareCoreFlutter.createClient(config)`
(`flare_core_flutter_lifecycle`), which installs the platform lifecycle with the
client's init: device network changes, foreground state and the app version
reach the core without any app wiring. Repositories, Riverpod providers and SDK
event scopes expose view state; message/composer adapters translate contracts
and callbacks for public kit widgets.

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
Unit/widget fixtures are test inputs, not a supported product demo mode.

## Real SDK Mode

Enter a test user ID on the login screen. Where the app connects is the build's
endpoint configuration (`lib/shared/config/endpoints.dart`); the login screen has no
server settings and the app keeps no addresses. Connect tokens are SDK-managed
(`auth: {}`): the core issues and refreshes them through the Core API of the
configured deployment;
the app configures no token address and holds no signing keys. Use isolated test
accounts for destructive or send workflows.

### Endpoint configuration

Release builds pass `--dart-define=FLARE_CORE_ENDPOINTS_JSON` with `baseUrl` and `websocketUrl`, plus optional `quicUrl` and `mediaBaseUrl`. Debug builds default to ports 50050 and 60051 on loopback, or the Android emulator host `10.0.2.2`. `FLARE_DEV_HOST`, `FLARE_DEV_CORE_API_URL`, `FLARE_DEV_WS_URL`, `FLARE_DEV_QUIC_URL`, and `FLARE_DEV_MEDIA_URL` override the debug defaults.

## Supported Features

Conversation/message flows are the Core scope: session initialization, list,
opening a conversation, timeline, composer, send/retry, message actions, search,
media and SDK diagnostics. Integration and canonical-renderer coverage differ by
platform. See the [UI reuse policy](https://github.com/flare-im/flare-im-design/blob/main/docs/ui-component-reuse-policy.md) for component ownership.
Contact-directory, group-directory and relationship navigation require a Social
adapter. Group conversations are messaging targets, not group administration.

## Update center

The prompt, the About page and the wiring of the controller live in
`flare_core_flutter_update_ui`; the app only places them. `UpdateHost` starts the
controller once the SDK is initialized, not at sign-in, because a build the
server refuses cannot sign in. Settings opens the Kit version panel, the
connection notice's Update now goes to the same controller, and in read-only
mode local conversations stay open while the composer is disabled.

Version and build in `sdkConfig.app` come from the installed package (`version`
in `pubspec.yaml`). The language is the app's own setting; update notes follow a
change at once. A build decides the rest:

| Define | Default | Meaning |
|---|---|---|
| `FLARE_APP_CHANNEL` | `stable` | Update channel |
| `FLARE_APP_DISTRIBUTION` | `direct` on Android, otherwise read from the install | Which artifact to take |
| `FLARE_APP_VERSION` | Read from the install | Required on Windows and Linux, which cannot read it |
| `FLARE_APP_BUILD` | Read from the install | Plain integer; required on Windows and Linux |

**Android ships direct builds only:** `AndroidManifest.xml` declares
`REQUEST_INSTALL_PACKAGES` and `android/settings.gradle.kts` registers
`flare-core-android-update`. Google Play refuses that permission and a direct
build must not carry the Play dependency, so a Play build needs flavors, as in
`flare-core-android-app`:

1. Add the dimension `distribution` with the flavors `direct` and `play` to
   `android/app/build.gradle.kts`.
2. Move `REQUEST_INSTALL_PACKAGES` from the main manifest to
   `android/app/src/direct/AndroidManifest.xml`.
3. Register `flare-core-android-update-play` in `android/settings.gradle.kts`,
   next to the module already there.
4. Add `"playImplementation"(project(":flare-core-android-update-play"))` to
   `android/app/build.gradle.kts`.
5. Add an `Application` under `src/play`, point the flavor's
   `manifestPlaceholders["applicationName"]` at it, and replace the installer in
   `onCreate`:

   ```kotlin
   FlareCoreFlutterUpdatePlugin.installerFactory =
       { context, activity -> FlarePlayUpdateInstaller(context, activity) }
   ```

6. Build with the channel:
   `flutter build appbundle --release --flavor play --dart-define=FLARE_APP_DISTRIBUTION=play`.

## System push

`flare_core_flutter_push` bridges the native platform push modules
(`FlarePlatformPush` on iOS, `flare-core-android-push` on Android); the engine
decides every alert through the core client's `CorePushHost`.

- `main` starts the plugin; it never asks for permission. `PushNotificationHost`
  hands the in-app language to `setLocale` (at start and on every change),
  attaches the host after sign-in or a restored session and, after sign-out,
  calls `signOut()`, which detaches it and clears this SDK's notifications.
- The permission state is the plugin's (`permissionChanges`). When the
  conversation list is reached after sign-in with notifications off, the Kit
  soft-ask (`FlarePermissionPrompt.show`, `softAsk: true`) explains the request
  in a sheet: Turn on notifications shows the system dialog while
  `canRequestPermission()` holds, Open Settings once the system will not ask
  again. Any choice is remembered per account. Settings places the Kit
  `FlareNotificationDeliverySettings` as a section of its one settings list
  (`sectionBuilder`): New message notifications asks while the system would show
  the dialog and otherwise opens the system notification settings; on Android it
  adds Receive messages in the background (from `backgroundChanges`), whose guide
  opens the battery settings and, on phones that have one, the maker's auto-start
  page.
- A tapped notification opens its conversation. A tap that cold-starts the app
  waits until the session is restored and the app has left the sign-in route.
- While the app is open, the engine decides each alert and hands in-app ones over
  as `notification.present` (surface `inApp`): `MessageAlertHost` (in
  `MaterialApp.builder`) feeds them to the Kit `FlareInAppNotificationHost`
  (tapping a banner opens the conversation like a notification tap) and plays the
  system message sound through the app's `flare.im/sound` channel when the engine
  asks. It reports the foreground chat (`notification.setFocus`, cleared in the
  background). Settings places the Kit `FlareNotificationAlertSettings` sections
  (quiet hours, preview, the other-device behaviour; shared by the account's
  devices) after the notification section, saved through
  `notification.updateSettings` (shown at once, rolled back and read again when a
  save fails).
- In the background the plugin's `FlareNotificationPresenter` shows the engine's
  system presentations, attached with the same host after sign-in and signed out
  with it. Android: the push module's background presenter; with notifications
  allowed the engine keeps acknowledging over the live link and alerts by
  itself, and pushes cover a frozen or killed process. macOS: the notification
  centre, asked for authorisation once after sign-in, one notification per
  conversation, the unread count on the dock tile. A click on either opens its
  conversation the same way as a push tap.

Android: `android/settings.gradle.kts` includes `:flare-core-android-push`, which
the plugin depends on. FCM needs the Firebase client configuration at
`android/app/google-services.json` (not committed, and the server's FCM
credentials must belong to the same Firebase project); the Google services plugin
is applied only when that file exists. Without it the app builds and runs, no FCM
token is registered, and messages arrive only over the live connection.

Getui (devices in mainland China) is off unless the build has a Getui app id,
the same `FLARE_GETUI_APP_ID` as the native Android app, given as a define:

```bash
flutter build apk --dart-define=FLARE_GETUI_APP_ID=<Getui app id>
```

The Android build reads the same define into the Getui SDK's `GETUI_APPID`
manifest placeholder, and the app calls `installGetui()` after sign-in, so no
push SDK starts before someone signed in. Without it the
`:flare-core-android-push-getui` module is compiled in but never started. Getui's
artifacts come from its own Maven repository, which `android/build.gradle.kts`
uses for `com.getui` coordinates only; the vendor channels are added as described
in that module's README.

iOS: `Runner.entitlements` carries `aps-environment` (`development`; a
distribution profile turns it into production), `Info.plist` lists the
`remote-notification` background mode, and `AppDelegate` calls
`FlareCoreFlutterPushPlugin.prepare()` before `super` so cold-start taps and
background launches reach the module before any scene connects. The deployment
target is iOS 15, the floor of `FlarePlatformPush`.

## Platform-Specific Integration

FFI artifact loading, Riverpod lifecycle, GoRouter navigation, file/photo
picking, microphone permissions, local/authenticated media resolution and
platform sharing stay in the host. `scripts/sync_ffi.sh` installs matching
native SDK artifacts. This Core reference app ships no audio/video calls; calls
are the managed `flare.call` plugin, integrated by product apps.

## Localization integration

Kit strings follow the app language. Swift custom strings use the configuration closure. See [native localization integration](../../docs/native-localization.md) for the migration, generated resources, and platform adapters.

The macOS build embeds `flare-core-sdk/native/artifacts/host/libflare_im_core_sdk_ffi.dylib` through `scripts/copy_macos_ffi_dylib.sh`. Prepare that SDK artifact first, or set `FLARE_CORE_FFI_DYLIB` to an explicit matching-architecture library. The app build validates architectures and signs its embedded copy; it does not invoke the removed workspace `cargo xtask`.

After rebuilding the engine FFI, run `make sync-host` in `flare-core-sdk` (use `CORE_DIST` for an isolated test dist). The macOS embedding phase checks every exported function declared by the generated SDK C header and rejects stale binaries before copying.
