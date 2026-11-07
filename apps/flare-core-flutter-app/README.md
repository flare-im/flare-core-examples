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
access config (`lib/shared/config/access_config.dart`); the login screen has no
server settings and the app keeps no addresses. Connect tokens are SDK-managed
(`auth: {}`): the core issues and refreshes them through the Core API of the
access point it uses (in development mode `developmentEndpoints.coreApiUrl`);
the app configures no token address and holds no signing keys. Use isolated test
accounts for destructive or send workflows.

### Access config

A release build needs the signed access config:

```bash
flutter build apk --release \
  --dart-define=FLARE_ACCESS_JSON='{"bootstrapId":"…","trustRoots":[…],"seed":"…","trustMode":"production"}'
```

Without `FLARE_ACCESS_JSON`, or with a development one, a release build fails at
SDK init instead of falling back to development mode.

Debug and profile builds without `FLARE_ACCESS_JSON` run in development mode
(unsigned local endpoints; the kit connection notice wears its development
badge). The defaults are the local stack's ports:

| define | default | |
|---|---|---|
| `FLARE_DEV_HOST` | `127.0.0.1`; `10.0.2.2` on Android | the host below. The Android emulator reaches the host machine at `10.0.2.2`; a device needs the machine's LAN address |
| `FLARE_DEV_WS_URL` | `ws://<host>:60051/ws` | gateway WebSocket |
| `FLARE_DEV_QUIC_URL` | none | gateway QUIC (local QUIC needs a certificate; WebSocket only by default) |
| `FLARE_DEV_CORE_API_URL` | `http://<host>:50050` | Core HTTP |
| `FLARE_DEV_MEDIA_URL` | Core HTTP | media |

A given entry replaces its default whole. Two local access points (failover
drills) and any other full development config go in `FLARE_ACCESS_JSON`; the
primary access point is `development`, `accessPoints` lists the others in the
same cell:

```bash
flutter run -d macos \
  --dart-define='FLARE_ACCESS_JSON={"trustMode":"development","developmentEndpoints":{"wsUrl":"ws://127.0.0.1:60051/ws","coreApiUrl":"http://127.0.0.1:50050","mediaUrl":"http://127.0.0.1:50050","accessPoints":[{"id":"dev-b","wsUrl":"ws://127.0.0.1:61051/ws","coreApiUrl":"http://127.0.0.1:51050"}]}}'
```

The connection banner is the kit's `FlareConnectionNotice`, fed with the core's
`connection://status`; kicked or expired sessions sign out to the login page.
Login and connect succeed when the failure is one the link recovers from by
itself (no network, unreachable access points, overload): the core keeps the
session and reconnects, the local view stays, and whether the app is online is
read from `connection://status` only.

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

macOS registers `flare-recover://` in `macos/Runner/Info.plist` and takes the link
through `flare_core_flutter_lifecycle`. On Windows and Linux a release build
registers itself for the current user at startup: `reg add` under
`HKCU\Software\Classes\flare-recover`, or a desktop entry in
`~/.local/share/applications` with `xdg-mime default`. A failed registration is only
logged, and a recovery link can still be pasted on the network and line page. The
system starts the app with the link as an argument of `main`, and from there it
takes the same path as on macOS. This app has no `windows/` or `linux/` runner yet,
so none of this runs until they are added.

Limits on Windows and Linux:

- With the app already running, opening a link starts a second process. It is not
  handed to the running instance, which takes a native single-instance check that
  this app does not have.
- There is one handler per user. The Flutter apps share the scheme, so the one
  started last holds it.

## Platform-Specific Integration

FFI artifact loading, Riverpod lifecycle, GoRouter navigation, file/photo
picking, microphone permissions, local/authenticated media resolution and
platform sharing stay in the host. `scripts/sync_ffi.sh` installs matching
native SDK artifacts. This Core reference app ships no audio/video calls; calls
are the managed `flare.call` plugin, integrated by product apps.
